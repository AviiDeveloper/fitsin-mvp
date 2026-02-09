import SwiftUI

struct MonthView: View {
    @StateObject private var vm = MonthViewModel()
    @State private var showingGoalSheet = false
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

    var body: some View {
        NavigationStack {
            ZStack {
                DashboardBackground()

                ScrollView {
                    VStack(spacing: 12) {

                        if let data = vm.data {
                            summary(data: data)

                            VStack(spacing: 10) {
                                ForEach(Array(filteredDays(from: data).reversed().enumerated()), id: \.element.id) { index, day in
                                    let sunday = isSunday(day.date)
                                    HStack(alignment: .top) {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(day.date)
                                                .font(.headline)
                                                .foregroundStyle(BrandTheme.ink)
                                            if sunday {
                                                Text("Closed")
                                                    .font(.subheadline.weight(.bold))
                                                    .foregroundStyle(BrandTheme.danger)
                                            } else {
                                                Text("Actual: \(gbp.string(from: NSNumber(value: day.actual)) ?? "£0")")
                                                    .font(.subheadline)
                                                    .foregroundStyle(BrandTheme.inkSoft)
                                                Text("Target: \(gbp.string(from: NSNumber(value: day.target)) ?? "£0")")
                                                    .font(.subheadline)
                                                    .foregroundStyle(BrandTheme.inkSoft)
                                            }
                                        }
                                        Spacer()
                                    }
                                    .vintageCard()
                                    .opacity(animateIn ? 1 : 0)
                                    .offset(y: animateIn ? 0 : 12)
                                    .animation(.spring(duration: 0.45).delay(Double(index) * 0.02), value: animateIn)
                                }
                            }
                        }

                        if let error = vm.errorText {
                            Text(error)
                                .font(.footnote)
                                .foregroundStyle(BrandTheme.inkSoft)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .vintageCard()
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .opacity(animateIn ? 1 : 0)
                    .offset(y: animateIn ? 0 : 10)
                }
                .refreshable {
                    await vm.load()
                }
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
                    Button("Set Goal") {
                        if let goal = vm.monthGoal {
                            goalInput = String(format: "%.2f", goal)
                        } else {
                            goalInput = ""
                        }
                        showingGoalSheet = true
                    }
                }
            }
            .toolbarColorScheme(.light, for: .navigationBar)
            .sheet(isPresented: $showingGoalSheet) {
                NavigationStack {
                    Form {
                        Section("Monthly Goal (GBP)") {
                            TextField("e.g. 4000", text: $goalInput)
                                .keyboardType(.decimalPad)
                        }
                    }
                    .navigationTitle("Set Month Goal")
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button("Cancel") { showingGoalSheet = false }
                        }
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Save") {
                                let parsed = Double(goalInput.replacingOccurrences(of: ",", with: "."))
                                Task {
                                    await vm.saveMonthGoal(parsed)
                                    showingGoalSheet = false
                                }
                            }
                            .disabled(vm.isSavingGoal)
                        }
                        ToolbarItem(placement: .bottomBar) {
                            Button("Clear Goal") {
                                Task {
                                    await vm.saveMonthGoal(nil)
                                    showingGoalSheet = false
                                }
                            }
                            .foregroundStyle(BrandTheme.danger)
                        }
                    }
                }
            }
        }
    }

    private func summary(data: MonthMetrics) -> some View {
        let projectedMonthTarget = totalMonthProjection(from: data)

        return VStack(alignment: .leading, spacing: 8) {
            Text("Month Overview")
                .font(.headline.weight(.semibold))
                .foregroundStyle(BrandTheme.ink)

            summaryRow("MTD Actual", data.mtd_actual)
            summaryRow("MTD Target", data.mtd_target)
            summaryRow("Full-Month Target", projectedMonthTarget)
            if let monthGoal = vm.monthGoal {
                summaryRow("Month Goal", monthGoal)
            }

            HStack {
                Text(data.ahead_behind >= 0 ? "Ahead" : "Behind")
                    .foregroundStyle(BrandTheme.inkSoft)
                Spacer()
                Text(gbp.string(from: NSNumber(value: abs(data.ahead_behind))) ?? "£0")
                    .foregroundStyle(data.ahead_behind >= 0 ? BrandTheme.success : BrandTheme.danger)
                    .fontWeight(.semibold)
            }
        }
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

    private func summaryRow(_ title: String, _ value: Double) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(BrandTheme.inkSoft)
            Spacer()
            Text(gbp.string(from: NSNumber(value: value)) ?? "£0")
                .foregroundStyle(BrandTheme.ink)
                .fontWeight(.semibold)
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
}
