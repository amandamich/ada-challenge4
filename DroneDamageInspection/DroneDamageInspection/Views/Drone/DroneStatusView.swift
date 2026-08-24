import SwiftUI

struct DroneStatusView: View {
    let isConnected: Bool
    let batteryLevel: Int
    let altitude: Double

    var body: some View {
        HStack(spacing: 16) {
            Label(isConnected ? "Connected" : "Disconnected", systemImage: isConnected ? "wifi" : "wifi.slash")
            Label("Battery \(batteryLevel)%", systemImage: "battery.75")
            Label("\(altitude.formatted()) m", systemImage: "arrow.up")
        }
        .font(.subheadline)
        .foregroundStyle(.secondary)
    }
}

#Preview {
    DroneStatusView(isConnected: false, batteryLevel: 0, altitude: 0)
}
