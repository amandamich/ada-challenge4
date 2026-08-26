import Foundation

struct TelloResponse: Equatable, Sendable {
    let message: String
    let receivedAt: Date

    var isOK: Bool {
        message.lowercased() == "ok"
    }

    nonisolated init(message: String, receivedAt: Date = Date()) {
        self.message = message
        self.receivedAt = receivedAt
    }
}
