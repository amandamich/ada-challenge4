import SwiftUI

struct DroneControlView: View {
    let isConnected: Bool
    let connectAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(isConnected ? "Drone Connected" : "Drone Disconnected")
                .font(.headline)

            Button("Connect Drone", action: connectAction)
                .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}

#Preview {
    DroneControlView(isConnected: false) {}
}
