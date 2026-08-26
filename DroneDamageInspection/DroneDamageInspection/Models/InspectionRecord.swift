import CoreGraphics
import Foundation

struct InspectionRecord: Identifiable, Equatable {
    let id: UUID
    var createdAt: Date
    var damageTypes: [String]
    var imageFileURL: URL?
    var capturedImage: CGImage?

    init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        damageTypes: [String] = [],
        imageFileURL: URL? = nil,
        capturedImage: CGImage? = nil
    ) {
        self.id = id
        self.createdAt = createdAt
        self.damageTypes = damageTypes
        self.imageFileURL = imageFileURL
        self.capturedImage = capturedImage
    }

    static func == (lhs: InspectionRecord, rhs: InspectionRecord) -> Bool {
        lhs.id == rhs.id &&
        lhs.createdAt == rhs.createdAt &&
        lhs.damageTypes == rhs.damageTypes &&
        lhs.imageFileURL == rhs.imageFileURL
    }
}
