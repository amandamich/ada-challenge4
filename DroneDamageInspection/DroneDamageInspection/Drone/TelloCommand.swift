import Foundation

enum TelloCommand: Equatable, Sendable {
    case commandMode
    case takeOff
    case land
    case battery
    case streamOn
    case streamOff
    case moveForward(Int)
    case moveBackward(Int)
    case moveLeft(Int)
    case moveRight(Int)
    case moveUp(Int)
    case moveDown(Int)
    case rotateClockwise(Int)
    case rotateCounterClockwise(Int)
    case custom(String)

    var responseTimeout: TimeInterval {
        switch self {
        case .commandMode, .battery:
            2
        case .streamOn, .streamOff:
            2
        case .takeOff, .land:
            8
        case .moveForward, .moveBackward, .moveLeft, .moveRight, .moveUp, .moveDown, .rotateClockwise, .rotateCounterClockwise:
            5
        case .custom:
            5
        }
    }

    var rawValue: String {
        switch self {
        case .commandMode:
            "command"
        case .takeOff:
            "takeoff"
        case .land:
            "land"
        case .battery:
            "battery?"
        case .streamOn:
            "streamon"
        case .streamOff:
            "streamoff"
        case .moveForward(let centimeters):
            "forward \(centimeters)"
        case .moveBackward(let centimeters):
            "back \(centimeters)"
        case .moveLeft(let centimeters):
            "left \(centimeters)"
        case .moveRight(let centimeters):
            "right \(centimeters)"
        case .moveUp(let centimeters):
            "up \(centimeters)"
        case .moveDown(let centimeters):
            "down \(centimeters)"
        case .rotateClockwise(let degrees):
            "cw \(degrees)"
        case .rotateCounterClockwise(let degrees):
            "ccw \(degrees)"
        case .custom(let command):
            command
        }
    }
}
