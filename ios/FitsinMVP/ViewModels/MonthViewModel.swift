import Foundation

@MainActor
final class MonthViewModel: ObservableObject {
    @Published var data: MonthMetrics?
    @Published var errorText: String?
    @Published var monthGoal: Double?
    @Published var isSavingGoal = false
    private var refreshTask: Task<Void, Never>?

    private var monthKey: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM"
        fmt.timeZone = TimeZone(identifier: "Europe/London")
        return fmt.string(from: Date())
    }

    func load() async {
        do {
            async let monthTask = APIClient.shared.getMonth()
            async let goalTask = APIClient.shared.getMonthGoal(month: monthKey)

            let payload = try await monthTask
            let goal = try await goalTask
            data = payload
            monthGoal = goal.goal ?? payload.month_goal
            LocalCache.write(payload, key: "month.json")
            errorText = payload.warning
        } catch {
            if case APIError.unauthorized = error {
                errorText = "Access code is invalid. Please re-enter it."
                return
            }
            if case APIError.noCode = error {
                errorText = "No access code saved."
                return
            }
            if let cached: MonthMetrics = LocalCache.read(MonthMetrics.self, key: "month.json") {
                data = cached
                monthGoal = cached.month_goal
                errorText = "Showing cached month data."
            } else {
                errorText = "Could not load month metrics."
            }
        }
    }

    func saveMonthGoal(_ goal: Double?) async {
        isSavingGoal = true
        defer { isSavingGoal = false }

        do {
            let saved = try await APIClient.shared.setMonthGoal(month: monthKey, goal: goal)
            monthGoal = saved.goal
            await load()
        } catch {
            errorText = "Could not save month goal."
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
