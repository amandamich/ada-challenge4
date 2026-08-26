import CoreGraphics
import Foundation
import Observation

@MainActor
@Observable
final class DroneViewModel {
    private(set) var isConnected = false
    private(set) var batteryLevel = 0
    private(set) var altitude = 0.0
    private(set) var speed = 0.0
    private(set) var temperature = 0
    private(set) var flightTime = 0
    private(set) var rawStateMessage = ""
    private(set) var isVideoStreaming = false
    private(set) var videoPacketCount = 0
    private(set) var videoByteCount = 0
    private(set) var videoNALUnitCount = 0
    private(set) var videoSPSCount = 0
    private(set) var videoPPSCount = 0
    private(set) var videoFrameCount = 0
    private(set) var decodedVideoFrameCount = 0
    private(set) var latestVideoFrame: CGImage?
    private(set) var isRecordingVideo = false
    private(set) var lastRecordingURL: URL?
    private(set) var recordingMessage: String?
    private(set) var errorMessage: String?

    private let telloService: TelloService
    private let stateService: TelloStateService
    private let videoStreamService: VideoStreamService
    private var stateTask: Task<Void, Never>?

    init(
        telloService: TelloService? = nil,
        stateService: TelloStateService? = nil,
        videoStreamService: VideoStreamService? = nil
    ) {
        self.telloService = telloService ?? TelloService()
        self.stateService = stateService ?? TelloStateService()
        self.videoStreamService = videoStreamService ?? VideoStreamService()
    }

    func connect() async {
        startStateUpdates()

        do {
            try await telloService.connect()
            syncState(telloService.state)
            errorMessage = nil
            refreshBatteryInBackground()
        } catch {
            stopStateUpdates()
            isConnected = false
            errorMessage = error.localizedDescription
        }
    }

    func disconnect() {
        stopStateUpdates()
        Task {
            await videoStreamService.stopStream()
        }
        updateVideoStats(.stopped)
        latestVideoFrame = nil
        isRecordingVideo = false
        telloService.disconnect()
        syncState(telloService.state)
        errorMessage = nil
    }

    func shutdownForAppExit() {
        let shouldSendStreamOff = isConnected || isVideoStreaming

        stopStateUpdates()
        updateVideoStats(.stopped)
        latestVideoFrame = nil
        isRecordingVideo = false

        Task {
            await videoStreamService.stopStream()
            if shouldSendStreamOff {
                try? await telloService.stopVideoStream()
            }
            telloService.disconnect()
            await MainActor.run {
                self.syncState(self.telloService.state)
                self.errorMessage = nil
            }
        }
    }

    func takeOff() async {
        await runCommand {
            try await telloService.takeOff()
        }
    }

    func land() async {
        await runCommand {
            try await telloService.land()
        }
    }

    func refreshBattery() async {
        await runCommand {
            batteryLevel = try await telloService.getBattery()
        }
    }

    func startVideoStream() async {
        await videoStreamService.startStream(
            onStatsUpdate: { stats in
                Task { @MainActor in
                    self.updateVideoStats(stats)
                }
            },
            onFrame: { frame in
                Task { @MainActor in
                    self.latestVideoFrame = frame.image
                }
            },
            onError: { message in
                Task { @MainActor in
                    self.errorMessage = message
                }
            }
        )

        do {
            try await telloService.startVideoStream()
            syncState(telloService.state)
            errorMessage = nil
        } catch NetworkCommunicationError.timeout {
            syncState(telloService.state)
            errorMessage = "Stream command response timed out, but the video listener is still running. Watch the packet counter."
        } catch {
            await videoStreamService.stopStream()
            updateVideoStats(.stopped)
            errorMessage = error.localizedDescription
        }
    }

    func stopVideoStream() async {
        await stopVideoRecording()
        await videoStreamService.stopStream()
        updateVideoStats(.stopped)
        latestVideoFrame = nil

        await runCommand {
            try await telloService.stopVideoStream()
        }
    }

    func startVideoRecording() async {
        guard isVideoStreaming else {
            recordingMessage = "Start the video stream before recording."
            return
        }

        do {
            let outputURL = try await videoStreamService.startRecording()
            lastRecordingURL = outputURL
            isRecordingVideo = true
            recordingMessage = "Recording: \(outputURL.path)"
        } catch {
            isRecordingVideo = false
            recordingMessage = error.localizedDescription
        }
    }

    func stopVideoRecording() async {
        do {
            let outputURL = try await videoStreamService.stopRecording()
            isRecordingVideo = false
            if let outputURL {
                lastRecordingURL = outputURL
                recordingMessage = "Saved recording: \(outputURL.path)"
            }
        } catch {
            isRecordingVideo = false
            recordingMessage = error.localizedDescription
        }
    }

    func moveForward() async {
        await runCommand {
            try await telloService.moveForward(30)
        }
    }

    func moveBackward() async {
        await runCommand {
            try await telloService.moveBackward(30)
        }
    }

    func moveLeft() async {
        await runCommand {
            try await telloService.moveLeft(30)
        }
    }

    func moveRight() async {
        await runCommand {
            try await telloService.moveRight(30)
        }
    }

    func moveUp() async {
        await runCommand {
            try await telloService.moveUp(30)
        }
    }

    func moveDown() async {
        await runCommand {
            try await telloService.moveDown(30)
        }
    }

    func rotateClockwise() async {
        await runCommand {
            try await telloService.rotateClockwise(30)
        }
    }

    func rotateCounterClockwise() async {
        await runCommand {
            try await telloService.rotateCounterClockwise(30)
        }
    }

    private func runCommand(_ operation: () async throws -> Void) async {
        do {
            try await operation()
            syncState(telloService.state)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func startStateUpdates() {
        stopStateUpdates()

        stateTask = Task { [stateService] in
            do {
                for try await state in stateService.stateStream() {
                    await MainActor.run {
                        syncState(state)
                    }
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func stopStateUpdates() {
        stateTask?.cancel()
        stateTask = nil
        stateService.stop()
    }

    private func refreshBatteryInBackground() {
        Task {
            do {
                let batteryLevel = try await telloService.getBattery()
                await MainActor.run {
                    self.batteryLevel = batteryLevel
                }
            } catch {
                // State packets can still update battery later; keep connect flow non-blocking.
            }
        }
    }

    private func syncState(_ state: TelloState) {
        isConnected = state.isConnected
        batteryLevel = state.batteryLevel
        altitude = state.altitude
        speed = state.speed
        temperature = state.temperature
        flightTime = state.flightTime
        rawStateMessage = state.rawMessage
    }

    private func updateVideoStats(_ stats: VideoStreamStats) {
        isVideoStreaming = stats.isStreaming
        videoPacketCount = stats.packetCount
        videoByteCount = stats.byteCount
        videoNALUnitCount = stats.nalUnitCount
        videoSPSCount = stats.spsCount
        videoPPSCount = stats.ppsCount
        videoFrameCount = stats.frameCount
        decodedVideoFrameCount = stats.decodedFrameCount
    }
}
