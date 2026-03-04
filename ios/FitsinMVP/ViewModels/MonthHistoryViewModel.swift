import Foundation

struct HistoricalMonthSummary: Identifiable {
    let monthKey: String
    let actual: Double
    let target: Double
    let gap: Double
    let goal: Double?
    let daysCount: Int

    var id: String { monthKey }
}

@MainActor
final class MonthHistoryViewModel: ObservableObject {
    private static let monthCachePrefix = "month-v2-"
    @Published var pastMonths: [HistoricalMonthSummary] = []
    @Published var yearMonths: [HistoricalMonthSummary] = []
    @Published var selectedYear: Int
    @Published var isLoadingPastMonths = false
    @Published var isLoadingYear = false
    @Published var errorText: String?

    private let timezone = TimeZone(identifier: "Europe/London") ?? .current

    init() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timezone
        selectedYear = calendar.component(.year, from: Date())
    }

    func loadInitial() async {
        async let past: Void = loadPastMonths()
        async let year: Void = loadYear(selectedYear)
        _ = await (past, year)
    }

    func loadPastMonths(count: Int = 12) async {
        isLoadingPastMonths = true
        defer { isLoadingPastMonths = false }

        let keys = recentMonthKeys(count: count)
        var summaries = [HistoricalMonthSummary]()
        var hadFailures = false

        for key in keys {
            if let summary = await loadSummary(for: key) {
                summaries.append(summary)
            } else {
                hadFailures = true
            }
        }

        pastMonths = summaries
        if summaries.isEmpty {
            errorText = "Could not load month history."
            return
        }

        errorText = hadFailures
            ? "Some months are showing cached data."
            : nil
    }

    private func loadSummary(for key: String) async -> HistoricalMonthSummary? {
        do {
            let metrics = try await APIClient.shared.getMonth(month: key)
            LocalCache.write(metrics, key: "\(Self.monthCachePrefix)\(key).json")
            return summary(from: metrics, fallbackMonthKey: key)
        } catch {
            if let cached: MonthMetrics = LocalCache.read(MonthMetrics.self, key: "\(Self.monthCachePrefix)\(key).json") {
                return summary(from: cached, fallbackMonthKey: key)
            }
            return nil
        }
    }

    func loadYear(_ year: Int) async {
        isLoadingYear = true
        defer { isLoadingYear = false }

        let keys = monthKeys(for: year)
        var summaries = [HistoricalMonthSummary]()
        var hadFailures = false

        for key in keys {
            if let summary = await loadSummary(for: key) {
                summaries.append(summary)
            } else {
                hadFailures = true
            }
        }

        yearMonths = summaries
        if summaries.isEmpty {
            errorText = "Could not load year history."
            return
        }

        errorText = hadFailures
            ? "Some months are showing cached data."
            : nil
    }

    var availableYears: [Int] {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timezone
        let nowYear = calendar.component(.year, from: Date())
        return Array((nowYear - 4)...nowYear).reversed()
    }

    private func summary(from metrics: MonthMetrics, fallbackMonthKey: String) -> HistoricalMonthSummary {
        return HistoricalMonthSummary(
            monthKey: fallbackMonthKey,
            actual: metrics.mtd_actual,
            target: metrics.mtd_target,
            gap: metrics.ahead_behind,
            goal: metrics.month_goal,
            daysCount: metrics.days.count
        )
    }

    private func recentMonthKeys(count: Int) -> [String] {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timezone

        let now = Date()
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) ?? now

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        formatter.timeZone = timezone
        formatter.locale = Locale(identifier: "en_GB")

        return (0..<count).compactMap { offset in
            guard let date = calendar.date(byAdding: .month, value: -offset, to: startOfMonth) else { return nil }
            return formatter.string(from: date)
        }
    }

    private func monthKeys(for year: Int) -> [String] {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timezone
        let now = Date()
        let nowYear = calendar.component(.year, from: now)
        let maxMonth = year == nowYear ? calendar.component(.month, from: now) : 12

        return (1...maxMonth).map { month in
            String(format: "%04d-%02d", year, month)
        }
    }
}
