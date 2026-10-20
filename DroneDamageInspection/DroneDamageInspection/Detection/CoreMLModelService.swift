import CoreML
import Foundation
import Vision

enum CoreMLModelError: LocalizedError {
    case modelNotFound(String)
    case modelLoadFailed(String)

    var errorDescription: String? {
        switch self {
        case .modelNotFound(let name):
            "Core ML model '\(name).mlmodel' not found in app bundle."
        case .modelLoadFailed(let reason):
            "Failed to load Core ML model: \(reason)"
        }
    }
}

final class CoreMLModelService {
    private static let modelName = "DamageDetector"

    private var loadedModel: VNCoreMLModel?

    var isModelLoaded: Bool {
        loadedModel != nil
    }

    func loadModel() async throws {
        if loadedModel != nil {
            return
        }

        let config = MLModelConfiguration()
        config.computeUnits = .all

        guard let modelURL = Bundle.main.url(forResource: Self.modelName, withExtension: "mlmodelc") else {
            throw CoreMLModelError.modelNotFound(Self.modelName)
        }

        let compiledModel = try MLModel(contentsOf: modelURL, configuration: config)
        let visionModel = try VNCoreMLModel(for: compiledModel)
        loadedModel = visionModel
    }

    func getVisionModel() throws -> VNCoreMLModel {
        guard let loadedModel else {
            throw CoreMLModelError.modelNotFound(Self.modelName)
        }
        return loadedModel
    }
}
