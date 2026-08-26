import Foundation

final class VideoRecordingService: @unchecked Sendable {
    private let lock = NSLock()

    nonisolated init() {}
    nonisolated(unsafe) private var fileHandle: FileHandle?
    nonisolated(unsafe) private var outputURL: URL?

    nonisolated var isRecording: Bool {
        lock.lock()
        defer { lock.unlock() }
        return fileHandle != nil
    }

    nonisolated func startRecording() throws -> URL {
        lock.lock()
        defer { lock.unlock() }

        if let outputURL {
            return outputURL
        }

        let directoryURL = try recordingDirectoryURL()
        let fileURL = directoryURL.appendingPathComponent("tello-recording-\(UUID().uuidString).h264")
        FileManager.default.createFile(atPath: fileURL.path, contents: nil)

        let handle = try FileHandle(forWritingTo: fileURL)
        fileHandle = handle
        outputURL = fileURL
        return fileURL
    }

    nonisolated func append(_ packet: Data) throws {
        lock.lock()
        let handle = fileHandle
        lock.unlock()

        try handle?.write(contentsOf: packet)
    }

    nonisolated func stopRecording() throws -> URL? {
        lock.lock()
        let handle = fileHandle
        fileHandle = nil
        let completedURL = outputURL
        outputURL = nil
        lock.unlock()

        try handle?.close()
        return completedURL
    }

    nonisolated func cancelRecording() {
        lock.lock()
        let handle = fileHandle
        fileHandle = nil
        outputURL = nil
        lock.unlock()

        try? handle?.close()
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
