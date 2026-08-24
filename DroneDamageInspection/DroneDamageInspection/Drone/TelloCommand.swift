import Foundation

enum TelloCommand: Equatable {
    case commandMode
    case takeOff
    case land
    case streamOn
    case streamOff
    case custom(String)

    var rawValue: String {
        switch self {
        case .commandMode:
            "command"
        case .takeOff:
            "takeoff"
        case .land:
            "land"
        case .streamOn:
            "streamon"
        case .streamOff:
            "streamoff"
        case .custom(let command):
            command
        }
    }
}
