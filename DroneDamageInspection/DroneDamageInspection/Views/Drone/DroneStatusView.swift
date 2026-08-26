import SwiftUI

struct DroneStatusView: View {
    let isConnected: Bool
    let batteryLevel: Int
    let altitude: Double
    let speed: Double
    let temperature: Int
    let flightTime: Int

    var body: some View {
        Grid(horizontalSpacing: 16, verticalSpacing: 8) {
            GridRow {
                Label(isConnected ? "Connected" : "Disconnected", systemImage: isConnected ? "wifi" : "wifi.slash")
                Label("Battery \(batteryLevel)%", systemImage: "battery.75")
                Label("\(altitude.metersText)", systemImage: "arrow.up")
            }

            GridRow {
                Label("\(speed.formatted()) cm/s", systemImage: "speedometer")
                Label("\(temperature) C", systemImage: "thermometer.medium")
                Label("\(flightTime) s", systemImage: "timer")
            }
        }
        .font(.subheadline)
        .foregroundStyle(.secondary)
    }
}

#Preview {
    DroneStatusView(
        isConnected: false,
        batteryLevel: 0,
        altitude: 0,
        speed: 0,
        temperature: 0,
        flightTime: 0
    )
}
