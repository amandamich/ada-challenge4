import Foundation

final class TelloStateService: @unchecked Sendable {
    private let listener: UDPListener
    private let parser: TelloStateParser
    private let configuration: NetworkConfiguration

    init(
        listener: UDPListener = UDPListener(),
        parser: TelloStateParser = TelloStateParser(),
        configuration: NetworkConfiguration = .tello
    ) {
        self.listener = listener
        self.parser = parser
        self.configuration = configuration
    }

    func stateStream() -> AsyncThrowingStream<TelloState, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    try await listener.start(on: configuration.statePort) { [parser] data in
                        guard let message = String(data: data, encoding: .utf8) else { return }
                        continuation.yield(parser.parse(message))
                    }
                } catch {
                    continuation.finish(throwing: error)
                }
            }

            continuation.onTermination = { [listener] _ in
                listener.stop()
            }
        }
    }

    func parseState(from message: String) -> TelloState {
        parser.parse(message)
    }

    func stop() {
        listener.stop()
    }
}
