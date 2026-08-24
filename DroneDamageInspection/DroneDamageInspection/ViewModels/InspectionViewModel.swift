import Foundation
import Observation

@MainActor
@Observable
final class InspectionViewModel {
    private(set) var detectedDamage: [Damage] = []
    private(set) var inspectionRecords: [InspectionRecord] = []

    private let damageDetectionService: DamageDetectionService

    init(damageDetectionService: DamageDetectionService = DamageDetectionService()) {
        self.damageDetectionService = damageDetectionService
    }

    func inspectCurrentFrame() async {
        do {
            detectedDamage = try await damageDetectionService.detectDamage()
            inspectionRecords.append(InspectionRecord(detectedDamage: detectedDamage))
        } catch {
            detectedDamage = []
        }
    }
}
