import CoreGraphics
import CoreImage
import CoreMedia
import Foundation
import VideoToolbox

nonisolated struct VideoFrame: @unchecked Sendable {
    let image: CGImage
}

nonisolated struct H264DecodeOutput: Sendable {
    let stats: H264StreamStats
    let frame: VideoFrame?
}

nonisolated struct H264StreamStats: Equatable, Sendable {
    var nalUnitCount: Int
    var spsCount: Int
    var ppsCount: Int
    var frameCount: Int
    var decodedFrameCount: Int

    static let empty = H264StreamStats(
        nalUnitCount: 0,
        spsCount: 0,
        ppsCount: 0,
        frameCount: 0,
        decodedFrameCount: 0
    )
}

actor VideoDecoder {
    private var assembler = H264AnnexBAssembler()
    private var stats: H264StreamStats = .empty
    private var sps: Data?
    private var pps: Data?
    private var formatDescription: CMVideoFormatDescription?
    private var decompressionSession: VTDecompressionSession?
    private var pendingAccessUnit: [H264NALUnit] = []
    private let frameRenderer = VideoFrameRenderer()

    func append(_ packet: Data) -> H264DecodeOutput {
        let nalUnits = assembler.append(packet)
        var decodedFrame: VideoFrame?

        for nalUnit in nalUnits {
            stats.nalUnitCount += 1

            switch nalUnit.type {
            case .sps:
                sps = nalUnit.data
                stats.spsCount += 1
                rebuildDecoderIfPossible()
            case .pps:
                pps = nalUnit.data
                stats.ppsCount += 1
                rebuildDecoderIfPossible()
            case .idrSlice, .nonIDRSlice:
                if let frame = flushPendingAccessUnit() {
                    decodedFrame = frame
                }
                pendingAccessUnit = [nalUnit]
                stats.frameCount += 1
            case .other:
                if !pendingAccessUnit.isEmpty {
                    pendingAccessUnit.append(nalUnit)
                }
            }
        }

        return H264DecodeOutput(stats: stats, frame: decodedFrame)
    }

    func reset() {
        assembler.reset()
        stats = .empty
        sps = nil
        pps = nil
        formatDescription = nil
        pendingAccessUnit.removeAll(keepingCapacity: true)
        if let decompressionSession {
            VTDecompressionSessionInvalidate(decompressionSession)
        }
        decompressionSession = nil
    }

    private func rebuildDecoderIfPossible() {
        guard let sps, let pps else { return }

        let status = sps.withUnsafeBytes { spsBuffer in
            pps.withUnsafeBytes { ppsBuffer in
                guard let spsBase = spsBuffer.bindMemory(to: UInt8.self).baseAddress,
                      let ppsBase = ppsBuffer.bindMemory(to: UInt8.self).baseAddress else {
                    return kCMFormatDescriptionError_InvalidParameter
                }

                let parameterSetPointers: [UnsafePointer<UInt8>] = [spsBase, ppsBase]
                let parameterSetSizes = [sps.count, pps.count]
                var newFormatDescription: CMVideoFormatDescription?

                let formatStatus = parameterSetPointers.withUnsafeBufferPointer { pointerBuffer in
                    parameterSetSizes.withUnsafeBufferPointer { sizeBuffer in
                        CMVideoFormatDescriptionCreateFromH264ParameterSets(
                            allocator: kCFAllocatorDefault,
                            parameterSetCount: 2,
                            parameterSetPointers: pointerBuffer.baseAddress!,
                            parameterSetSizes: sizeBuffer.baseAddress!,
                            nalUnitHeaderLength: 4,
                            formatDescriptionOut: &newFormatDescription
                        )
                    }
                }

                guard formatStatus == noErr, let newFormatDescription else {
                    return formatStatus
                }

                formatDescription = newFormatDescription
                createDecompressionSession(formatDescription: newFormatDescription)
                return noErr
            }
        }

        if status != noErr {
            formatDescription = nil
            decompressionSession = nil
        }
    }

    private func createDecompressionSession(formatDescription: CMVideoFormatDescription) {
        if let decompressionSession,
           VTDecompressionSessionCanAcceptFormatDescription(
            decompressionSession,
            formatDescription: formatDescription
           ) {
            return
        }

        if let decompressionSession {
            VTDecompressionSessionInvalidate(decompressionSession)
        }

        let imageBufferAttributes = [
            kCVPixelBufferPixelFormatTypeKey: kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange
        ] as CFDictionary

        var newSession: VTDecompressionSession?
        let status = VTDecompressionSessionCreate(
            allocator: kCFAllocatorDefault,
            formatDescription: formatDescription,
            decoderSpecification: nil,
            imageBufferAttributes: imageBufferAttributes,
            decompressionSessionOut: &newSession
        )

        decompressionSession = status == noErr ? newSession : nil
    }

    private func flushPendingAccessUnit() -> VideoFrame? {
        guard !pendingAccessUnit.isEmpty else { return nil }

        let accessUnit = pendingAccessUnit
        pendingAccessUnit.removeAll(keepingCapacity: true)

        guard let frame = decode(accessUnit) else { return nil }
        stats.decodedFrameCount += 1
        return frame
    }

    private func decode(_ accessUnit: [H264NALUnit]) -> VideoFrame? {
        guard let decompressionSession,
              let formatDescription,
              let sampleBuffer = makeSampleBuffer(from: accessUnit, formatDescription: formatDescription) else {
            return nil
        }

        let frameBox = DecodedFrameBox()
        var infoFlags = VTDecodeInfoFlags()
        let status = VTDecompressionSessionDecodeFrame(
            decompressionSession,
            sampleBuffer: sampleBuffer,
            flags: [],
            infoFlagsOut: &infoFlags
        ) { [frameRenderer, frameBox] status, _, imageBuffer, _, _ in
            guard status == noErr,
                  let imageBuffer,
                  let image = frameRenderer.makeImage(from: imageBuffer) else {
                return
            }

            frameBox.set(VideoFrame(image: image))
        }

        guard status == noErr else { return nil }
        VTDecompressionSessionWaitForAsynchronousFrames(decompressionSession)
        return frameBox.frame
    }

    private func makeSampleBuffer(
        from accessUnit: [H264NALUnit],
        formatDescription: CMVideoFormatDescription
    ) -> CMSampleBuffer? {
        var avccData = Data()
        for nalUnit in accessUnit {
            var length = UInt32(nalUnit.data.count).bigEndian
            withUnsafeBytes(of: &length) { avccData.append(contentsOf: $0) }
            avccData.append(nalUnit.data)
        }

        var blockBuffer: CMBlockBuffer?
        let blockStatus = CMBlockBufferCreateWithMemoryBlock(
            allocator: kCFAllocatorDefault,
            memoryBlock: nil,
            blockLength: avccData.count,
            blockAllocator: kCFAllocatorDefault,
            customBlockSource: nil,
            offsetToData: 0,
            dataLength: avccData.count,
            flags: 0,
            blockBufferOut: &blockBuffer
        )

        guard blockStatus == noErr, let blockBuffer else { return nil }

        let replaceStatus = avccData.withUnsafeBytes { bytes in
            guard let baseAddress = bytes.baseAddress else {
                return kCMBlockBufferBadPointerParameterErr
            }

            return CMBlockBufferReplaceDataBytes(
                with: baseAddress,
                blockBuffer: blockBuffer,
                offsetIntoDestination: 0,
                dataLength: avccData.count
            )
        }

        guard replaceStatus == noErr else { return nil }

        var timing = CMSampleTimingInfo(
            duration: .invalid,
            presentationTimeStamp: CMTime(value: Int64(stats.frameCount), timescale: 30),
            decodeTimeStamp: .invalid
        )
        var sampleSize = avccData.count
        var sampleBuffer: CMSampleBuffer?

        let sampleStatus = CMSampleBufferCreateReady(
            allocator: kCFAllocatorDefault,
            dataBuffer: blockBuffer,
            formatDescription: formatDescription,
            sampleCount: 1,
            sampleTimingEntryCount: 1,
            sampleTimingArray: &timing,
            sampleSizeEntryCount: 1,
            sampleSizeArray: &sampleSize,
            sampleBufferOut: &sampleBuffer
        )

        guard sampleStatus == noErr else { return nil }
        return sampleBuffer
    }
}

