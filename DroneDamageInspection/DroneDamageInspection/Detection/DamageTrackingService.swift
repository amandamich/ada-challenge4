import CoreGraphics
import Foundation

final class DamageTrackingService {
    struct TrackedDetection {
        let id: UUID
        var damageType: String
        var smoothedConfidence: Double
        var boundingBox: CGRect
        var framesSeen: Int
        var lastSeenFrame: Int
    }

    private(set) var trackedDetections: [TrackedDetection] = []
    private var currentFrame: Int = 0
    private var nextIndex: Int = 0

    private let iouThreshold: Double
    private let confidenceThreshold: Double
    private let gracePeriodFrames: Int
    private let smoothingFactor: Double

    init(
        iouThreshold: Double = 0.4,
        confidenceThreshold: Double = 0.5,
        gracePeriodFrames: Int = 3,
        smoothingFactor: Double = 0.4
    ) {
        self.iouThreshold = iouThreshold
        self.confidenceThreshold = confidenceThreshold
        self.gracePeriodFrames = gracePeriodFrames
        self.smoothingFactor = smoothingFactor
    }

    func update(with newDetections: [DetectionResult]) -> [DetectionResult] {
        currentFrame += 1
        let filtered = newDetections.filter { $0.confidence >= confidenceThreshold }

        var updated: [TrackedDetection] = []
        var matchedOldIDs: Set<UUID> = []
        var matchedNewIndices: Set<Int> = []

        for (newIdx, detection) in filtered.enumerated() {
            if let matchIndex = trackedDetections.firstIndex(where: { existing in
                !matchedOldIDs.contains(existing.id) &&
                existing.damageType == detection.damageType &&
                Self.computeIoU(existing.boundingBox, detection.boundingBox) >= iouThreshold
            }) {
                let existing = trackedDetections[matchIndex]
                matchedOldIDs.insert(existing.id)
                matchedNewIndices.insert(newIdx)

                let alpha = smoothingFactor
                let smoothedConfidence = alpha * detection.confidence + (1.0 - alpha) * existing.smoothedConfidence
                let mergedBox = Self.weightedMergeBoxes(
                    existing.boundingBox,
                    detection.boundingBox,
                    existingWeight: max(0.3, 1.0 - alpha),
                    newWeight: alpha
                )

                updated.append(TrackedDetection(
                    id: existing.id,
                    damageType: existing.damageType,
                    smoothedConfidence: smoothedConfidence,
                    boundingBox: mergedBox,
                    framesSeen: existing.framesSeen + 1,
                    lastSeenFrame: currentFrame
                ))
            }
        }

        for existing in trackedDetections where !matchedOldIDs.contains(existing.id) {
            let framesSinceLastSeen = currentFrame - existing.lastSeenFrame
            if framesSinceLastSeen <= gracePeriodFrames {
                let decayedConfidence = existing.smoothedConfidence * pow(0.85, Double(framesSinceLastSeen))
                updated.append(TrackedDetection(
                    id: existing.id,
                    damageType: existing.damageType,
                    smoothedConfidence: decayedConfidence,
                    boundingBox: existing.boundingBox,
                    framesSeen: existing.framesSeen,
                    lastSeenFrame: existing.lastSeenFrame
                ))
            }
        }

        for (newIdx, detection) in filtered.enumerated() where !matchedNewIndices.contains(newIdx) {
            nextIndex += 1
            updated.append(TrackedDetection(
                id: detection.id,
                damageType: detection.damageType,
                smoothedConfidence: detection.confidence,
                boundingBox: detection.boundingBox,
                framesSeen: 1,
                lastSeenFrame: currentFrame
            ))
        }

        trackedDetections = updated

        return updated.map { tracked in
            DetectionResult(
                id: tracked.id,
                damageType: tracked.damageType,
                confidence: tracked.smoothedConfidence,
                boundingBox: tracked.boundingBox
            )
        }
    }

    func clear() {
        trackedDetections.removeAll()
        currentFrame = 0
        nextIndex = 0
    }

    var stableDetections: [DetectionResult] {
        trackedDetections
            .filter { $0.framesSeen >= 2 && $0.smoothedConfidence >= confidenceThreshold }
            .map { tracked in
                DetectionResult(
                    id: tracked.id,
                    damageType: tracked.damageType,
                    confidence: tracked.smoothedConfidence,
                    boundingBox: tracked.boundingBox
                )
            }
    }

    static func computeIoU(_ a: CGRect, _ b: CGRect) -> Double {
        let intersectionX = max(a.minX, b.minX)
        let intersectionY = max(a.minY, b.minY)
        let intersectionMaxX = min(a.maxX, b.maxX)
        let intersectionMaxY = min(a.maxY, b.maxY)

        let intersectionWidth = max(0, intersectionMaxX - intersectionX)
        let intersectionHeight = max(0, intersectionMaxY - intersectionY)
        let intersectionArea = intersectionWidth * intersectionHeight

        let areaA = a.width * a.height
        let areaB = b.width * b.height
        let unionArea = areaA + areaB - intersectionArea

        guard unionArea > 0 else { return 0 }
        return intersectionArea / unionArea
    }

    private static func weightedMergeBoxes(
        _ a: CGRect,
        _ b: CGRect,
        existingWeight: Double,
        newWeight: Double
    ) -> CGRect {
        let totalWeight = existingWeight + newWeight
        guard totalWeight > 0 else { return a }

        let x = (a.origin.x * existingWeight + b.origin.x * newWeight) / totalWeight
        let y = (a.origin.y * existingWeight + b.origin.y * newWeight) / totalWeight
        let w = (a.width * existingWeight + b.width * newWeight) / totalWeight
        let h = (a.height * existingWeight + b.height * newWeight) / totalWeight

        return CGRect(x: x, y: y, width: w, height: h)
    }
}
