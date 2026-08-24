import SwiftUI

struct DamageDetailView: View {
    let title: String
    let confidence: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            Text("Confidence: \(confidence.formatted(.percent.precision(.fractionLength(1))))")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}

#Preview {
    DamageDetailView(title: "Crack", confidence: 0.91)
}
