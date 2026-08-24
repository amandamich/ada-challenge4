import Foundation

actor TelloCommandQueue {
    private var commands: [TelloCommand] = []

    func enqueue(_ command: TelloCommand) {
        commands.append(command)
    }

    func dequeue() -> TelloCommand? {
        guard !commands.isEmpty else { return nil }
        return commands.removeFirst()
    }

    func removeAll() {
        commands.removeAll()
    }
}
