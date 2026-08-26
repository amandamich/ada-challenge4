import Foundation

actor TelloCommandQueue {
    private var commands: [TelloCommand] = []
    private var tailTask: Task<Void, Never>?

    var pendingCount: Int {
        commands.count
    }

    func execute(
        _ command: TelloCommand,
        operation: @Sendable @escaping (TelloCommand) async throws -> TelloResponse
    ) async throws -> TelloResponse {
        let previousTailTask = tailTask
        commands.append(command)

        let responseTask = Task<TelloResponse, Error> {
            await previousTailTask?.value
            return try await operation(command)
        }

        tailTask = Task<Void, Never> {
            _ = try? await responseTask.value
        }

        do {
            let response = try await responseTask.value
            removeCompletedCommand(command)
            clearTailIfQueueIsEmpty()
            return response
        } catch {
            removeCompletedCommand(command)
            clearTailIfQueueIsEmpty()
            throw error
        }
    }

    func removeAll() {
        commands.removeAll()
        tailTask?.cancel()
        tailTask = nil
    }

    private func removeCompletedCommand(_ command: TelloCommand) {
        guard let index = commands.firstIndex(of: command) else { return }
        commands.remove(at: index)
    }

    private func clearTailIfQueueIsEmpty() {
        if commands.isEmpty {
            tailTask = nil
        }
    }
}
