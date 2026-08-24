import Foundation

struct TelloState: Equatable {
    var isConnected: Bool
    var batteryLevel: Int
    var altitude: Double

    static let disconnected = TelloState(
        isConnected: false,
        batteryLevel: 0,
        altitude: 0
    )
}
