import Foundation

struct TelloState: Equatable, Sendable {
    var isConnected: Bool
    var batteryLevel: Int
    var altitude: Double
    var speed: Double
    var temperature: Int
    var flightTime: Int
    var rawMessage: String

    static let disconnected = TelloState(
        isConnected: false,
        batteryLevel: 0,
        altitude: 0,
        speed: 0,
        temperature: 0,
        flightTime: 0,
        rawMessage: ""
    )
}
