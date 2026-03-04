import SwiftUI

struct MonthHistoryView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @StateObject private var vm = MonthHistoryViewModel()
    @State private var selectedMode: HistoryMode = .months

    private enum HistoryMode: String, CaseIterable, Identifiable {
        case months = "Months"
        case year = "Year"

        var id: String { rawValue }
    }

    private var gbp: NumberFormatter {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = "GBP"
        f.locale = Locale(identifier: "en_GB")
        return f
    }

    private struct YearTotals {
        let actual: Double
        let target: Double
        let goal: Double
        let gap: Double
    }

    private struct QuarterSummary: Identifiable {
        let id: Int
        let title: String
        let actual: Double
        let target: Double
        let gap: Double
    }

    var body: some View {
        ZStack {
            DashboardBackground()

            ScrollView {
                VStack(spacing: 14) {
                    headerControls

                    if selectedMode == .months {
                        monthsList
                    } else {
                        yearGrid
                    }

                    if let errorText = vm.errorText {
                        InlineNotice(text: errorText, tone: BrandTheme.danger, systemImage: "wifi.exclamationmark")
                            .vintageCard()
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .refreshable {
                if selectedMode == .months {
                    await vm.loadPastMonths()
                } else {
                    await vm.loadYear(vm.selectedYear, forceRefresh: true)
                }
            }
        }
        .navigationTitle("History")
        .task { await vm.loadInitial() }
    }

    private var headerControls: some View {
        VStack(alignment: .leading, spacing: 10) {
            Picker("Mode", selection: $selectedMode) {
                ForEach(HistoryMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            if selectedMode == .year {
                Picker("Year", selection: $vm.selectedYear) {
                    ForEach(vm.availableYears, id: \.self) { year in
                        Text(String(year)).tag(year)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: vm.selectedYear) { _, newYear in
                    Task { await vm.loadYear(newYear, forceRefresh: false) }
                }
            }
        }
        .vintageCard()
    }

    private var monthsList: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Past 12 Months")
                .sectionHeaderStyle()

            if vm.isLoadingPastMonths && vm.pastMonths.isEmpty {
                ProgressView("Loading month history...")
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 10)
            } else if vm.pastMonths.isEmpty {
                Text("No month history available yet.")
                    .font(.subheadline)
                    .foregroundStyle(BrandTheme.inkSoft)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(BrandTheme.surface)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(BrandTheme.outline, lineWidth: 1)
                    )
            } else {
                VStack(spacing: 8) {
                    ForEach(vm.pastMonths) { month in
                        let tone = month.gap >= 0 ? BrandTheme.success : BrandTheme.danger
                        NavigationLink {
                            MonthSnapshotView(monthKey: month.monthKey)
                        } label: {
                            HStack(spacing: 10) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(monthLabel(month.monthKey))
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(BrandTheme.ink)
                                    Text("Actual \(gbp.string(from: NSNumber(value: month.actual)) ?? "£0")")
                                        .font(.caption)
                                        .foregroundStyle(BrandTheme.inkSoft)
                                }

                                Spacer()

                                VStack(alignment: .trailing, spacing: 2) {
                                    Text("Gap \(signedCurrency(month.gap))")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(tone)
                                    Text("Target \(gbp.string(from: NSNumber(value: month.target)) ?? "£0")")
                                        .font(.caption)
                                        .foregroundStyle(BrandTheme.inkSoft)
                                }

                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(BrandTheme.inkSoft)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(BrandTheme.surface)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(BrandTheme.outline, lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .vintageCard()
    }

    private var yearGrid: some View {
        let isCompact = horizontalSizeClass == .compact
        let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: isCompact ? 3 : 4)

        return VStack(alignment: .leading, spacing: 10) {
            Text("\(vm.selectedYear) Calendar")
                .sectionHeaderStyle()

            if vm.isLoadingYear && vm.yearMonths.isEmpty {
                ProgressView("Loading year summary...")
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 10)
            } else if vm.yearMonths.isEmpty {
                Text("No year data available.")
                    .font(.subheadline)
                    .foregroundStyle(BrandTheme.inkSoft)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(BrandTheme.surface)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(BrandTheme.outline, lineWidth: 1)
                    )
            } else {
                yearOverviewCard
                quarterSummaryRow

                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(vm.yearMonths) { month in
                        let performance = month.target > 0 ? month.actual / month.target : 0
                        let heatStrength = min(max(performance, 0), 1.4)
                        let fillTone: Color = performance >= 1 ? BrandTheme.success : BrandTheme.accent

                        NavigationLink {
                            MonthSnapshotView(monthKey: month.monthKey)
                        } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(shortMonth(month.monthKey))
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(BrandTheme.ink)

                                Text(gbp.string(from: NSNumber(value: month.actual)) ?? "£0")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(BrandTheme.ink)

                                Text("T \(gbp.string(from: NSNumber(value: month.target)) ?? "£0")")
                                    .font(.caption2)
                                    .foregroundStyle(BrandTheme.inkSoft)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .frame(minHeight: 76, alignment: .topLeading)
                            .padding(10)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(fillTone.opacity(0.12 + (0.20 * heatStrength)))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(performance >= 1 ? fillTone.opacity(0.65) : BrandTheme.outline, lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .vintageCard()
    }

    private var yearOverviewCard: some View {
        let totals = yearTotals
        let tone = totals.gap >= 0 ? BrandTheme.success : BrandTheme.danger
        let completion = totals.target > 0 ? (totals.actual / totals.target) : 0

        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Year to Date")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(BrandTheme.ink)
                Spacer()
                StatusPill(text: totals.gap >= 0 ? "AHEAD" : "BEHIND", tone: tone)
            }

            Text(gbp.string(from: NSNumber(value: totals.actual)) ?? "£0")
                .font(.title2.weight(.bold))
                .foregroundStyle(BrandTheme.ink)

            HStack {
                Text("Target \(gbp.string(from: NSNumber(value: totals.target)) ?? "£0")")
                    .font(.caption)
                    .foregroundStyle(BrandTheme.inkSoft)
                Spacer()
                Text("\(Int(completion * 100))%")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(BrandTheme.inkSoft)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(BrandTheme.ink.opacity(0.08))
                        .frame(height: 8)
                    Capsule()
                        .fill(tone)
                        .frame(width: max(6, geo.size.width * min(max(completion, 0), 1)), height: 8)
                }
            }
            .frame(height: 8)

            HStack {
                Text("Gap \(signedCurrency(totals.gap))")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(tone)
                Spacer()
                Text("Goal \(gbp.string(from: NSNumber(value: totals.goal)) ?? "£0")")
                    .font(.caption)
                    .foregroundStyle(BrandTheme.inkSoft)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(BrandTheme.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(BrandTheme.outline, lineWidth: 1)
        )
    }

    private var quarterSummaryRow: some View {
        let quarters = quarterSummaries

        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(quarters) { quarter in
                    let tone = quarter.gap >= 0 ? BrandTheme.success : BrandTheme.danger

                    VStack(alignment: .leading, spacing: 4) {
                        Text(quarter.title)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(BrandTheme.inkSoft)
                        Text(gbp.string(from: NSNumber(value: quarter.actual)) ?? "£0")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(BrandTheme.ink)
                        Text(signedCurrency(quarter.gap))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(tone)
                    }
                    .frame(width: 104, alignment: .leading)
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(BrandTheme.surface)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(BrandTheme.outline, lineWidth: 1)
                    )
                }
            }
            .padding(.vertical, 2)
        }
    }

    private var yearTotals: YearTotals {
        let actual = vm.yearMonths.reduce(0) { $0 + $1.actual }
        let target = vm.yearMonths.reduce(0) { $0 + $1.target }
        let goal = vm.yearMonths.compactMap(\.goal).reduce(0, +)
        return YearTotals(actual: actual, target: target, goal: goal, gap: actual - target)
    }

    private var quarterSummaries: [QuarterSummary] {
        let groups = Dictionary(grouping: vm.yearMonths) { month in
            monthQuarter(month.monthKey)
        }

        return (1...4).compactMap { quarter in
            guard let months = groups[quarter], !months.isEmpty else { return nil }
            let actual = months.reduce(0) { $0 + $1.actual }
            let target = months.reduce(0) { $0 + $1.target }
            return QuarterSummary(
                id: quarter,
                title: "Q\(quarter)",
                actual: actual,
                target: target,
                gap: actual - target
            )
        }
    }

    private func monthQuarter(_ monthKey: String) -> Int {
        let pieces = monthKey.split(separator: "-")
        guard pieces.count == 2, let month = Int(pieces[1]) else { return 1 }
        return ((month - 1) / 3) + 1
    }

    private func monthLabel(_ monthKey: String) -> String {
        let inFmt = DateFormatter()
        inFmt.dateFormat = "yyyy-MM"
        inFmt.locale = Locale(identifier: "en_GB")
        inFmt.timeZone = TimeZone(identifier: "Europe/London")

        let outFmt = DateFormatter()
        outFmt.dateFormat = "LLLL yyyy"
        outFmt.locale = Locale(identifier: "en_GB")
        outFmt.timeZone = TimeZone(identifier: "Europe/London")

        guard let date = inFmt.date(from: monthKey) else { return monthKey }
        return outFmt.string(from: date)
    }

    private func shortMonth(_ monthKey: String) -> String {
        let inFmt = DateFormatter()
        inFmt.dateFormat = "yyyy-MM"
        inFmt.locale = Locale(identifier: "en_GB")
        inFmt.timeZone = TimeZone(identifier: "Europe/London")

        let outFmt = DateFormatter()
        outFmt.dateFormat = "MMM"
        outFmt.locale = Locale(identifier: "en_GB")
        outFmt.timeZone = TimeZone(identifier: "Europe/London")

        guard let date = inFmt.date(from: monthKey) else { return monthKey }
        return outFmt.string(from: date).uppercased()
    }

    private func signedCurrency(_ value: Double) -> String {
        let absVal = gbp.string(from: NSNumber(value: abs(value))) ?? "£0"
        return value >= 0 ? "+\(absVal)" : "-\(absVal)"
    }
}

struct MonthSnapshotView: View {
    let monthKey: String

    @StateObject private var vm = MonthSnapshotViewModel()

    private var gbp: NumberFormatter {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = "GBP"
        f.locale = Locale(identifier: "en_GB")
        return f
    }

    private var displayDay: DateFormatter {
        let f = DateFormatter()
        f.dateFormat = "EEE d MMM"
        f.timeZone = TimeZone(identifier: "Europe/London")
        f.locale = Locale(identifier: "en_GB")
        return f
    }

    private var dayParser: DateFormatter {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone(identifier: "Europe/London")
        f.locale = Locale(identifier: "en_GB")
        return f
    }

    var body: some View {
        ZStack {
            DashboardBackground()

            ScrollView {
                VStack(spacing: 14) {
                    if let data = vm.data {
                        summaryCard(data)
                        daysCard(data)
                    } else {
                        ProgressView("Loading month snapshot...")
                            .frame(maxWidth: .infinity, alignment: .center)
                            .vintageCard()
                    }

                    if let errorText = vm.errorText {
                        InlineNotice(text: errorText, tone: BrandTheme.danger, systemImage: "wifi.exclamationmark")
                            .vintageCard()
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .refreshable { await vm.load(monthKey: monthKey) }
        }
        .navigationTitle(titleForMonth(monthKey))
        .task { await vm.load(monthKey: monthKey) }
    }

    private func summaryCard(_ data: MonthMetrics) -> some View {
        let tone = data.ahead_behind >= 0 ? BrandTheme.success : BrandTheme.danger

        return VStack(alignment: .leading, spacing: 10) {
            Text("Snapshot")
                .sectionHeaderStyle()

            HStack(spacing: 8) {
                StatTile(title: "Actual", value: gbp.string(from: NSNumber(value: data.mtd_actual)) ?? "£0", tone: BrandTheme.ink)
                StatTile(title: "Target", value: gbp.string(from: NSNumber(value: data.mtd_target)) ?? "£0", tone: BrandTheme.inkSoft)
            }
            HStack(spacing: 8) {
                StatTile(title: "Gap", value: gbp.string(from: NSNumber(value: abs(data.ahead_behind))) ?? "£0", tone: tone)
                StatTile(title: "Goal", value: gbp.string(from: NSNumber(value: data.month_goal ?? 0)) ?? "Not set", tone: data.month_goal == nil ? BrandTheme.inkSoft : BrandTheme.ink)
            }
        }
        .vintageCard()
    }

    private func daysCard(_ data: MonthMetrics) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Daily Results")
                .sectionHeaderStyle()

            VStack(spacing: 8) {
                ForEach(data.days.reversed()) { day in
                    NavigationLink {
                        DaySalesView(date: day.date)
                    } label: {
                        HStack(spacing: 10) {
                            Text(displayDate(day.date))
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(BrandTheme.ink)
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text(gbp.string(from: NSNumber(value: day.actual)) ?? "£0")
                                    .font(.subheadline.weight(.bold))
                                    .foregroundStyle(BrandTheme.ink)
                                Text("Target \(gbp.string(from: NSNumber(value: day.target)) ?? "£0")")
                                    .font(.caption)
                                    .foregroundStyle(BrandTheme.inkSoft)
                            }
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(BrandTheme.inkSoft)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(BrandTheme.surface)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(BrandTheme.outline, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .vintageCard()
    }

    private func displayDate(_ raw: String) -> String {
        guard let date = dayParser.date(from: raw) else { return raw }
        return displayDay.string(from: date)
    }

    private func titleForMonth(_ key: String) -> String {
        let inFmt = DateFormatter()
        inFmt.dateFormat = "yyyy-MM"
        inFmt.locale = Locale(identifier: "en_GB")
        inFmt.timeZone = TimeZone(identifier: "Europe/London")

        let outFmt = DateFormatter()
        outFmt.dateFormat = "LLLL yyyy"
        outFmt.locale = Locale(identifier: "en_GB")
        outFmt.timeZone = TimeZone(identifier: "Europe/London")

        guard let date = inFmt.date(from: key) else { return key }
        return outFmt.string(from: date)
    }
}

@MainActor
final class MonthSnapshotViewModel: ObservableObject {
    private static let monthCachePrefix = "month-v2-"
    @Published var data: MonthMetrics?
    @Published var errorText: String?

    func load(monthKey: String) async {
        do {
            let payload = try await APIClient.shared.getMonth(month: monthKey)
            data = payload
            LocalCache.write(payload, key: "\(Self.monthCachePrefix)\(monthKey).json")
            errorText = payload.warning
        } catch {
            if let cached: MonthMetrics = LocalCache.read(MonthMetrics.self, key: "\(Self.monthCachePrefix)\(monthKey).json") {
                data = cached
                errorText = "Showing cached month data."
            } else {
                errorText = "Could not load month snapshot."
            }
        }
    }
}
