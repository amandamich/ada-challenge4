@preconcurrency import Dispatch
import Foundation
import Network

final class UDPClient: @unchecked Sendable {
    private let configuration: NetworkConfiguration
    private let queue = DispatchQueue(label: "DroneDamageInspection.UDPClient")

    init(configuration: NetworkConfiguration = .tello) {
        self.configuration = configuration
    }

    @discardableResult
    func send(_ message: String, timeout: TimeInterval = 5) async throws -> String {
        guard let port = configuration.commandEndpointPort else {
            throw NetworkCommunicationError.invalidPort(configuration.commandPort)
        }

        let connection = NWConnection(
            host: configuration.commandHost,
            port: port,
            using: .udp
        )

        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                let completion = UDPResponseCompletion(continuation: continuation)
                let timeoutHandler = UDPTimeout {
                    completion.resume(throwing: NetworkCommunicationError.timeout)
                    connection.cancel()
                }

                timeoutHandler.schedule(on: queue, after: timeout)

                connection.stateUpdateHandler = { state in
                    switch state {
                    case .ready:
                        let data = Data(message.utf8)
                        connection.send(
                            content: data,
                            contentContext: .defaultMessage,
                            isComplete: true,
                            completion: .contentProcessed { error in
                                if let error {
                                    timeoutHandler.cancel()
                                    completion.resume(throwing: NetworkCommunicationError.sendFailed(error.localizedDescription))
                                    connection.cancel()
                                    return
                                }

                                Self.receiveResponse(
                                    on: connection,
                                    timeout: timeoutHandler,
                                    completion: completion
                                )
                            }
                        )
                    case .failed(let error):
                        timeoutHandler.cancel()
                        completion.resume(throwing: NetworkCommunicationError.connectionFailed(error.localizedDescription))
                        connection.cancel()
                    case .cancelled:
                        timeoutHandler.cancel()
                    default:
                        break
                    }
                }

                connection.start(queue: queue)
            }
        } onCancel: {
            connection.cancel()
        }
    }

    private static func receiveResponse(
        on connection: NWConnection,
        timeout: UDPTimeout,
        completion: UDPResponseCompletion
    ) {
        connection.receiveMessage { data, _, _, error in
            timeout.cancel()

            if let error {
                completion.resume(throwing: NetworkCommunicationError.receiveFailed(error.localizedDescription))
                connection.cancel()
                return
            }

            guard let data, let response = String(data: data, encoding: .utf8) else {
                completion.resume(throwing: NetworkCommunicationError.invalidResponseData)
                connection.cancel()
                return
            }

            completion.resume(returning: response.trimmingCharacters(in: .whitespacesAndNewlines))
            connection.cancel()
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
