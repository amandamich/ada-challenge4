import CoreGraphics
import Foundation

struct DetectionResult: Identifiable, Equatable {
    let id: UUID
    var damageType: String
    var confidence: Double
    var boundingBox: CGRect

    init(id: UUID = UUID(), damageType: String, confidence: Double, boundingBox: CGRect = .zero) {
        self.id = id
        self.damageType = damageType
        self.confidence = confidence
        self.boundingBox = boundingBox
    }
}
