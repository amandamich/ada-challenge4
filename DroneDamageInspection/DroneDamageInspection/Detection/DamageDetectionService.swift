import Foundation

final class DamageDetectionService {
    private let modelService: CoreMLModelService

    init(modelService: CoreMLModelService = CoreMLModelService()) {
        self.modelService = modelService
    }

    func detectDamage() async throws -> [Damage] {
        try await modelService.loadModel()
        return []
    }
}
