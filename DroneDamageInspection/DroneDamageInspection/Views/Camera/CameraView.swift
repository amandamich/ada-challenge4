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

    var body: some View {
        ZStack {
            Rectangle()
                .fill(.black.opacity(0.85))

            if let latestFrame {
                Image(decorative: latestFrame, scale: 1)
                    .resizable()
                    .scaledToFit()
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
                }
                .font(.caption.monospacedDigit())
                .padding(8)
                .background(.black.opacity(0.5), in: RoundedRectangle(cornerRadius: 6))
                .foregroundStyle(.white.opacity(0.85))
            }
        }
        .aspectRatio(16 / 9, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .padding()
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
