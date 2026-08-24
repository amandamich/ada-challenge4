import Foundation
import Observation

@MainActor
@Observable
final class DroneViewModel {
    private(set) var isConnected = false
    private(set) var batteryLevel = 0
    private(set) var altitude = 0.0

    func connect() async {
        isConnected = true
    }

    func disconnect() {
        isConnected = false
        batteryLevel = 0
        altitude = 0
    }
}
