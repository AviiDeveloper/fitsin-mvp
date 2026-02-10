import SwiftUI

struct MonthView: View {
    @StateObject private var vm = MonthViewModel()
    @State private var showingGoalSheet = false
    @State private var showingProjectionCalendar = false
    @State private var goalInput = ""
    @State private var animateIn = false

    private var gbp: NumberFormatter {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = "GBP"
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

    private var displayDay: DateFormatter {
        let f = DateFormatter()
        f.dateFormat = "EEE d MMM"
        f.timeZone = TimeZone(identifier: "Europe/London")
        f.locale = Locale(identifier: "en_GB")
        return f
    }

    private var gridColumns: [GridItem] {
        [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]
    }

    var body: some View {
        NavigationStack {
            ZStack {
                DashboardBackground()

                ScrollView {
                    VStack(spacing: 18) {
                        if let data = vm.data {
                            overviewCard(data: data)

                            DashboardSection(title: "Month Totals", subtitle: "Current progress and projection") {
                                totalsGrid(data: data)
                            }

                            DashboardSection(title: "Daily Performance", subtitle: "Most recent day first") {
                                dailyRows(data: data)
                            }
                        } else {
                            ProgressView("Loading month dashboard...")
                                .frame(maxWidth: .infinity, alignment: .center)
                                .vintageCard()
                        }

                        if let warning = vm.data?.warning, !warning.isEmpty {
                            InlineNotice(text: warning, tone: BrandTheme.danger, systemImage: "exclamationmark.triangle.fill")
                                .vintageCard()
                        }

                        if let error = vm.errorText {
                            InlineNotice(text: error, tone: BrandTheme.danger, systemImage: "wifi.exclamationmark")
                                .vintageCard()
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .opacity(animateIn ? 1 : 0)
                    .offset(y: animateIn ? 0 : 10)
                }
                .refreshable { await vm.load() }
            }
            .task {
                await vm.load()
                animateIn = false
                withAnimation(.spring(duration: 0.45, bounce: 0.2)) {
                    animateIn = true
                }
                vm.startAutoRefresh(intervalSeconds: 15)
            }
            .onDisappear { vm.stopAutoRefresh() }
            .navigationTitle("Month")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        if let goal = vm.monthGoal {
                            goalInput = String(format: "%.2f", goal)
                        } else {
                            goalInput = ""
                        }
                        showingGoalSheet = true
                    } label: {
                        Label("Set Goal", systemImage: "target")
                    }
                }
            }
            .toolbarColorScheme(.light, for: .navigationBar)
            .sheet(isPresented: $showingGoalSheet) {
                goalSheet
            }
            .sheet(isPresented: $showingProjectionCalendar) {
                projectionCalendarSheet
            }
        }
    }

