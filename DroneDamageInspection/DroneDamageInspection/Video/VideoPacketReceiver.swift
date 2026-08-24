import Foundation

final class VideoPacketReceiver {
    private let listener: UDPListener

    init(listener: UDPListener = UDPListener()) {
        self.listener = listener
    }

    func startReceiving(on port: UInt16 = NetworkConfiguration.tello.videoPort) async throws {
        try await listener.start(on: port)
    }

    func stopReceiving() {
        listener.stop()
    }
}
