import Foundation

enum TelloServiceError: Error, LocalizedError {
    case commandRejected(String)
    case invalidBatteryResponse(String)

    var errorDescription: String? {
        switch self {
        case .commandRejected(let message):
            "Tello rejected command: \(message)."
        case .invalidBatteryResponse(let message):
            "Invalid battery response: \(message)."
        }
    }
}

final class TelloService {
    private(set) var state: TelloState = .disconnected

    private let udpClient: UDPClient
    private let commandQueue: TelloCommandQueue

    var pendingCommandCount: Int {
        get async {
            await commandQueue.pendingCount
        }
    }

    init(
        udpClient: UDPClient = UDPClient(),
        commandQueue: TelloCommandQueue = TelloCommandQueue()
    ) {
        self.udpClient = udpClient
        self.commandQueue = commandQueue
    }

    func connect() async throws {
        try await executeOKCommandWithRetry(.commandMode, attempts: 2)
        state.isConnected = true
    }

    func disconnect() {
        Task {
            await commandQueue.removeAll()
        }
        udpClient.resetConnection()
        state = .disconnected
    }

    @discardableResult
    func sendCommand(_ command: TelloCommand) async throws -> TelloResponse {
        try await commandQueue.execute(command) { [udpClient] command in
            let message = try await udpClient.send(
                command.rawValue,
                timeout: command.responseTimeout
            )
            return TelloResponse(message: message)
        }
    }

    func takeOff() async throws {
        try await executeOKCommand(.takeOff)
    }

    func land() async throws {
        try await executeOKCommand(.land)
    }

    func getBattery() async throws -> Int {
        let response = try await sendCommand(.battery)
        let trimmedMessage = response.message.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let batteryLevel = Int(trimmedMessage) else {
            throw TelloServiceError.invalidBatteryResponse(response.message)
        }

        state.batteryLevel = batteryLevel
        return batteryLevel
    }

    func startVideoStream() async throws {
        try await executeOKCommand(.streamOn)
    }

    func stopVideoStream() async throws {
        try await executeOKCommand(.streamOff)
    }

    func moveForward(_ centimeters: Int) async throws {
        try await executeOKCommand(.moveForward(centimeters))
    }

    func moveBackward(_ centimeters: Int) async throws {
        try await executeOKCommand(.moveBackward(centimeters))
    }

    func moveLeft(_ centimeters: Int) async throws {
        try await executeOKCommand(.moveLeft(centimeters))
    }

    func moveRight(_ centimeters: Int) async throws {
        try await executeOKCommand(.moveRight(centimeters))
    }

    func moveUp(_ centimeters: Int) async throws {
        try await executeOKCommand(.moveUp(centimeters))
    }

    func moveDown(_ centimeters: Int) async throws {
        try await executeOKCommand(.moveDown(centimeters))
    }

    func rotateClockwise(_ degrees: Int) async throws {
        try await executeOKCommand(.rotateClockwise(degrees))
    }

    func rotateCounterClockwise(_ degrees: Int) async throws {
        try await executeOKCommand(.rotateCounterClockwise(degrees))
    }

    func sendRemoteControl(leftRight: Int, forwardBack: Int, upDown: Int, yaw: Int) async throws {
        let command = TelloCommand.remoteControl(
            leftRight: clampControlValue(leftRight),
            forwardBack: clampControlValue(forwardBack),
            upDown: clampControlValue(upDown),
            yaw: clampControlValue(yaw)
        )
        try await udpClient.sendWithoutResponse(command.rawValue)
    }

    private func executeOKCommand(_ command: TelloCommand) async throws {
        let response = try await sendCommand(command)

        guard response.isOK else {
            throw TelloServiceError.commandRejected(response.message)
        }
    }

    private func executeOKCommandWithRetry(_ command: TelloCommand, attempts: Int) async throws {
        var lastError: Error?

        for attempt in 1...attempts {
            do {
                try await executeOKCommand(command)
                return
            } catch {
                lastError = error

                if attempt < attempts {
                    try await Task.sleep(for: .milliseconds(100))
                }
            }
        }

        throw lastError ?? NetworkCommunicationError.timeout
    }

    private func clampControlValue(_ value: Int) -> Int {
        min(100, max(-100, value))
    }
}
