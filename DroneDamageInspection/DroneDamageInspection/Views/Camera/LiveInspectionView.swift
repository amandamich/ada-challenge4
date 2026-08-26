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
    @State private var inspectionRecords: [InspectionRecord] = []
    @State private var inspectionStatusMessage: String?
    @State private var inspectionStatusIsError = false

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

                    CameraView(
                        isStreaming: droneViewModel.isVideoStreaming,
                        packetCount: droneViewModel.videoPacketCount,
                        byteCount: droneViewModel.videoByteCount,
                        nalUnitCount: droneViewModel.videoNALUnitCount,
                        spsCount: droneViewModel.videoSPSCount,
                        ppsCount: droneViewModel.videoPPSCount,
                        frameCount: droneViewModel.videoFrameCount,
                        decodedFrameCount: droneViewModel.decodedVideoFrameCount,
                        latestFrame: droneViewModel.latestVideoFrame
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
                            Task { await droneViewModel.startVideoStream() }
                        },
                        stopStreamAction: {
                            Task { await droneViewModel.stopVideoStream() }
                        },
                        moveForwardAction: {
                            Task { await droneViewModel.moveForward() }
                        },
                        moveBackwardAction: {
                            Task { await droneViewModel.moveBackward() }
                        },
                        moveLeftAction: {
                            Task { await droneViewModel.moveLeft() }
                        },
                        moveRightAction: {
                            Task { await droneViewModel.moveRight() }
                        },
                        moveUpAction: {
                            Task { await droneViewModel.moveUp() }
                        },
                        moveDownAction: {
                            Task { await droneViewModel.moveDown() }
                        },
                        rotateClockwiseAction: {
                            Task { await droneViewModel.rotateClockwise() }
                        },
                        rotateCounterClockwiseAction: {
                            Task { await droneViewModel.rotateCounterClockwise() }
                        },
                        refreshBatteryAction: {
                            Task { await droneViewModel.refreshBattery() }
                        }
                    )

                    if let errorMessage = droneViewModel.errorMessage {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.leading)
                    }

                    if !droneViewModel.rawStateMessage.isEmpty {
                        Text(droneViewModel.rawStateMessage)
                            .font(.caption2.monospaced())
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                            .padding(.horizontal)
                    }

                    HStack(spacing: 12) {
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

                    if let recordingMessage = droneViewModel.recordingMessage {
                        Text(recordingMessage)
                            .font(.footnote)
                            .foregroundStyle(droneViewModel.isRecordingVideo ? .red : .secondary)
                            .multilineTextAlignment(.leading)
                            .textSelection(.enabled)
                            .padding(.horizontal)
                    }

                    if let inspectionStatusMessage {
                        Text(inspectionStatusMessage)
                            .font(.footnote)
                            .foregroundStyle(inspectionStatusIsError ? .red : .secondary)
                            .multilineTextAlignment(.leading)
                            .textSelection(.enabled)
                            .padding(.horizontal)
                    }

                    InspectionResultView(records: inspectionRecords)
                }
                .padding(.bottom, 24)
            }
            .navigationTitle("Drone Inspection")
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase != .active {
                droneViewModel.shutdownForAppExit()
            }
        }
        .onDisappear {
            droneViewModel.shutdownForAppExit()
        }
    }

    private func captureCurrentFrame() {
        guard let latestFrame = droneViewModel.latestVideoFrame else { return }

        do {
            let imageFileURL = try saveCapturedImage(latestFrame)
            inspectionRecords.insert(
                InspectionRecord(
                    imageFileURL: imageFileURL,
                    capturedImage: latestFrame
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
