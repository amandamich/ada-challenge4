import Foundation
import GameController

@MainActor
@Observable
final class GameControllerInputManager {
    private(set) var isControllerConnected = false
    private(set) var controllerName = "No controller connected"

    var onJoystickInput: ((DroneJoystickInput) -> Void)?

    private var activeController: GCController?
    private var observers: [NSObjectProtocol] = []
    private var leftThumbstick = CGPoint.zero
    private var rightThumbstick = CGPoint.zero
    private var currentInput = DroneJoystickInput.zero
    private var repeatTask: Task<Void, Never>?

    func startMonitoring() {
        guard observers.isEmpty else { return }

        let connectObserver = NotificationCenter.default.addObserver(
            forName: .GCControllerDidConnect,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let controller = notification.object as? GCController else { return }
            MainActor.assumeIsolated {
                self?.connect(controller)
            }
        }

        let disconnectObserver = NotificationCenter.default.addObserver(
            forName: .GCControllerDidDisconnect,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let controller = notification.object as? GCController else { return }
            MainActor.assumeIsolated {
                self?.disconnect(controller)
            }
        }

        observers = [connectObserver, disconnectObserver]
        GCController.controllers().first(where: { $0.extendedGamepad != nil }).map(connect)
        GCController.startWirelessControllerDiscovery(completionHandler: nil)
    }

    func stopMonitoring() {
        sendStopCommand()
        repeatTask?.cancel()
        repeatTask = nil
        activeController?.extendedGamepad?.valueChangedHandler = nil
        activeController = nil
        isControllerConnected = false
        controllerName = "No controller connected"
        GCController.stopWirelessControllerDiscovery()

        observers.forEach(NotificationCenter.default.removeObserver)
        observers.removeAll()
    }

    private func connect(_ controller: GCController) {
        guard let gamepad = controller.extendedGamepad else { return }

        activeController?.extendedGamepad?.valueChangedHandler = nil
        activeController = controller
        isControllerConnected = true
        controllerName = controller.vendorName ?? controller.productCategory
        leftThumbstick = .zero
        rightThumbstick = .zero
        currentInput = .zero

        gamepad.valueChangedHandler = { [weak self] gamepad, _ in
            Task { @MainActor in
                self?.updateInput(from: gamepad)
            }
        }

        updateInput(from: gamepad)
    }

    private func disconnect(_ controller: GCController) {
        guard controller == activeController else { return }

        sendStopCommand()
        activeController?.extendedGamepad?.valueChangedHandler = nil
        activeController = nil
        isControllerConnected = false
        controllerName = "No controller connected"
        leftThumbstick = .zero
        rightThumbstick = .zero
        currentInput = .zero
        repeatTask?.cancel()
        repeatTask = nil

        GCController.controllers().first(where: { $0.extendedGamepad != nil }).map(connect)
    }

    private func updateInput(from gamepad: GCExtendedGamepad) {
        leftThumbstick = CGPoint(
            x: deadzoned(Double(gamepad.leftThumbstick.xAxis.value)),
            y: deadzoned(Double(gamepad.leftThumbstick.yAxis.value))
        )
        rightThumbstick = CGPoint(
            x: deadzoned(Double(gamepad.rightThumbstick.xAxis.value)),
            y: deadzoned(Double(gamepad.rightThumbstick.yAxis.value))
        )

        let input = DroneJoystickInput(
            leftRight: rightThumbstick.x,
            forwardBack: rightThumbstick.y,
            upDown: leftThumbstick.y,
            yaw: leftThumbstick.x
        )

        currentInput = input
        onJoystickInput?(input)

        if input == .zero {
            repeatTask?.cancel()
            repeatTask = nil
        } else if repeatTask == nil {
            repeatTask = Task { [weak self] in
                while !Task.isCancelled {
                    try? await Task.sleep(for: .milliseconds(100))
                    await MainActor.run {
                        guard let self, self.currentInput != .zero else { return }
                        self.onJoystickInput?(self.currentInput)
                    }
                }
            }
        }
    }

    private func sendStopCommand() {
        currentInput = .zero
        onJoystickInput?(.zero)
    }

    private func deadzoned(_ value: Double) -> Double {
        abs(value) < 0.12 ? 0 : value
    }
}
