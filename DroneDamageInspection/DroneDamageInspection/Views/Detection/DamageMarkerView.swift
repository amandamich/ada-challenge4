import SwiftUI

struct DamageMarkerView: View {
    let detection: DetectionResult
    let viewSize: CGSize

    private var normalizedBox: CGRect {
        let box = detection.boundingBox
        return CGRect(
            x: box.origin.x * viewSize.width,
            y: (1 - box.origin.y - box.height) * viewSize.height,
            width: box.width * viewSize.width,
            height: box.height * viewSize.height
        )
    }

    var body: some View {
        let box = normalizedBox

        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 2)
                .stroke(.red, lineWidth: 2)

            Text(damageLabel)
                .font(.caption2.weight(.semibold))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(.red.opacity(0.85), in: Capsule())
                .foregroundStyle(.white)
                .offset(x: 0, y: -20)
        }
        .frame(width: box.width, height: box.height)
        .position(x: box.midX, y: box.midY)
    }

    private var damageLabel: String {
        let confidence = Int(detection.confidence * 100)
        return "\(detection.damageType) \(confidence)% - \(buildingZone)"
    }

    private var buildingZone: String {
        let box = detection.boundingBox
        let centerX = box.midX
        let centerYFromTop = 1 - box.midY
        let horizontalZone = zone(
            value: centerX,
            lowerLabel: "kiri",
            middleLabel: "tengah",
            upperLabel: "kanan"
        )
        let verticalZone = zone(
            value: centerYFromTop,
            lowerLabel: "atas",
            middleLabel: "tengah",
            upperLabel: "bawah"
        )

        return "\(verticalZone)-\(horizontalZone)"
    }

    private func zone(
        value: CGFloat,
        lowerLabel: String,
        middleLabel: String,
        upperLabel: String
    ) -> String {
        if value < 1.0 / 3.0 {
            return lowerLabel
        } else if value < 2.0 / 3.0 {
            return middleLabel
        } else {
            return upperLabel
        }
    }
}

#Preview {
    DamageMarkerView(
        detection: DetectionResult(
            damageType: "Crack",
            confidence: 0.91,
            boundingBox: CGRect(x: 0.3, y: 0.4, width: 0.2, height: 0.15)
        ),
        viewSize: CGSize(width: 400, height: 300)
    )
}
