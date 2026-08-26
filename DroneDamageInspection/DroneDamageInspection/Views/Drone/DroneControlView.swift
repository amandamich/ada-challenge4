import SwiftUI

struct DroneControlView: View {
    let isConnected: Bool
    let connectAction: () -> Void
    let takeOffAction: () -> Void
    let landAction: () -> Void
    let startStreamAction: () -> Void
    let stopStreamAction: () -> Void
    let moveForwardAction: () -> Void
    let moveBackwardAction: () -> Void
    let moveLeftAction: () -> Void
    let moveRightAction: () -> Void
    let moveUpAction: () -> Void
    let moveDownAction: () -> Void
    let rotateClockwiseAction: () -> Void
    let rotateCounterClockwiseAction: () -> Void
    let refreshBatteryAction: () -> Void

    var body: some View {
        VStack(alignment: .center, spacing: 12) {
            Text(isConnected ? "Drone Connected" : "Drone Disconnected")
                .font(.headline)

            HStack(spacing: 12) {
                Button("Connect", action: connectAction)
                    .buttonStyle(.borderedProminent)
                    .disabled(isConnected)

                Button("Take Off", action: takeOffAction)
                    .buttonStyle(.bordered)
                    .disabled(!isConnected)

                Button("Land", action: landAction)
                    .buttonStyle(.bordered)
                    .disabled(!isConnected)

                Button("Battery", action: refreshBatteryAction)
                    .buttonStyle(.bordered)
                    .disabled(!isConnected)
            }

            HStack(spacing: 12) {
                Button("Start Stream", action: startStreamAction)
                    .buttonStyle(.bordered)
                    .disabled(!isConnected)

                Button("Stop Stream", action: stopStreamAction)
                    .buttonStyle(.bordered)
                    .disabled(!isConnected)
            }

            VStack(spacing: 8) {
                Button("Forward 30cm", action: moveForwardAction)
                    .buttonStyle(.bordered)
                    .disabled(!isConnected)

                HStack(spacing: 8) {
                    Button("Left 30cm", action: moveLeftAction)
                    Button("Up 30cm", action: moveUpAction)
                    Button("Down 30cm", action: moveDownAction)
                    Button("Right 30cm", action: moveRightAction)
                }
                .buttonStyle(.bordered)
                .disabled(!isConnected)

                Button("Back 30cm", action: moveBackwardAction)
                    .buttonStyle(.bordered)
                    .disabled(!isConnected)

                HStack(spacing: 8) {
                    Button("Rotate CCW 30", action: rotateCounterClockwiseAction)
                    Button("Rotate CW 30", action: rotateClockwiseAction)
                }
                .buttonStyle(.bordered)
                .disabled(!isConnected)
            }
        }
        .padding()
    }
}

#Preview {
    DroneControlView(
        isConnected: false,
        connectAction: {},
        takeOffAction: {},
        landAction: {},
        startStreamAction: {},
        stopStreamAction: {},
        moveForwardAction: {},
        moveBackwardAction: {},
        moveLeftAction: {},
        moveRightAction: {},
        moveUpAction: {},
        moveDownAction: {},
        rotateClockwiseAction: {},
        rotateCounterClockwiseAction: {},
        refreshBatteryAction: {}
    )
}
