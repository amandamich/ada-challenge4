import Foundation

final class TelloService {
    private(set) var state: TelloState = .disconnected
    private let udpClient: UDPClient

    init(udpClient: UDPClient = UDPClient()) {
        self.udpClient = udpClient
    }

    func connect() async throws {
        let response = try await sendCommand(.commandMode)

        guard response.isOK else {
            throw NetworkCommunicationError.receiveFailed(response.message)
        }

        state.isConnected = true
    }

    func disconnect() {
        state = .disconnected
    }

    @discardableResult
    func sendCommand(_ command: TelloCommand) async throws -> TelloResponse {
        let message = try await udpClient.send(command.rawValue)
        return TelloResponse(message: message)
    }
}
