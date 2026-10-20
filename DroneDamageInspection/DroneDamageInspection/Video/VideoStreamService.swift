import CoreMedia
import Foundation

nonisolated struct VideoStreamStats: Equatable, Sendable {
    var isStreaming: Bool
    var packetCount: Int
    var byteCount: Int
    var nalUnitCount: Int
    var spsCount: Int
    var ppsCount: Int
    var frameCount: Int
    var decodedFrameCount: Int

    static let stopped = VideoStreamStats(
        isStreaming: false,
        packetCount: 0,
        byteCount: 0,
        nalUnitCount: 0,
        spsCount: 0,
        ppsCount: 0,
        frameCount: 0,
        decodedFrameCount: 0
    )
}

actor VideoStreamService {
    private let receiver: VideoPacketReceiver
    private let decoder: VideoDecoder
    private let recorder: VideoRecordingService
    private var streamTask: Task<Void, Never>?
    private var stats: VideoStreamStats = .stopped

    init(
        receiver: VideoPacketReceiver = VideoPacketReceiver(),
        decoder: VideoDecoder = VideoDecoder(),
        recorder: VideoRecordingService = VideoRecordingService()
    ) {
        self.receiver = receiver
        self.decoder = decoder
        self.recorder = recorder
    }

    func startStream(
        onStatsUpdate: @escaping @Sendable (VideoStreamStats) -> Void,
        onFrame: @escaping @Sendable (VideoFrame) -> Void,
        onError: @escaping @Sendable (String) -> Void
    ) {
        stopStream()

        stats = VideoStreamStats(
            isStreaming: true,
            packetCount: 0,
            byteCount: 0,
            nalUnitCount: 0,
            spsCount: 0,
            ppsCount: 0,
            frameCount: 0,
            decodedFrameCount: 0
        )
        onStatsUpdate(stats)

        streamTask = Task { [receiver, decoder, recorder] in
            var currentStats = VideoStreamStats(
                isStreaming: true,
                packetCount: 0,
                byteCount: 0,
                nalUnitCount: 0,
                spsCount: 0,
                ppsCount: 0,
                frameCount: 0,
                decodedFrameCount: 0
            )
            var frameTimestamp = CMTime(value: 0, timescale: 30)
            var lastStatsUpdateDate = Date.distantPast
            let statsUpdateInterval: TimeInterval = 0.25

            await decoder.reset()

            do {
                for try await packet in receiver.packetStream() {
                    guard !Task.isCancelled else { break }

                    let decodeOutput = await decoder.append(packet)
                    let h264Stats = decodeOutput.stats

                    currentStats.packetCount += 1
                    currentStats.byteCount += packet.count
                    currentStats.nalUnitCount = h264Stats.nalUnitCount
                    currentStats.spsCount = h264Stats.spsCount
                    currentStats.ppsCount = h264Stats.ppsCount
                    currentStats.frameCount = h264Stats.frameCount
                    currentStats.decodedFrameCount = h264Stats.decodedFrameCount

                    let now = Date()
                    if now.timeIntervalSince(lastStatsUpdateDate) >= statsUpdateInterval {
                        onStatsUpdate(currentStats)
                        lastStatsUpdateDate = now
                    }

                    if let frame = decodeOutput.frame {
                        if recorder.isRecording, let pixelBuffer = frame.pixelBuffer {
                            try? recorder.append(pixelBuffer: pixelBuffer, presentationTime: frameTimestamp)
                            frameTimestamp = CMTimeAdd(frameTimestamp, CMTime(value: 1, timescale: 30))
                        }
                        onFrame(frame)
                    }
                }
            } catch {
                currentStats.isStreaming = false
                onStatsUpdate(currentStats)
                onError(error.localizedDescription)
            }
        }
    }

    func startRecording(width: Int = 960, height: Int = 720) throws -> URL {
        try recorder.startRecording(width: width, height: height)
    }

    func stopRecording() throws -> URL? {
        try recorder.stopRecording()
    }

    func stopStream() {
        streamTask?.cancel()
        streamTask = nil
        receiver.stopReceiving()
        _ = try? recorder.stopRecording()
        stats = .stopped
    }
}
