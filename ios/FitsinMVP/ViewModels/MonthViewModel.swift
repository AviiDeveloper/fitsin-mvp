import Foundation

@MainActor
final class MonthViewModel: ObservableObject {
    @Published var data: MonthMetrics?
    @Published var lastMonthData: MonthMetrics?
    @Published var errorText: String?
    @Published var monthGoal: Double?
    @Published var isSavingGoal = false
    private var refreshTask: Task<Void, Never>?

    private static let monthFormatter: DateFormatter = {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM"
        fmt.timeZone = TimeZone(identifier: "Europe/London")
        return fmt
    }()

    private var monthKey: String {
        Self.monthFormatter.string(from: Date())
    }

    private var lastMonthKey: String {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Europe/London") ?? .current
        let lastMonth = cal.date(byAdding: .month, value: -1, to: Date()) ?? Date()
        return Self.monthFormatter.string(from: lastMonth)
    }

    func loadCached() {
        guard data == nil else { return }
        if let cached: MonthMetrics = LocalCache.read(MonthMetrics.self, key: "month.json") {
            data = cached
            monthGoal = cached.month_goal
        }
        if lastMonthData == nil {
            if let cached: MonthMetrics = LocalCache.read(MonthMetrics.self, key: "month-last.json") {
                lastMonthData = cached
            }
        }
    }

    func load() async {
        do {
            async let monthTask = APIClient.shared.getMonth()
            async let goalTask = APIClient.shared.getMonthGoal(month: monthKey)
            async let lastTask = APIClient.shared.getMonth(month: lastMonthKey)

            let payload = try await monthTask
            let goal = try await goalTask
            data = payload
            monthGoal = goal.goal ?? payload.month_goal
            LocalCache.write(payload, key: "month.json")
            errorText = payload.warning

            // Last month loads independently — don't fail the whole load
            if let last = try? await lastTask {
                lastMonthData = last
                LocalCache.write(last, key: "month-last.json")
            }
        } catch {
            if case APIError.unauthorized = error {
                errorText = "Access code is invalid. Please re-enter it."
                return
            }
            if case APIError.noCode = error {
                errorText = "No access code saved."
                return
            }
            if data == nil {
                if let cached: MonthMetrics = LocalCache.read(MonthMetrics.self, key: "month.json") {
                    data = cached
                    monthGoal = cached.month_goal
                }
            }
            errorText = data != nil ? "Showing cached month data." : "Could not load month metrics."
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

    func startAutoRefresh(intervalSeconds: UInt64 = 60) {
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
