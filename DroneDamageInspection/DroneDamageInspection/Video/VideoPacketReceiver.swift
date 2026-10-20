import Foundation

final class VideoPacketReceiver: @unchecked Sendable {
    private let configuration: NetworkConfiguration

    nonisolated init(
        configuration: NetworkConfiguration = .tello
    ) {
        self.configuration = configuration
    }

    nonisolated func packetStream() -> AsyncThrowingStream<Data, Error> {
        let listener = UDPListener()

        return AsyncThrowingStream(bufferingPolicy: .bufferingNewest(200)) { continuation in
            Task {
                do {
                    try await listener.start(on: configuration.videoPort) { data in
                        continuation.yield(data)
                    }
                } catch {
                    continuation.finish(throwing: error)
                }
            }

            continuation.onTermination = { _ in
                listener.stop()
            }
        }
    }

    nonisolated func stopReceiving() {
    }
}
