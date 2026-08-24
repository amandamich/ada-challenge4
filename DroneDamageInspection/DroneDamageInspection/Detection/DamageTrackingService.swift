import Foundation

final class DamageTrackingService {
    private(set) var trackedResults: [DetectionResult] = []

    func update(with results: [DetectionResult]) {
        trackedResults = results
    }

    func clear() {
        trackedResults.removeAll()
    }
}
