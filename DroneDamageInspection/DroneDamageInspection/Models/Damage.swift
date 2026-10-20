import CoreGraphics
import Foundation

struct Damage: Identifiable, Equatable {
    let id: UUID
    var type: String
    var confidence: Double
    var boundingBox: CGRect
    var inspectionZone: BuildingZone
    var timestamp: Date
    var evidenceImageFileURL: URL?
    var evidenceImage: CGImage?
    var notes: String

    init(
        id: UUID = UUID(),
        type: String,
        confidence: Double,
        boundingBox: CGRect = .zero,
        inspectionZone: BuildingZone = .defaultZone,
        timestamp: Date = Date(),
        evidenceImageFileURL: URL? = nil,
        evidenceImage: CGImage? = nil,
        notes: String = ""
    ) {
        self.id = id
        self.type = type
        self.confidence = confidence
        self.boundingBox = boundingBox
        self.inspectionZone = inspectionZone
        self.timestamp = timestamp
        self.evidenceImageFileURL = evidenceImageFileURL
        self.evidenceImage = evidenceImage
        self.notes = notes
    }

    static func == (lhs: Damage, rhs: Damage) -> Bool {
        lhs.id == rhs.id &&
        lhs.type == rhs.type &&
        lhs.confidence == rhs.confidence &&
        lhs.boundingBox == rhs.boundingBox &&
        lhs.inspectionZone == rhs.inspectionZone &&
        lhs.timestamp == rhs.timestamp &&
        lhs.evidenceImageFileURL == rhs.evidenceImageFileURL &&
        lhs.notes == rhs.notes
    }
}
