import Foundation
import Network

struct NetworkConfiguration: Equatable {
    var host: String
    var commandPort: UInt16
    var statePort: UInt16
    var videoPort: UInt16

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
            "The UDP request timed out."
        case .connectionFailed(let message):
            "UDP connection failed: \(message)."
        case .sendFailed(let message):
            "UDP send failed: \(message)."
        case .receiveFailed(let message):
            "UDP receive failed: \(message)."
        case .invalidResponseData:
            "The UDP response could not be decoded."
        }
    }
}
