import SwiftUI

struct DamageMarkerView: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.red.opacity(0.85), in: Capsule())
            .foregroundStyle(.white)
    }
}

#Preview {
    DamageMarkerView(title: "Crack")
}