private final class DecodedFrameBox: @unchecked Sendable {
    private let lock = NSLock()
    nonisolated(unsafe) private var storedFrame: VideoFrame?

    nonisolated init() {}

    nonisolated var frame: VideoFrame? {
        lock.lock()
        defer { lock.unlock() }
        return storedFrame
    }

    func set(_ frame: VideoFrame) {
        lock.lock()
        storedFrame = frame
        lock.unlock()
    }
}

private final class VideoFrameRenderer: @unchecked Sendable {
    private let context = CIContext()

    nonisolated init() {}

    nonisolated func makeImage(from imageBuffer: CVImageBuffer) -> CGImage? {
        let ciImage = CIImage(cvImageBuffer: imageBuffer)
        return context.createCGImage(ciImage, from: ciImage.extent)
    }
}

nonisolated struct H264NALUnit: Equatable, Sendable {
    nonisolated enum UnitType: Equatable, Sendable {
        case nonIDRSlice
        case idrSlice
        case sps
        case pps
        case other(Int)
    }

    let data: Data

    nonisolated init(data: Data) {
        self.data = data
    }

    nonisolated var type: UnitType {
        guard let firstByte = data.first else { return .other(-1) }

        switch Int(firstByte & 0x1F) {
        case 1:
            return .nonIDRSlice
        case 5:
            return .idrSlice
        case 7:
            return .sps
        case 8:
            return .pps
        case let value:
            return .other(value)
        }
    }
}

