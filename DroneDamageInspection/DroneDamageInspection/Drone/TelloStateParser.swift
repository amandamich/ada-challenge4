import Foundation

struct TelloStateParser {
    func parse(_ message: String) -> TelloState {
        let values = Dictionary(
            uniqueKeysWithValues: message
                .split(separator: ";")
                .compactMap { pair -> (String, String)? in
                    let parts = pair.split(separator: ":", maxSplits: 1)
                    guard parts.count == 2 else { return nil }
                    return (String(parts[0]), String(parts[1]))
                }
        )

        return TelloState(
            isConnected: true,
            batteryLevel: Int(values["bat"] ?? "0") ?? 0,
            altitude: Double(values["h"] ?? "0") ?? 0
        )
    }
}
