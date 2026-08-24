import Foundation

struct Damage: Identifiable, Equatable {
    let id: UUID
    var type: String
    var confidence: Double
    var notes: String

    init(id: UUID = UUID(), type: String, confidence: Double, notes: String = "") {
        self.id = id
        self.type = type
        self.confidence = confidence
        self.notes = notes
    }
}
