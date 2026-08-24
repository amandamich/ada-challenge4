@preconcurrency import Dispatch
import Foundation
import Network

final class UDPListener: @unchecked Sendable {
    private let queue = DispatchQueue(label: "DroneDamageInspection.UDPListener")
    nonisolated(unsafe) private var listener: NWListener?
    nonisolated(unsafe) private(set) var isListening = false

    func start(on port: UInt16, messageHandler: ((Data) -> Void)? = nil) async throws {
        guard let endpointPort = NetworkConfiguration.tello.endpointPort(for: port) else {
            throw NetworkCommunicationError.invalidPort(port)
        }

        let listener = try NWListener(using: .udp, on: endpointPort)

        try await withCheckedThrowingContinuation { continuation in
            let completion = UDPStartCompletion(continuation: continuation)

            listener.stateUpdateHandler = { [weak self] state in
                switch state {
                case .ready:
                    self?.isListening = true
                    completion.resume()
                case .failed(let error):
                    self?.isListening = false
                    completion.resume(throwing: NetworkCommunicationError.connectionFailed(error.localizedDescription))
                    listener.cancel()
                case .cancelled:
                    self?.isListening = false
                default:
                    break
                }
            }

            listener.newConnectionHandler = { [weak self] connection in
                guard let self else {
                    connection.cancel()
                    return
                }

                connection.start(queue: queue)
                self.receiveMessages(on: connection, messageHandler: messageHandler)
            }

            self.listener = listener
            listener.start(queue: queue)
        }
    }

    func stop() {
        listener?.cancel()
        listener = nil
        isListening = false
    }

    nonisolated private func receiveMessages(on connection: NWConnection, messageHandler: ((Data) -> Void)?) {
        connection.receiveMessage { [weak self] data, _, _, error in
            if error != nil {
                connection.cancel()
                return
            }

            if let data, !data.isEmpty {
                messageHandler?(data)
            }

            self?.receiveMessages(on: connection, messageHandler: messageHandler)
        }
    }
}

private final class UDPStartCompletion: @unchecked Sendable {
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
