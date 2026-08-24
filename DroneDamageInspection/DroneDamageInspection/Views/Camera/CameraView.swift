import SwiftUI

struct CameraView: View {
    var body: some View {
        ZStack {
            Rectangle()
                .fill(.black.opacity(0.85))

            Image(systemName: "video")
                .font(.largeTitle)
                .foregroundStyle(.white)
        }
        .aspectRatio(16 / 9, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .padding()
    }
}

#Preview {
    CameraView()
}
