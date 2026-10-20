#if os(macOS)
import AppKit
#endif
import CoreGraphics
import ImageIO
import SwiftUI
import UniformTypeIdentifiers

struct LiveInspectionView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var droneViewModel = DroneViewModel()
    @State private var inspectionViewModel = InspectionViewModel()
    @State private var gameControllerInputManager = GameControllerInputManager()
    @State private var inspectionRecords: [InspectionRecord] = []
    @State private var inspectionStatusMessage: String?
    @State private var inspectionStatusIsError = false
    @State private var mockDetectionMode = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    DroneStatusView(
                        isConnected: droneViewModel.isConnected,
                        batteryLevel: droneViewModel.batteryLevel,
                        altitude: droneViewModel.altitude,
                        speed: droneViewModel.speed,
                        temperature: droneViewModel.temperature,
                        flightTime: droneViewModel.flightTime
                    )

                    InspectionZoneSelectorView(inspectionViewModel: inspectionViewModel)

                    CameraView(
                        isStreaming: droneViewModel.isVideoStreaming,
                        packetCount: droneViewModel.videoPacketCount,
                        byteCount: droneViewModel.videoByteCount,
                        nalUnitCount: droneViewModel.videoNALUnitCount,
                        spsCount: droneViewModel.videoSPSCount,
                        ppsCount: droneViewModel.videoPPSCount,
                        frameCount: droneViewModel.videoFrameCount,
                        decodedFrameCount: droneViewModel.decodedVideoFrameCount,
                        latestFrame: droneViewModel.latestVideoFrame,
                        detections: inspectionViewModel.trackedDetections
                    )

                    DroneControlView(
                        isConnected: droneViewModel.isConnected,
                        connectAction: {
                            Task { await droneViewModel.connect() }
                        },
                        takeOffAction: {
                            Task { await droneViewModel.takeOff() }
                        },
                        landAction: {
                            Task { await droneViewModel.land() }
                        },
                        startStreamAction: {
                            Task {
                                await droneViewModel.startVideoStream()
                                await inspectionViewModel.loadModel()
                                await MainActor.run {
                                    mockDetectionMode = inspectionViewModel.usesMockDetection
                                }
                            }
                        },
                        stopStreamAction: {
                            Task { await droneViewModel.stopVideoStream() }
                        },
                        refreshBatteryAction: {
                            Task { await droneViewModel.refreshBattery() }
                        },
                        joystickControlAction: { input in
                            Task { await droneViewModel.sendJoystickControl(input) }
                        },
                        isGameControllerConnected: gameControllerInputManager.isControllerConnected,
                        gameControllerName: gameControllerInputManager.controllerName
                    )

                    if let errorMessage = droneViewModel.errorMessage {
                        Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.leading)
                            .padding(.horizontal)
                    }

                    HStack(spacing: 12) {
                        Button("Inspect Frame") {
                            Task {
                                await inspectCurrentFrame()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.orange)
                        .disabled(droneViewModel.latestVideoFrame == nil || inspectionViewModel.isDetecting)

                        Button("Capture Frame") {
                            captureCurrentFrame()
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(droneViewModel.latestVideoFrame == nil)

                        Button(droneViewModel.isRecordingVideo ? "Stop Recording" : "Start Recording") {
                            Task {
                                if droneViewModel.isRecordingVideo {
                                    await droneViewModel.stopVideoRecording()
                                } else {
                                    await droneViewModel.startVideoRecording()
                                }
                            }
                        }
                        .buttonStyle(.bordered)
                        .disabled(!droneViewModel.isVideoStreaming)

                        if let recordingURL = droneViewModel.lastRecordingURL {
                            Button {
                                revealFile(recordingURL)
                            } label: {
                                Image(systemName: "folder")
                            }
                            .buttonStyle(.borderless)
                            .help("Reveal recording in Finder")
                        }
                    }

                    if inspectionViewModel.isDetecting {
                        HStack(spacing: 8) {
                            ProgressView()
                                .controlSize(.small)
                            Text("Running detection...")
                                .font(.subheadline.weight(.medium))
                        }
                        .foregroundStyle(.orange)
                        .padding(.horizontal)
                    }

                    if let inspectionStatusMessage {
                        Label(inspectionStatusMessage, systemImage: inspectionStatusIsError ? "xmark.circle.fill" : "checkmark.circle.fill")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(inspectionStatusIsError ? .red : .green)
                            .multilineTextAlignment(.leading)
                            .textSelection(.enabled)
                            .padding(.horizontal)
                    }

                    if let errorMessage = inspectionViewModel.errorMessage {
                        Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.leading)
                            .padding(.horizontal)
                            .padding(.horizontal)
                    }

                    if mockDetectionMode && droneViewModel.isVideoStreaming {
                        Label("Heuristic detection — multi-class (Crack/Surface Damage/Corrosion) without mlmodel", systemImage: "wand.and.stars")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.purple)
                            .padding(.horizontal)
                    } else if !mockDetectionMode && droneViewModel.isVideoStreaming && inspectionViewModel.errorMessage != nil {
                        Label("DamageDetector.mlmodel not found. Detection unavailable.", systemImage: "exclamationmark.triangle.fill")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.orange)
                            .padding(.horizontal)
                    }

                    if !droneViewModel.rawStateMessage.isEmpty {
                        Text(droneViewModel.rawStateMessage)
                            .font(.caption2.monospaced())
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                            .padding(.horizontal)
                    }

                    if !inspectionViewModel.trackedDetections.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Current Detections")
                                .font(.headline)
                                .padding(.horizontal)

                            ForEach(inspectionViewModel.trackedDetections) { detection in
                                HStack(spacing: 8) {
                                    Circle()
                                        .fill(.red)
                                        .frame(width: 6, height: 6)

                                    Text(detection.damageType)
                                        .font(.caption.weight(.semibold))

                                    Text(detection.confidence.formatted(.percent.precision(.fractionLength(1))))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)

                                    Spacer()
                                }
                                .padding(.horizontal)
                            }
                        }
                    }

                    BuildingInspectionMapView(damages: inspectionViewModel.detectedDamage)

                    InspectionResultView(records: inspectionRecords)
                }
                .padding(.bottom, 24)
            }
            .navigationTitle("Drone Inspection")
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase != .active {
                gameControllerInputManager.stopMonitoring()
                droneViewModel.shutdownForAppExit()
            } else {
                startGameControllerInput()
            }
        }
        .onAppear {
            startGameControllerInput()
        }
        .onDisappear {
            gameControllerInputManager.stopMonitoring()
            droneViewModel.shutdownForAppExit()
        }
    }

    private func startGameControllerInput() {
        gameControllerInputManager.onJoystickInput = { input in
            Task { await droneViewModel.sendJoystickControl(input) }
        }
        gameControllerInputManager.startMonitoring()
    }

    private func inspectCurrentFrame() async {
        guard let latestFrame = droneViewModel.latestVideoFrame else {
            print("[Inspection] No video frame available")
            inspectionStatusMessage = "No video frame available."
            inspectionStatusIsError = true
            return
        }

        print("[Inspection] Starting inspection on frame \(latestFrame.width)x\(latestFrame.height)")
        inspectionStatusMessage = "Running detection on frame..."
        inspectionStatusIsError = false

        await inspectionViewModel.detectDamage(in: latestFrame)

        if let error = inspectionViewModel.errorMessage {
            inspectionStatusMessage = "Detection failed: \(error)"
            inspectionStatusIsError = true
            print("[Inspection] Detection error: \(error)")
        } else if inspectionViewModel.trackedDetections.isEmpty {
            inspectionStatusMessage = "No damage detected in this frame."
            inspectionStatusIsError = false
            print("[Inspection] No damage detected")
        } else if inspectionViewModel.lastNewDamageCount == 0 {
            let types = inspectionViewModel.trackedDetections.map { "\($0.damageType) (\(Int($0.confidence * 100))%)" }
            inspectionStatusMessage = "Tracked existing damage: \(types.joined(separator: ", "))"
            inspectionStatusIsError = false
            print("[Inspection] Tracked existing damage: \(types.joined(separator: ", "))")
        } else {
            let zoneName = inspectionViewModel.currentInspectionZone.displayName
            inspectionStatusMessage = "Recorded \(inspectionViewModel.lastNewDamageCount) new damage(s) in \(zoneName)."
            inspectionStatusIsError = false
            print("[Inspection] Recorded \(inspectionViewModel.lastNewDamageCount) new damage(s) in \(zoneName)")
        }

        inspectionViewModel.captureAndInspect(latestFrame)
        inspectionRecords = inspectionViewModel.inspectionRecords
    }

    private func captureCurrentFrame() {
        guard let latestFrame = droneViewModel.latestVideoFrame else { return }

        do {
            let annotatedImage: CGImage
            if !inspectionViewModel.trackedDetections.isEmpty {
                annotatedImage = ImageAnnotationRenderer.renderDetections(on: latestFrame, detections: inspectionViewModel.trackedDetections) ?? latestFrame
            } else {
                annotatedImage = latestFrame
            }

            let imageFileURL = try saveCapturedImage(annotatedImage)
            inspectionRecords.insert(
                InspectionRecord(
                    imageFileURL: imageFileURL,
                    capturedImage: annotatedImage
                ),
                at: 0
            )
            inspectionStatusMessage = "Saved capture: \(imageFileURL.path)"
            inspectionStatusIsError = false
        } catch {
            inspectionStatusMessage = error.localizedDescription
            inspectionStatusIsError = true
        }
    }

    private func revealFile(_ url: URL) {
        #if os(macOS)
        NSWorkspace.shared.activateFileViewerSelecting([url])
        #endif
    }

    private func saveCapturedImage(_ image: CGImage) throws -> URL {
        let documentsURL = try FileManager.default.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let directoryURL = documentsURL.appendingPathComponent("DroneDamageInspectionCaptures", isDirectory: true)
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)

        let fileURL = directoryURL.appendingPathComponent("inspection-\(UUID().uuidString).png")
        guard let destination = CGImageDestinationCreateWithURL(
            fileURL as CFURL,
            UTType.png.identifier as CFString,
            1,
            nil
        ) else {
            throw LiveInspectionCaptureError.cannotCreateImageDestination
        }

        CGImageDestinationAddImage(destination, image, nil)

        guard CGImageDestinationFinalize(destination) else {
            throw LiveInspectionCaptureError.cannotWriteImage
        }

        return fileURL
    }
}

private enum LiveInspectionCaptureError: LocalizedError {
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

#Preview {
    LiveInspectionView()
}