nonisolated struct H264AnnexBAssembler: Sendable {
    private var buffer = Data()

    nonisolated init() {}

    nonisolated mutating func append(_ packet: Data) -> [H264NALUnit] {
        buffer.append(packet)
        return extractCompleteNALUnits()
    }

    nonisolated mutating func reset() {
        buffer.removeAll(keepingCapacity: true)
    }

    private mutating func extractCompleteNALUnits() -> [H264NALUnit] {
        var units: [H264NALUnit] = []

        while true {
            guard let firstStartCode = findStartCode(in: buffer, from: buffer.startIndex) else {
                trimBufferIfNeeded()
                return units
            }

            if firstStartCode.range.lowerBound > buffer.startIndex {
                buffer.removeSubrange(buffer.startIndex..<firstStartCode.range.lowerBound)
            }

            let nalStart = buffer.index(buffer.startIndex, offsetBy: firstStartCode.length)
            guard let nextStartCode = findStartCode(in: buffer, from: nalStart) else {
                return units
            }

            let nalData = buffer[nalStart..<nextStartCode.range.lowerBound]
            if !nalData.isEmpty {
                units.append(H264NALUnit(data: Data(nalData)))
            }

            buffer.removeSubrange(buffer.startIndex..<nextStartCode.range.lowerBound)
        }
    }

    private func findStartCode(in data: Data, from startIndex: Data.Index) -> (range: Range<Data.Index>, length: Int)? {
        guard data.count >= 4 else { return nil }

        var index = startIndex
        while index < data.endIndex {
            let remaining = data.distance(from: index, to: data.endIndex)

            if remaining >= 4,
               data[index] == 0,
               data[data.index(after: index)] == 0,
               data[data.index(index, offsetBy: 2)] == 0,
               data[data.index(index, offsetBy: 3)] == 1 {
                return (index..<data.index(index, offsetBy: 4), 4)
            }

            if remaining >= 3,
               data[index] == 0,
               data[data.index(after: index)] == 0,
               data[data.index(index, offsetBy: 2)] == 1 {
                return (index..<data.index(index, offsetBy: 3), 3)
            }

            index = data.index(after: index)
        }

        return nil
    }

    private mutating func trimBufferIfNeeded() {
        let maximumBufferSize = 2_000_000
        if buffer.count > maximumBufferSize {
            buffer.removeFirst(buffer.count - maximumBufferSize)
        }
    }
}
