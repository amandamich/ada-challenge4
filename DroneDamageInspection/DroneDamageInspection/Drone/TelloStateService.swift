import Foundation

final class TelloStateService {
    private let parser: TelloStateParser

    init(parser: TelloStateParser = TelloStateParser()) {
        self.parser = parser
    }

    func parseState(from message: String) -> TelloState {
        parser.parse(message)
    }
}
