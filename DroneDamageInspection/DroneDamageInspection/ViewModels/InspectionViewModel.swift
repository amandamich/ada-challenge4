import CoreGraphics
import Foundation
import ImageIO
import Observation
import UniformTypeIdentifiers

@MainActor
@Observable
final class InspectionViewModel {
    private(set) var detectedDamage: [Damage] = []
    private(set) var inspectionRecords: [InspectionRecord] = []
    private(set) var errorMessage: String?

    private let damageDetectionService: DamageDetectionService

    init(damageDetectionService: DamageDetectionService = DamageDetectionService()) {
        self.damageDetectionService = damageDetectionService
    }

    func captureFrame(_ image: CGImage) {
        do {
            let imageFileURL = try saveCapturedImage(image)
            inspectionRecords.insert(
                InspectionRecord(
                    imageFileURL: imageFileURL,
                    capturedImage: image
                ),
                at: 0
            )
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func inspectCurrentFrame() async {
        do {
            detectedDamage = try await damageDetectionService.detectDamage()
            inspectionRecords.insert(
                InspectionRecord(damageTypes: detectedDamage.map(\.type)),
                at: 0
            )
            errorMessage = nil
        } catch {
            detectedDamage = []
            errorMessage = error.localizedDescription
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
