import Foundation

struct TelloStateParser: Sendable {
    func parse(_ message: String) -> TelloState {
        let values = parseKeyValuePairs(from: message)
        let speedX = doubleValue(for: "vgx", in: values)
        let speedY = doubleValue(for: "vgy", in: values)
        let speedZ = doubleValue(for: "vgz", in: values)
        let speed = sqrt((speedX * speedX) + (speedY * speedY) + (speedZ * speedZ))

        let height = doubleValue(for: "h", in: values)
        let timeOfFlight = doubleValue(for: "tof", in: values)
        let altitude = height > 0 ? height : timeOfFlight

        return TelloState(
            isConnected: true,
            batteryLevel: intValue(for: "bat", in: values),
            altitude: altitude / 100,
            speed: speed,
            temperature: averageTemperature(from: values),
            flightTime: intValue(for: "time", in: values),
            rawMessage: message
        )
    }

    private func parseKeyValuePairs(from message: String) -> [String: String] {
        Dictionary(
            uniqueKeysWithValues: message
                .split(separator: ";")
                .compactMap { pair -> (String, String)? in
                    let parts = pair.split(separator: ":", maxSplits: 1)
                    guard parts.count == 2 else { return nil }
                    return (String(parts[0]), String(parts[1]))
                }
        )
    }

    private func intValue(for key: String, in values: [String: String]) -> Int {
        Int(values[key] ?? "0") ?? 0
    }

    private func doubleValue(for key: String, in values: [String: String]) -> Double {
        Double(values[key] ?? "0") ?? 0
    }

    private func averageTemperature(from values: [String: String]) -> Int {
        let lowTemperature = intValue(for: "templ", in: values)
        let highTemperature = intValue(for: "temph", in: values)

        guard lowTemperature > 0 || highTemperature > 0 else { return 0 }
        return (lowTemperature + highTemperature) / 2
    }
}
