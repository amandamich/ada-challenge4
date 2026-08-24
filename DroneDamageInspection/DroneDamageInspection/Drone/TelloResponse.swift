import Foundation

struct TelloResponse: Equatable {
    let message: String
    let receivedAt: Date

    var isOK: Bool {
        message.lowercased() == "ok"
    }

    init(message: String, receivedAt: Date = Date()) {
        self.message = message
        self.receivedAt = receivedAt
    }
}
