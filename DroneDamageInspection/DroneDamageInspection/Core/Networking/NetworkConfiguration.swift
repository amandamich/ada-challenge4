import Foundation
import Network

nonisolated struct NetworkConfiguration: Equatable, Sendable {
    var host: String
    var commandPort: UInt16
    var statePort: UInt16
    var videoPort: UInt16

    nonisolated init(host: String, commandPort: UInt16, statePort: UInt16, videoPort: UInt16) {
        self.host = host
        self.commandPort = commandPort
        self.statePort = statePort
        self.videoPort = videoPort
    }

    static let tello = NetworkConfiguration(
        host: "192.168.10.1",
        commandPort: 8889,
        statePort: 8890,
        videoPort: 11111
    )

    var commandHost: NWEndpoint.Host {
        NWEndpoint.Host(host)
    }

    var commandEndpointPort: NWEndpoint.Port? {
        NWEndpoint.Port(rawValue: commandPort)
    }

    func endpointPort(for port: UInt16) -> NWEndpoint.Port? {
        NWEndpoint.Port(rawValue: port)
    }
}

enum NetworkCommunicationError: Error, LocalizedError {
    case invalidPort(UInt16)
    case timeout
    case connectionFailed(String)
    case sendFailed(String)
    case receiveFailed(String)
    case invalidResponseData

    var errorDescription: String? {
        switch self {
        case .invalidPort(let port):
            "Invalid UDP port: \(port)."
        case .timeout:
            "No UDP response from Tello. Make sure the Mac is connected to TELLO Wi-Fi and the drone is powered on."
        case .connectionFailed(let message):
            if message.contains("Operation not permitted") {
                "UDP connection blocked by macOS sandbox. Enable App Sandbox > Network > Outgoing Connections in Xcode."
            } else {
                "UDP connection failed: \(message)."
            }
        case .sendFailed(let message):
            if message.contains("Operation not permitted") {
                "UDP send blocked by macOS sandbox. Enable App Sandbox > Network > Outgoing Connections in Xcode."
            } else {
                "UDP send failed: \(message)."
            }
        case .receiveFailed(let message):
            "UDP receive failed: \(message)."
        case .invalidResponseData:
            "The UDP response could not be decoded."
        }
    }
}
