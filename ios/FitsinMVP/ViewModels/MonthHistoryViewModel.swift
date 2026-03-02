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

        do {
            let keys = recentMonthKeys(count: count)
            var summaries = [HistoricalMonthSummary]()
            for key in keys {
                let metrics = try await APIClient.shared.getMonth(month: key)
                summaries.append(summary(from: metrics, fallbackMonthKey: key))
                LocalCache.write(metrics, key: "\(Self.monthCachePrefix)\(key).json")
            }
            pastMonths = summaries
            if errorText == "Showing cached month history." {
                errorText = nil
            }
        } catch {
            var cached = [HistoricalMonthSummary]()
            for key in recentMonthKeys(count: count) {
                if let metrics: MonthMetrics = LocalCache.read(MonthMetrics.self, key: "\(Self.monthCachePrefix)\(key).json") {
                    cached.append(summary(from: metrics, fallbackMonthKey: key))
                }
            }
            if !cached.isEmpty {
                pastMonths = cached
                errorText = "Showing cached month history."
            } else {
                errorText = "Could not load month history."
            }
        }
    }

    func loadYear(_ year: Int) async {
        isLoadingYear = true
        defer { isLoadingYear = false }

        do {
            let keys = monthKeys(for: year)
            var summaries = [HistoricalMonthSummary]()
            for key in keys {
                let metrics = try await APIClient.shared.getMonth(month: key)
                summaries.append(summary(from: metrics, fallbackMonthKey: key))
                LocalCache.write(metrics, key: "\(Self.monthCachePrefix)\(key).json")
            }
            yearMonths = summaries
            if errorText == "Showing cached year history." {
                errorText = nil
            }
        } catch {
            var cached = [HistoricalMonthSummary]()
            for key in monthKeys(for: year) {
                if let metrics: MonthMetrics = LocalCache.read(MonthMetrics.self, key: "\(Self.monthCachePrefix)\(key).json") {
                    cached.append(summary(from: metrics, fallbackMonthKey: key))
                }
            }
            if !cached.isEmpty {
                yearMonths = cached
                errorText = "Showing cached year history."
            } else {
                errorText = "Could not load year history."
            }
        }
    }

    var availableYears: [Int] {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timezone
        let nowYear = calendar.component(.year, from: Date())
        return Array((nowYear - 4)...nowYear).reversed()
    }

    private func summary(from metrics: MonthMetrics, fallbackMonthKey: String) -> HistoricalMonthSummary {
        let monthKey = metrics.month ?? fallbackMonthKey
        return HistoricalMonthSummary(
            monthKey: monthKey,
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
