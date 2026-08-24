import Foundation

final class VideoStreamService {
    private(set) var isStreaming = false
    private let receiver: VideoPacketReceiver

    init(receiver: VideoPacketReceiver = VideoPacketReceiver()) {
        self.receiver = receiver
    }

    func startStream() async throws {
        try await receiver.startReceiving()
        isStreaming = true
    }

    func stopStream() {
        receiver.stopReceiving()
        isStreaming = false
    }
}
