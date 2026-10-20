import SwiftUI

struct DroneControlView: View {
    let isConnected: Bool
    let connectAction: () -> Void
    let takeOffAction: () -> Void
    let landAction: () -> Void
    let startStreamAction: () -> Void
    let stopStreamAction: () -> Void
    let refreshBatteryAction: () -> Void
    let joystickControlAction: (DroneJoystickInput) -> Void
    let isGameControllerConnected: Bool
    let gameControllerName: String

    @State private var leftStick = CGPoint.zero
    @State private var rightStick = CGPoint.zero
    @State private var joystickRepeatTask: Task<Void, Never>?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label(
                        isConnected ? "Drone Connected" : "Drone Disconnected",
                        systemImage: isConnected ? "antenna.radiowaves.left.and.right" : "antenna.radiowaves.left.and.right.slash"
                    )
                        .font(.headline)
                        .foregroundStyle(isConnected ? .green : .secondary)

                    Spacer()

                    Label(
                        isGameControllerConnected ? gameControllerName : "DualSense not connected",
                        systemImage: isGameControllerConnected ? "gamecontroller.fill" : "gamecontroller"
                    )
                    .font(.caption.weight(.medium))
                    .foregroundStyle(isGameControllerConnected ? .green : .secondary)
                }

                HStack(spacing: 10) {
                    Button(action: connectAction) {
                        Label("Connect", systemImage: "link")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isConnected)

                    Button(action: takeOffAction) {
                        Label("Take Off", systemImage: "arrow.up.circle")
                    }
                    .buttonStyle(.bordered)
                    .disabled(!isConnected)

                    Button(action: landAction) {
                        Label("Land", systemImage: "arrow.down.circle")
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                    .disabled(!isConnected)
                }

                HStack(spacing: 10) {
                    Button(action: startStreamAction) {
                        Label("Start Stream", systemImage: "video")
                    }
                    .buttonStyle(.bordered)
                    .disabled(!isConnected)

                    Button(action: stopStreamAction) {
                        Label("Stop Stream", systemImage: "video.slash")
                    }
                    .buttonStyle(.bordered)
                    .disabled(!isConnected)

                    Button(action: refreshBatteryAction) {
                        Label("Battery", systemImage: "battery.75")
                    }
                    .buttonStyle(.bordered)
                    .disabled(!isConnected)
                }

                HStack(spacing: 24) {
                    JoystickPadView(
                        title: "Altitude / Yaw",
                        value: $leftStick,
                        isEnabled: isConnected,
                        horizontalLabel: "Yaw",
                        verticalLabel: "Up"
                    ) {
                        sendJoystickInput()
                    }

                    JoystickPadView(
                        title: "Move",
                        value: $rightStick,
                        isEnabled: isConnected,
                        horizontalLabel: "Left / Right",
                        verticalLabel: "Forward"
                    ) {
                        sendJoystickInput()
                    }
                }

                Button {
                    leftStick = .zero
                    rightStick = .zero
                    sendJoystickInput()
                } label: {
                    Label("Stop Joystick", systemImage: "stop.circle")
                }
                .buttonStyle(.bordered)
                .disabled(!isConnected)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(.secondary.opacity(0.10), in: RoundedRectangle(cornerRadius: 8))
        }
        .padding()
        .onDisappear {
            joystickRepeatTask?.cancel()
            joystickRepeatTask = nil
            joystickControlAction(.zero)
        }
    }

    private func sendJoystickInput() {
        let input = DroneJoystickInput(
            leftRight: Double(rightStick.x),
            forwardBack: Double(rightStick.y),
            upDown: Double(leftStick.y),
            yaw: Double(leftStick.x)
        )

        joystickControlAction(input)

        if input == .zero {
            joystickRepeatTask?.cancel()
            joystickRepeatTask = nil
        } else if joystickRepeatTask == nil {
            joystickRepeatTask = Task {
                while !Task.isCancelled {
                    try? await Task.sleep(for: .milliseconds(100))
                    await MainActor.run {
                        sendJoystickInput()
                    }
                }
            }
        }
    }
}

private struct JoystickPadView: View {
    let title: String
    @Binding var value: CGPoint
    let isEnabled: Bool
    let horizontalLabel: String
    let verticalLabel: String
    let onChange: () -> Void

    private let size: CGFloat = 130
    private let knobSize: CGFloat = 42

    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))

            ZStack {
                Circle()
                    .fill(.black.opacity(0.08))
                Circle()
                    .stroke(.secondary.opacity(0.35), lineWidth: 1)
                Path { path in
                    path.move(to: CGPoint(x: size / 2, y: 10))
                    path.addLine(to: CGPoint(x: size / 2, y: size - 10))
                    path.move(to: CGPoint(x: 10, y: size / 2))
                    path.addLine(to: CGPoint(x: size - 10, y: size / 2))
                }
                .stroke(.secondary.opacity(0.25), lineWidth: 1)

                Circle()
                    .fill(isEnabled ? .blue.opacity(0.85) : .secondary.opacity(0.45))
                    .frame(width: knobSize, height: knobSize)
                    .offset(
                        x: value.x * travelRadius,
                        y: -value.y * travelRadius
                    )
            }
            .frame(width: size, height: size)
            .gesture(dragGesture)
            .opacity(isEnabled ? 1 : 0.5)

            VStack(spacing: 2) {
                Text(verticalLabel)
                Text(horizontalLabel)
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var travelRadius: CGFloat {
        (size - knobSize) / 2
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { gesture in
                guard isEnabled else { return }

                let translation = gesture.translation
                let rawX = translation.width / travelRadius
                let rawY = -translation.height / travelRadius
                let point = CGPoint(x: rawX, y: rawY)
                value = clamped(point)
                onChange()
            }
            .onEnded { _ in
                value = .zero
                onChange()
            }
    }

    private func clamped(_ point: CGPoint) -> CGPoint {
        let distance = sqrt(point.x * point.x + point.y * point.y)
        guard distance > 1 else { return point }

        return CGPoint(
            x: point.x / distance,
            y: point.y / distance
        )
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
        refreshBatteryAction: {},
        joystickControlAction: { _ in },
        isGameControllerConnected: true,
        gameControllerName: "DualSense Wireless Controller"
    )
}
