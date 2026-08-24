import Foundation

struct InspectionRecord: Identifiable, Equatable {
    let id: UUID
    var createdAt: Date
    var damageTypes: [String]

    init(id: UUID = UUID(), createdAt: Date = Date(), damageTypes: [String] = []) {
        self.id = id
        self.createdAt = createdAt
        self.damageTypes = damageTypes
    }
}
