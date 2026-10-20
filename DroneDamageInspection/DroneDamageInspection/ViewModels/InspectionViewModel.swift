import CoreGraphics
import Foundation
import ImageIO
import Observation
import UniformTypeIdentifiers

@MainActor
@Observable
final class InspectionViewModel {
    private(set) var detectedDamage: [Damage] = []
    private(set) var trackedDetections: [DetectionResult] = []
    private(set) var inspectionRecords: [InspectionRecord] = []
    private(set) var isDetecting = false
    private(set) var errorMessage: String?
    private(set) var lastNewDamageCount = 0
    var currentInspectionZone = BuildingZone.defaultZone
    var usesMockDetection: Bool { damageDetectionService.mockMode }

    private let damageDetectionService: DamageDetectionService
    private let damageTrackingService: DamageTrackingService

    init(
        damageDetectionService: DamageDetectionService? = nil,
        damageTrackingService: DamageTrackingService? = nil
    ) {
        self.damageDetectionService = damageDetectionService ?? DamageDetectionService()
        self.damageTrackingService = damageTrackingService ?? DamageTrackingService()
    }

    func loadModel() async {
        do {
            print("[Inspection] Loading Core ML model...")
            try await damageDetectionService.loadModel()
            if damageDetectionService.mockMode {
                errorMessage = nil
                print("[Inspection] Using mock detection mode (no .mlmodel found).")
            } else {
                errorMessage = nil
                print("[Inspection] Model loaded successfully.")
            }
        } catch {
            errorMessage = error.localizedDescription
            print("[Inspection] Model load FAILED: \(error.localizedDescription)")
        }
    }

    func detectDamage(in image: CGImage) async {
        guard !isDetecting else {
            print("[Inspection] Detection already in progress, skipping.")
            return
        }
        isDetecting = true
        defer { isDetecting = false }

        do {
            print("[Inspection] Running detection on \(image.width)x\(image.height) image...")
            let rawDetections = try await damageDetectionService.detectDamage(in: image)
            print("[Inspection] Raw detections: \(rawDetections.count)")
            let existingTrackedIDs = Set(trackedDetections.map(\.id))
            let tracked = damageTrackingService.update(with: rawDetections)
            print("[Inspection] Tracked detections: \(tracked.count)")
            trackedDetections = tracked
            let newDetections = tracked.filter { !existingTrackedIDs.contains($0.id) }
            lastNewDamageCount = newDetections.count
            try saveNewDamageRecords(from: newDetections, sourceImage: image)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
            print("[Inspection] Detection FAILED: \(error.localizedDescription)")
        }
    }

    func captureAndInspect(_ image: CGImage) {
        do {
            let annotatedImage: CGImage
            if !trackedDetections.isEmpty {
                annotatedImage = ImageAnnotationRenderer.renderDetections(on: image, detections: trackedDetections) ?? image
            } else {
                annotatedImage = image
            }

            let imageFileURL = try saveCapturedImage(annotatedImage)

            let record = InspectionRecord(
                damageTypes: trackedDetections.map(\.damageType),
                detections: trackedDetections,
                imageFileURL: imageFileURL,
                capturedImage: annotatedImage
            )
            inspectionRecords.insert(record, at: 0)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func clearTracking() {
        damageTrackingService.clear()
        trackedDetections = []
        lastNewDamageCount = 0
    }

    func damages(in zone: BuildingZone) -> [Damage] {
        detectedDamage.filter { $0.inspectionZone == zone }
    }

    private func saveNewDamageRecords(
        from detections: [DetectionResult],
        sourceImage: CGImage
    ) throws {
        guard !detections.isEmpty else { return }

        for detection in detections {
            let evidenceImage = ImageAnnotationRenderer.renderDetections(
                on: sourceImage,
                detections: [detection]
            ) ?? sourceImage
            let evidenceURL = try saveCapturedImage(evidenceImage)
            let damage = Damage(
                id: detection.id,
                type: detection.damageType,
                confidence: detection.confidence,
                boundingBox: detection.boundingBox,
                inspectionZone: currentInspectionZone,
                evidenceImageFileURL: evidenceURL,
                evidenceImage: evidenceImage
            )
            detectedDamage.insert(damage, at: 0)
        }
    }

    private func saveCapturedImage(_ image: CGImage) throws -> URL {
        let directoryURL = try captureDirectoryURL()
        let fileName = "inspection-\(UUID().uuidString).png"
        let fileURL = directoryURL.appendingPathComponent(fileName)

        guard let destination = CGImageDestinationCreateWithURL(
            fileURL as CFURL,
            UTType.png.identifier as CFString,
            1,
            nil
        ) else {
            throw InspectionCaptureError.cannotCreateImageDestination
        }

        CGImageDestinationAddImage(destination, image, nil)

        guard CGImageDestinationFinalize(destination) else {
            throw InspectionCaptureError.cannotWriteImage
        }

        return fileURL
    }

    private func captureDirectoryURL() throws -> URL {
        let documentsURL = try FileManager.default.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let directoryURL = documentsURL.appendingPathComponent("DroneDamageInspectionCaptures", isDirectory: true)
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        return directoryURL
    }
}

enum InspectionCaptureError: LocalizedError {
    case cannotCreateImageDestination
    case cannotWriteImage

    var errorDescription: String? {
        switch self {
        case .cannotCreateImageDestination:
            "Could not prepare the captured image file."
        case .cannotWriteImage:
            "Could not save the captured image."
        }
    }
}
