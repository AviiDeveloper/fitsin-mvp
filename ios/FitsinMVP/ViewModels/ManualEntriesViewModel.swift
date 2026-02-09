import Foundation

@MainActor
final class ManualEntriesViewModel: ObservableObject {
    @Published var entries: [ManualEntry] = []
    @Published var errorText: String?
    @Published var deletingIds: Set<String> = []
    private var refreshTask: Task<Void, Never>?

    private var monthStartKey: String {
        let cal = Calendar(identifier: .gregorian)
        let start = cal.date(from: cal.dateComponents([.year, .month], from: Date())) ?? Date()
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        fmt.timeZone = TimeZone(identifier: "Europe/London")
        return fmt.string(from: start)
    }

    func load() async {
        do {
            let payload = try await APIClient.shared.getManualEntries(from: monthStartKey, to: nil, limit: 500)
            entries = payload.entries
            errorText = nil
        } catch {
            errorText = "Could not load manual entries."
        }
    }

    func deleteEntry(_ entry: ManualEntry) async {
        deletingIds.insert(entry.id)
        defer { deletingIds.remove(entry.id) }

        do {
            try await APIClient.shared.deleteManualEntry(id: entry.id)
            entries.removeAll { $0.id == entry.id }
            errorText = nil
        } catch {
            errorText = "Could not delete manual entry."
        }
    }

    func startAutoRefresh(intervalSeconds: UInt64 = 15) {
        stopAutoRefresh()
        refreshTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: intervalSeconds * 1_000_000_000)
                if Task.isCancelled { break }
                await self.load()
            }
        }
    }

    func stopAutoRefresh() {
        refreshTask?.cancel()
        refreshTask = nil
    }
}
