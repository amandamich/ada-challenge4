import CoreGraphics
import SwiftUI

struct CameraView: View {
    let isStreaming: Bool
    let packetCount: Int
    let byteCount: Int
    let nalUnitCount: Int
    let spsCount: Int
    let ppsCount: Int
    let frameCount: Int
    let decodedFrameCount: Int
    let latestFrame: CGImage?
    var detections: [DetectionResult] = []

    var body: some View {
        ZStack {
            Rectangle()
                .fill(.black.opacity(0.85))

            if let latestFrame {
                GeometryReader { geometry in
                    let imageSize = CGSize(width: latestFrame.width, height: latestFrame.height)
                    let fittedSize = fittedImageSize(for: imageSize, in: geometry.size)

                    ZStack {
                        Image(decorative: latestFrame, scale: 1)
                            .resizable()
                            .scaledToFit()
                            .frame(width: fittedSize.width, height: fittedSize.height)

                        if !detections.isEmpty {
                            ForEach(detections) { detection in
                                DamageMarkerView(
                                    detection: detection,
                                    viewSize: fittedSize
                                )
                            }
                        }
                    }
                    .frame(width: fittedSize.width, height: fittedSize.height)
                    .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
                }
            }

            VStack(spacing: 12) {
                if latestFrame == nil {
                    Image(systemName: isStreaming ? "video.fill" : "video")
                        .font(.largeTitle)
                        .foregroundStyle(isStreaming ? .green : .white)

                    Text(isStreaming ? "Decoding Video Stream" : "Video Stream Stopped")
                        .font(.headline)
                        .foregroundStyle(.white)
                }

                VStack(spacing: 4) {
                    Text("Packets: \(packetCount)  Bytes: \(byteCount)")
                    Text("NAL: \(nalUnitCount)  SPS: \(spsCount)  PPS: \(ppsCount)  Frames: \(frameCount)")
                    Text("Decoded: \(decodedFrameCount)")
                    if !detections.isEmpty {
                        Text("Detections: \(detections.count)")
                            .foregroundStyle(.red)
                    }
                }
                .font(.caption.monospacedDigit())
                .padding(8)
                .background(.black.opacity(0.5), in: RoundedRectangle(cornerRadius: 6))
                .foregroundStyle(.white.opacity(0.85))
            }
        }
        .aspectRatio(imageAspectRatio, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .padding()
    }

    private var imageAspectRatio: CGFloat {
        guard let latestFrame else { return 16 / 9 }
        return CGFloat(latestFrame.width) / CGFloat(latestFrame.height)
    }

    private func fittedImageSize(for imageSize: CGSize, in containerSize: CGSize) -> CGSize {
        guard imageSize.width > 0, imageSize.height > 0,
              containerSize.width > 0, containerSize.height > 0 else {
            return .zero
        }

        let imageAspectRatio = imageSize.width / imageSize.height
        let containerAspectRatio = containerSize.width / containerSize.height

        if imageAspectRatio > containerAspectRatio {
            return CGSize(
                width: containerSize.width,
                height: containerSize.width / imageAspectRatio
            )
        } else {
            return CGSize(
                width: containerSize.height * imageAspectRatio,
                height: containerSize.height
            )
        }
    }
}

#Preview {
    CameraView(
        isStreaming: true,
        packetCount: 128,
        byteCount: 188_416,
        nalUnitCount: 42,
        spsCount: 1,
        ppsCount: 1,
        frameCount: 20,
        decodedFrameCount: 12,
        latestFrame: nil
    )
}
