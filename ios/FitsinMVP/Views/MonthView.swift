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
                    VStack(spacing: 14) {
                        if let data = vm.data {
                            monthStatusCard(data: data)
                            targetsCard(data: data)
                            completedDaysCard(data: data)
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
                withAnimation(.easeOut(duration: 0.35)) {
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

    private func monthStatusCard(data: MonthMetrics) -> some View {
        let paceTone = data.ahead_behind >= 0 ? BrandTheme.success : BrandTheme.danger
        let paceText = data.ahead_behind >= 0 ? "Ahead of pace" : "Behind pace"
        let achieved = min(max(data.mtd_actual / max(data.mtd_target, 1), 0), 1)

        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("PRIMARY STATUS")
                        .font(.caption.weight(.semibold))
                        .tracking(1)
                        .foregroundStyle(BrandTheme.inkSoft)
                    Text(gbp.string(from: NSNumber(value: data.mtd_actual)) ?? "£0")
                        .font(.system(size: 42, weight: .black, design: .rounded))
                        .foregroundStyle(BrandTheme.ink)
                    Text("Month-to-date actual")
                        .font(.subheadline)
                        .foregroundStyle(BrandTheme.inkSoft)
                }
                Spacer()
                StatusPill(text: paceText.uppercased(), tone: paceTone)
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Progress vs MTD target")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(BrandTheme.inkSoft)
                    Spacer()
                    Text("\(Int(achieved * 100))%")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(BrandTheme.inkSoft)
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(BrandTheme.ink.opacity(0.08))
                            .frame(height: 11)
                        Capsule()
                            .fill(paceTone)
                            .frame(width: max(8, geo.size.width * achieved), height: 11)
                    }
                }
                .frame(height: 11)
            }

            HStack {
                Text("Gap to target")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(BrandTheme.inkSoft)
                Spacer()
                Text(gbp.string(from: NSNumber(value: abs(data.ahead_behind))) ?? "£0")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(paceTone)
            }

            Text("Updated \(formatTimestamp(data.updated_at))")
                .font(.caption)
                .foregroundStyle(BrandTheme.inkSoft)
        }
        .vintageCard()
    }

    private func targetsCard(data: MonthMetrics) -> some View {
        let projection = totalMonthProjection(from: data)

        return VStack(alignment: .leading, spacing: 10) {
            Text("Targets & Forecast")
                .sectionHeaderStyle()

            LazyVGrid(columns: gridColumns, spacing: 10) {
                StatTile(
                    title: "MTD Target",
                    value: gbp.string(from: NSNumber(value: data.mtd_target)) ?? "£0",
                    tone: BrandTheme.ink
                )
                StatTile(
                    title: "Month Projection",
                    value: gbp.string(from: NSNumber(value: projection)) ?? "£0",
                    tone: BrandTheme.accent
                )
                StatTile(
                    title: "Month Goal",
                    value: gbp.string(from: NSNumber(value: vm.monthGoal ?? 0)) ?? "Not set",
                    tone: vm.monthGoal == nil ? BrandTheme.inkSoft : BrandTheme.success
                )
                StatTile(
                    title: "Days Logged",
                    value: "\(filteredDays(from: data).count)",
                    tone: BrandTheme.ink
                )
            }

            HStack(spacing: 8) {
                Button {
                    if let goal = vm.monthGoal {
                        goalInput = String(format: "%.2f", goal)
                    } else {
                        goalInput = ""
                    }
                    showingGoalSheet = true
                } label: {
                    Label("Edit Goal", systemImage: "slider.horizontal.3")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 11)
                                .fill(BrandTheme.ink.opacity(0.08))
                        )
                }
                .buttonStyle(.plain)
                .foregroundStyle(BrandTheme.ink)

                Button {
                    showingProjectionCalendar = true
                } label: {
                    Label("Calendar", systemImage: "calendar")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 11)
                                .fill(BrandTheme.accent.opacity(0.14))
                        )
                }
                .buttonStyle(.plain)
                .foregroundStyle(BrandTheme.accent)
            }
        }
        .vintageCard()
    }

    private func completedDaysCard(data: MonthMetrics) -> some View {
        let days = Array(filteredDays(from: data).reversed())

        return VStack(alignment: .leading, spacing: 10) {
            Text("Completed Days")
                .sectionHeaderStyle()

            if days.isEmpty {
                Text("No completed days yet for this month.")
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
                    ForEach(Array(days.enumerated()), id: \.element.id) { index, day in
                        let sunday = isSunday(day.date)

                        NavigationLink {
                            DaySalesView(date: day.date)
                        } label: {
                            HStack(spacing: 10) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(displayDate(day.date))
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(BrandTheme.ink)
                                    Text(sunday ? "Store closed" : "Tap for item breakdown")
                                        .font(.caption)
                                        .foregroundStyle(sunday ? BrandTheme.danger : BrandTheme.inkSoft)
                                }

                                Spacer()

                                if sunday {
                                    StatusPill(text: "Closed", tone: BrandTheme.danger)
                                } else {
                                    VStack(alignment: .trailing, spacing: 2) {
                                        Text(gbp.string(from: NSNumber(value: day.actual)) ?? "£0")
                                            .font(.subheadline.weight(.bold))
                                            .foregroundStyle(BrandTheme.ink)
                                        Text("Target \(gbp.string(from: NSNumber(value: day.target)) ?? "£0")")
                                            .font(.caption)
                                            .foregroundStyle(BrandTheme.inkSoft)
                                    }
                                }

                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(BrandTheme.inkSoft)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(sunday ? BrandTheme.danger.opacity(0.08) : BrandTheme.surface)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(BrandTheme.outline, lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                        .opacity(animateIn ? 1 : 0)
                        .offset(y: animateIn ? 0 : 8)
                        .animation(.easeOut(duration: 0.28).delay(Double(index) * 0.02), value: animateIn)
                    }
                }
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
                        Text("Remaining daily targets rebalance to hit this number.")
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
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Projection Calendar")
                                    .font(.headline.weight(.semibold))
                                    .foregroundStyle(BrandTheme.ink)
                                Text("Forecast from today until month end.")
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
                                        .fill(sunday ? BrandTheme.danger.opacity(0.08) : BrandTheme.surface)
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
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Europe/London") ?? .current
        let today = cal.startOfDay(for: Date())

        return data.days.filter { day in
            guard let date = dayParser.date(from: day.date) else { return false }
            return cal.startOfDay(for: date) <= today
        }
    }

    private func remainingDays(from data: MonthMetrics) -> [MonthDay] {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Europe/London") ?? .current
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

    private func formatTimestamp(_ raw: String) -> String {
        let parser = ISO8601DateFormatter()
        parser.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let fallback = ISO8601DateFormatter()

        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM, HH:mm"
        formatter.locale = Locale(identifier: "en_GB")
        formatter.timeZone = TimeZone(identifier: "Europe/London")

        if let date = parser.date(from: raw) ?? fallback.date(from: raw) {
            return formatter.string(from: date)
        }
        return "-"
    }
}
