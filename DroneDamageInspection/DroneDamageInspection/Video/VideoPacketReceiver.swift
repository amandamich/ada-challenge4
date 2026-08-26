import Foundation

final class VideoPacketReceiver: @unchecked Sendable {
    private let listener: UDPListener
    private let configuration: NetworkConfiguration

    nonisolated init(
        listener: UDPListener = UDPListener(),
        configuration: NetworkConfiguration = .tello
    ) {
        self.listener = listener
        self.configuration = configuration
    }

    nonisolated func packetStream() -> AsyncThrowingStream<Data, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    try await listener.start(on: configuration.videoPort) { data in
                        continuation.yield(data)
                    }
                } catch {
                    continuation.finish(throwing: error)
                }
            }

            continuation.onTermination = { [listener] _ in
                listener.stop()
            }
        }
    }

    nonisolated func stopReceiving() {
        listener.stop()
    }
}