    private func overviewCard(data: MonthMetrics) -> some View {
        let paceTone = data.ahead_behind >= 0 ? BrandTheme.success : BrandTheme.danger
        let paceText = data.ahead_behind >= 0 ? "Ahead" : "Behind"

        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Month Overview")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(BrandTheme.inkSoft)
                    Text(gbp.string(from: NSNumber(value: data.mtd_actual)) ?? "£0")
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .foregroundStyle(BrandTheme.ink)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 8) {
                    StatusPill(text: paceText, tone: paceTone)
                    Button {
                        showingProjectionCalendar = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "calendar")
                            Text("Plan")
                        }
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(
                            Capsule()
                                .fill(BrandTheme.accent.opacity(0.14))
                        )
                        .foregroundStyle(BrandTheme.accent)
                    }
                    .buttonStyle(.plain)
                }
            }

            HStack {
                Text("MTD vs target")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(BrandTheme.inkSoft)
                Spacer()
                Text(gbp.string(from: NSNumber(value: abs(data.ahead_behind))) ?? "£0")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(paceTone)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .vintageCard()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        colors: [BrandTheme.surfaceStrong, BrandTheme.surface],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
    }

    private func totalsGrid(data: MonthMetrics) -> some View {
        let projection = totalMonthProjection(from: data)

        return LazyVGrid(columns: gridColumns, spacing: 10) {
            StatTile(title: "MTD Actual", value: gbp.string(from: NSNumber(value: data.mtd_actual)) ?? "£0", tone: BrandTheme.ink)
            StatTile(title: "MTD Target", value: gbp.string(from: NSNumber(value: data.mtd_target)) ?? "£0", tone: BrandTheme.ink)
            StatTile(title: "Month Projection", value: gbp.string(from: NSNumber(value: projection)) ?? "£0", tone: BrandTheme.accent)
            StatTile(title: "Month Goal", value: gbp.string(from: NSNumber(value: vm.monthGoal ?? 0)) ?? "Not set", tone: vm.monthGoal == nil ? BrandTheme.inkSoft : BrandTheme.success)
        }
    }

    private func dailyRows(data: MonthMetrics) -> some View {
        VStack(spacing: 8) {
            ForEach(Array(filteredDays(from: data).reversed().enumerated()), id: \.element.id) { index, day in
                let sunday = isSunday(day.date)
                NavigationLink {
                    DaySalesView(date: day.date)
                } label: {
                    HStack(alignment: .center, spacing: 10) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(displayDate(day.date))
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(BrandTheme.ink)
                            Text(sunday ? "Closed" : "Tap to view item sales")
                                .font(.caption)
                                .foregroundStyle(sunday ? BrandTheme.danger : BrandTheme.inkSoft)
                        }

                        Spacer()

                        if sunday {
                            StatusPill(text: "Closed", tone: BrandTheme.danger)
                        } else {
                            VStack(alignment: .trailing, spacing: 2) {
                                Text("A \(gbp.string(from: NSNumber(value: day.actual)) ?? "£0")")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(BrandTheme.ink)
                                Text("T \(gbp.string(from: NSNumber(value: day.target)) ?? "£0")")
                                    .font(.caption)
                                    .foregroundStyle(BrandTheme.inkSoft)
                            }
                        }

                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(BrandTheme.inkSoft.opacity(0.75))
                            .padding(.leading, 2)
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(sunday ? BrandTheme.danger.opacity(0.08) : BrandTheme.surfaceStrong)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(BrandTheme.outline, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .opacity(animateIn ? 1 : 0)
                .offset(y: animateIn ? 0 : 10)
                .animation(.easeOut(duration: 0.35).delay(Double(index) * 0.02), value: animateIn)
            }
        }
        .vintageCard()
    }

    private var goalSheet: some View {
        NavigationStack {
            ZStack {
                DashboardBackground()
                VStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Monthly Goal")
                            .font(.title3.weight(.bold))
                            .foregroundStyle(BrandTheme.ink)
                        Text("This value is used to rebalance remaining daily targets.")
                            .font(.subheadline)
                            .foregroundStyle(BrandTheme.inkSoft)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    TextField("e.g. 4000", text: $goalInput)
                        .keyboardType(.decimalPad)
                        .textFieldStyle(FitsinInputStyle())

                    Button {
                        let parsed = Double(goalInput.replacingOccurrences(of: ",", with: "."))
                        Task {
                            await vm.saveMonthGoal(parsed)
                            showingGoalSheet = false
                        }
                    } label: {
                        HStack {
                            if vm.isSavingGoal { ProgressView().tint(.white) }
                            Text(vm.isSavingGoal ? "Saving..." : "Save Goal")
                                .font(.subheadline.weight(.semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(BrandTheme.ink)
                        )
                        .foregroundStyle(.white)
                    }
                    .disabled(vm.isSavingGoal)

                    Button("Clear Goal") {
                        Task {
                            await vm.saveMonthGoal(nil)
                            showingGoalSheet = false
                        }
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(BrandTheme.danger)
                }
                .padding(16)
                .vintageCard()
                .padding(16)
            }
            .navigationTitle("Set Goal")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { showingGoalSheet = false }
                }
            }
        }
    }

    private var projectionCalendarSheet: some View {
        NavigationStack {
            ZStack {
                DashboardBackground()

                ScrollView {
                    VStack(spacing: 12) {
                        if let data = vm.data {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Remaining Month Projections")
                                    .font(.headline.weight(.semibold))
                                    .foregroundStyle(BrandTheme.ink)
                                Text("Targets from today until the end of this month.")
                                    .font(.subheadline)
                                    .foregroundStyle(BrandTheme.inkSoft)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .vintageCard()

                            ForEach(remainingDays(from: data), id: \.id) { day in
                                let sunday = isSunday(day.date)
                                HStack {
                                    Text(displayDate(day.date))
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(BrandTheme.ink)
                                    Spacer()
                                    if sunday {
                                        StatusPill(text: "Closed", tone: BrandTheme.danger)
                                    } else {
                                        Text(gbp.string(from: NSNumber(value: day.target)) ?? "£0")
                                            .font(.subheadline.weight(.bold))
                                            .foregroundStyle(BrandTheme.accent)
                                    }
                                }
                                .padding(12)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(sunday ? BrandTheme.danger.opacity(0.08) : BrandTheme.surfaceStrong)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(BrandTheme.outline, lineWidth: 1)
                                )
                            }
                            .vintageCard()
                        } else {
                            ProgressView("Loading projections...")
                                .frame(maxWidth: .infinity, alignment: .center)
                                .vintageCard()
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
            }
            .navigationTitle("Projection Calendar")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { showingProjectionCalendar = false }
                }
            }
        }
    }

    private func filteredDays(from data: MonthMetrics) -> [MonthDay] {
        let cal = Calendar(identifier: .gregorian)
        let today = cal.startOfDay(for: Date())
        return data.days.filter { day in
            guard let date = dayParser.date(from: day.date) else { return false }
            return cal.startOfDay(for: date) <= today
        }
    }

    private func remainingDays(from data: MonthMetrics) -> [MonthDay] {
        let cal = Calendar(identifier: .gregorian)
        let today = cal.startOfDay(for: Date())
        return data.days.filter { day in
            guard let date = dayParser.date(from: day.date) else { return false }
            return cal.startOfDay(for: date) >= today
        }
    }

    private func isSunday(_ day: String) -> Bool {
        guard let date = dayParser.date(from: day) else { return false }
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Europe/London") ?? .current
        return cal.component(.weekday, from: date) == 1
    }

    private func totalMonthProjection(from data: MonthMetrics) -> Double {
        data.days
            .filter { !isSunday($0.date) }
            .reduce(0) { $0 + $1.target }
    }

    private func displayDate(_ raw: String) -> String {
        guard let date = dayParser.date(from: raw) else { return raw }
        return displayDay.string(from: date)
    }
}
