@preconcurrency import Dispatch
import Foundation
import Network

final class UDPClient: @unchecked Sendable {
    private let configuration: NetworkConfiguration
    private let queue = DispatchQueue(label: "DroneDamageInspection.UDPClient")
    private let lock = NSLock()
    nonisolated(unsafe) private var connection: NWConnection?
    nonisolated(unsafe) private var isConnected = false

    init(configuration: NetworkConfiguration = .tello) {
        self.configuration = configuration
    }

    private func getOrCreateConnection() -> NWConnection {
        lock.lock()
        defer { lock.unlock() }

        if let connection, isConnected {
            return connection
        }

        guard let port = configuration.commandEndpointPort else {
            fatalError("Invalid Tello command port: \(configuration.commandPort)")
        }

        let newConnection = NWConnection(
            host: configuration.commandHost,
            port: port,
            using: .udp
        )

        connection = newConnection
        isConnected = true

        newConnection.stateUpdateHandler = { [weak self] state in
            switch state {
            case .failed, .cancelled:
                self?.lock.lock()
                self?.isConnected = false
                self?.connection = nil
                self?.lock.unlock()
            default:
                break
            }
        }

        newConnection.start(queue: queue)
        return newConnection
    }

    func resetConnection() {
        lock.lock()
        let oldConnection = connection
        connection = nil
        isConnected = false
        lock.unlock()

        oldConnection?.cancel()
    }

    @discardableResult
    func send(_ message: String, timeout: TimeInterval = 3) async throws -> String {
        let conn = getOrCreateConnection()

        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                let completion = UDPResponseCompletion(continuation: continuation)
                let timeoutHandler = UDPTimeout {
                    completion.resume(throwing: NetworkCommunicationError.timeout)
                    self.resetConnection()
                }

                timeoutHandler.schedule(on: queue, after: timeout)

                let data = Data(message.utf8)
                conn.send(
                    content: data,
                    contentContext: .defaultMessage,
                    isComplete: true,
                    completion: .contentProcessed { error in
                        if let error {
                            timeoutHandler.cancel()
                            completion.resume(throwing: NetworkCommunicationError.sendFailed(error.localizedDescription))
                            self.resetConnection()
                            return
                        }

                        Self.receiveResponse(
                            on: conn,
                            timeout: timeoutHandler,
                            completion: completion,
                            client: self
                        )
                    }
                )
            }
        } onCancel: {
            Task { @MainActor in
                self.resetConnection()
            }
        }
    }

    func sendWithoutResponse(_ message: String) async throws {
        let conn = getOrCreateConnection()

        try await withCheckedThrowingContinuation { continuation in
            let completion = UDPSendCompletion(continuation: continuation)
            let data = Data(message.utf8)

            conn.send(
                content: data,
                contentContext: .defaultMessage,
                isComplete: true,
                completion: .contentProcessed { error in
                    if let error {
                        completion.resume(throwing: NetworkCommunicationError.sendFailed(error.localizedDescription))
                        self.resetConnection()
                        return
                    }

                    completion.resume()
                }
            )
        }
    }

    private static func receiveResponse(
        on connection: NWConnection,
        timeout: UDPTimeout,
        completion: UDPResponseCompletion,
        client: UDPClient
    ) {
        connection.receiveMessage { data, _, _, error in
            timeout.cancel()

            if let error {
                completion.resume(throwing: NetworkCommunicationError.receiveFailed(error.localizedDescription))
                client.resetConnection()
                return
            }

            guard let data, let response = String(data: data, encoding: .utf8) else {
                completion.resume(throwing: NetworkCommunicationError.invalidResponseData)
                client.resetConnection()
                return
            }

            completion.resume(returning: response.trimmingCharacters(in: .whitespacesAndNewlines))
        }
    }
}

private final class UDPTimeout: @unchecked Sendable {
    nonisolated(unsafe) private let workItem: DispatchWorkItem

    init(action: @escaping @Sendable () -> Void) {
        workItem = DispatchWorkItem(block: action)
    }

    nonisolated func schedule(on queue: DispatchQueue, after timeout: TimeInterval) {
        queue.asyncAfter(deadline: .now() + timeout, execute: workItem)
    }

    nonisolated func cancel() {
        workItem.cancel()
    }
}

private final class UDPResponseCompletion: @unchecked Sendable {
    private let lock = NSLock()
    nonisolated(unsafe) private var continuation: CheckedContinuation<String, Error>?

    init(continuation: CheckedContinuation<String, Error>) {
        self.continuation = continuation
    }

    nonisolated func resume(returning value: String) {
        lock.lock()
        let continuation = continuation
        self.continuation = nil
        lock.unlock()

        continuation?.resume(returning: value)
    }

    nonisolated func resume(throwing error: Error) {
        lock.lock()
        let continuation = continuation
        self.continuation = nil
        lock.unlock()

        continuation?.resume(throwing: error)
    }
}

private final class UDPSendCompletion: @unchecked Sendable {
    private let lock = NSLock()
    nonisolated(unsafe) private var continuation: CheckedContinuation<Void, Error>?

    init(continuation: CheckedContinuation<Void, Error>) {
        self.continuation = continuation
    }

    nonisolated func resume() {
        lock.lock()
        let continuation = continuation
        self.continuation = nil
        lock.unlock()

        continuation?.resume()
    }

    nonisolated func resume(throwing error: Error) {
        lock.lock()
        let continuation = continuation
        self.continuation = nil
        lock.unlock()

        continuation?.resume(throwing: error)
    }
}
