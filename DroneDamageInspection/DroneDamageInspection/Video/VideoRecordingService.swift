import AVFoundation
import CoreMedia
import Foundation

final class VideoRecordingService: @unchecked Sendable {
    private let lock = NSLock()

    nonisolated init() {}
    nonisolated(unsafe) private var assetWriter: AVAssetWriter?
    nonisolated(unsafe) private var assetWriterInput: AVAssetWriterInput?
    nonisolated(unsafe) private var adaptor: AVAssetWriterInputPixelBufferAdaptor?
    nonisolated(unsafe) private var outputURL: URL?
    nonisolated(unsafe) private var startTime: CMTime?
    nonisolated(unsafe) private var sessionStarted = false

    nonisolated var isRecording: Bool {
        lock.lock()
        defer { lock.unlock() }
        return assetWriter != nil
    }

    nonisolated func startRecording(width: Int = 960, height: Int = 720) throws -> URL {
        lock.lock()
        defer { lock.unlock() }

        if let outputURL {
            return outputURL
        }

        let directoryURL = try recordingDirectoryURL()
        let fileURL = directoryURL.appendingPathComponent("tello-recording-\(UUID().uuidString).mp4")

        let writer = try AVAssetWriter(outputURL: fileURL, fileType: .mp4)

        let outputSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: width,
            AVVideoHeightKey: height,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: 3_000_000,
                AVVideoMaxKeyFrameIntervalKey: 30,
                AVVideoProfileLevelKey: AVVideoProfileLevelH264BaselineAutoLevel
            ]
        ]

        let input = AVAssetWriterInput(mediaType: .video, outputSettings: outputSettings)
        input.expectsMediaDataInRealTime = true

        let adaptorAttributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange,
            kCVPixelBufferWidthKey as String: width,
            kCVPixelBufferHeightKey as String: height
        ]
        let pixelAdaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: adaptorAttributes)

        writer.add(input)

        guard writer.startWriting() else {
            throw writer.error ?? NSError(domain: "VideoRecordingService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to start asset writer"])
        }

        assetWriter = writer
        assetWriterInput = input
        adaptor = pixelAdaptor
        outputURL = fileURL
        startTime = nil
        return fileURL
    }

    nonisolated func append(pixelBuffer: CVPixelBuffer, presentationTime: CMTime) throws {
        lock.lock()
        let input = assetWriterInput
        let adaptor = adaptor
        let writer = assetWriter
        let startTimeRef = startTime
        lock.unlock()

        guard let input, let adaptor, let writer else { return }

        if !sessionStarted {
            writer.startSession(atSourceTime: presentationTime)
            lock.lock()
            startTime = presentationTime
            sessionStarted = true
            lock.unlock()
        }

        guard writer.status == .writing,
              input.isReadyForMoreMediaData else { return }

        if let startTimeRef {
            let adjustedTime = CMTimeSubtract(presentationTime, startTimeRef)
            adaptor.append(pixelBuffer, withPresentationTime: adjustedTime)
        }
    }

    nonisolated func stopRecording() throws -> URL? {
        lock.lock()
        let writer = assetWriter
        let input = assetWriterInput
        assetWriter = nil
        assetWriterInput = nil
        adaptor = nil
        let completedURL = outputURL
        outputURL = nil
        startTime = nil
        sessionStarted = false
        lock.unlock()

        guard let writer, let input else { return completedURL }

        if writer.status == .writing {
            input.markAsFinished()
            let semaphore = DispatchSemaphore(value: 0)
            writer.finishWriting {
                semaphore.signal()
            }
            semaphore.wait()
            if writer.status == .failed, let finishError = writer.error {
                throw finishError
            }
        }

        return completedURL
    }

    nonisolated func cancelRecording() {
        lock.lock()
        let writer = assetWriter
        assetWriter = nil
        assetWriterInput = nil
        adaptor = nil
        outputURL = nil
        startTime = nil
        sessionStarted = false
        lock.unlock()

        if let writer, writer.status == .writing {
            writer.cancelWriting()
        }
    }

    private nonisolated func recordingDirectoryURL() throws -> URL {
        let documentsURL = try FileManager.default.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let directoryURL = documentsURL.appendingPathComponent("DroneDamageInspectionRecordings", isDirectory: true)
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        return directoryURL
    }
}
