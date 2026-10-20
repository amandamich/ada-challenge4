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
    case remoteControl(leftRight: Int, forwardBack: Int, upDown: Int, yaw: Int)
    case custom(String)

    var responseTimeout: TimeInterval {
        switch self {
        case .commandMode, .battery:
            1.5
        case .streamOn, .streamOff:
            1.5
        case .takeOff, .land:
            5
        case .moveForward, .moveBackward, .moveLeft, .moveRight, .moveUp, .moveDown, .rotateClockwise, .rotateCounterClockwise:
            3
        case .remoteControl:
            0.2
        case .custom:
            3
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
        case .remoteControl(let leftRight, let forwardBack, let upDown, let yaw):
            "rc \(leftRight) \(forwardBack) \(upDown) \(yaw)"
        case .custom(let command):
            command
        }
    }
}
