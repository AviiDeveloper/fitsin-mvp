import SwiftUI

struct TodayView: View {
    @StateObject private var vm = TodayViewModel()
    @State private var animateIn = false
    @State private var animatedProgress = 0.0
    @State private var selectedSource: ManualSource = .cash
    @State private var manualAmount = ""
    @State private var manualNote = ""
    @State private var manualDescription = ""

    private var gbp: NumberFormatter {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = "GBP"
        f.locale = Locale(identifier: "en_GB")
        return f
    }

    private var dayLabel: DateFormatter {
        let f = DateFormatter()
        f.dateFormat = "EEE d"
        f.timeZone = TimeZone(identifier: "Europe/London")
        f.locale = Locale(identifier: "en_GB")
        return f
    }

    private var londonCalendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Europe/London") ?? .current
        return cal
    }

    private var isSundayToday: Bool {
        londonCalendar.component(.weekday, from: Date()) == 1
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
                            heroSection(data: data)
                                .transition(.opacity.combined(with: .move(edge: .top)))

                            DashboardSection(title: "Today Breakdown", subtitle: isSundayToday ? "Store closed on Sundays" : "Live performance against target") {
                                todayGrid(data: data)
                            }

                            DashboardSection(title: "Week Ahead", subtitle: "Next 7 days target and actual") {
                                weekAheadStrip
                            }

                            DashboardSection(title: "Manual Sale Entry", subtitle: "Add Vinted, website, cash, or other sales") {
                                manualEntryCard
                            }
                        } else {
                            ProgressView("Loading today dashboard...")
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

                        if let manualStatus = vm.manualEntryStatus {
                            InlineNotice(text: manualStatus, tone: BrandTheme.success, systemImage: "checkmark.circle.fill")
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
                withAnimation(.spring(duration: 0.45, bounce: 0.22)) {
                    animateIn = true
                }
                vm.startAutoRefresh(intervalSeconds: 15)
            }
            .onDisappear { vm.stopAutoRefresh() }
            .navigationTitle("Today")
            .toolbarColorScheme(.light, for: .navigationBar)
        }
    }

    private func heroSection(data: TodayMetrics) -> some View {
        let progress = isSundayToday ? 0 : min(max(data.pct / 100.0, 0), 1)

        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("TODAY")
                        .font(.caption.weight(.semibold))
                        .tracking(1)
                        .foregroundStyle(BrandTheme.inkSoft)
                    Text(isSundayToday ? "Closed" : (gbp.string(from: NSNumber(value: data.actual_today)) ?? "£0"))
                        .font(.system(size: 44, weight: .black, design: .rounded))
                        .foregroundStyle(isSundayToday ? BrandTheme.danger : BrandTheme.ink)
                }
                Spacer()
                StatusPill(
                    text: isSundayToday ? "Sunday" : (data.pct >= 100 ? "On Pace" : "Tracking"),
                    tone: isSundayToday ? BrandTheme.danger : (data.pct >= 100 ? BrandTheme.success : BrandTheme.accent)
                )
            }

            VStack(alignment: .leading, spacing: 8) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(BrandTheme.ink.opacity(0.08))
                            .frame(height: 12)
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [BrandTheme.accent, BrandTheme.accent.opacity(0.68)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: max(8, geo.size.width * animatedProgress), height: 12)
                    }
                }
                .frame(height: 12)
                HStack {
                    Text(isSundayToday ? "Store closed today" : "\(Int(data.pct))% of daily target")
                    .font(.subheadline.weight(.semibold))
                        .foregroundStyle(BrandTheme.inkSoft)
                    Spacer()
                    if !isSundayToday {
                        Text("Updated \(formatTimestamp(data.updated_at))")
                            .font(.caption)
                            .foregroundStyle(BrandTheme.inkSoft)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .vintageCard()
        .onAppear {
            animatedProgress = 0
            withAnimation(.easeOut(duration: 0.75)) {
                animatedProgress = progress
            }
        }
        .onChange(of: data.pct) { _, newValue in
            withAnimation(.easeOut(duration: 0.5)) {
                animatedProgress = isSundayToday ? 0 : min(max(newValue / 100.0, 0), 1)
            }
        }
    }

    private func todayGrid(data: TodayMetrics) -> some View {
        LazyVGrid(columns: gridColumns, spacing: 10) {
            StatTile(
                title: "Actual",
                value: isSundayToday ? "Closed" : (gbp.string(from: NSNumber(value: data.actual_today)) ?? "£0"),
                tone: isSundayToday ? BrandTheme.danger : BrandTheme.ink
            )
            StatTile(
                title: "Target",
                value: isSundayToday ? "Closed" : (gbp.string(from: NSNumber(value: data.target_today)) ?? "£0"),
                tone: isSundayToday ? BrandTheme.danger : BrandTheme.ink
            )
            StatTile(
                title: "Remaining",
                value: isSundayToday ? "Closed" : (gbp.string(from: NSNumber(value: data.remaining)) ?? "£0"),
                tone: isSundayToday ? BrandTheme.danger : (data.remaining <= 0 ? BrandTheme.success : BrandTheme.accent)
            )
            StatTile(
                title: "Month Goal",
                value: gbp.string(from: NSNumber(value: data.month_goal ?? 0)) ?? "Not set",
                tone: data.month_goal == nil ? BrandTheme.inkSoft : BrandTheme.ink
            )
        }
    }

    private var weekAheadStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(Array(vm.weekAhead.enumerated()), id: \.element.id) { index, day in
                    let isSunday = londonCalendar.component(.weekday, from: day.date) == 1
                    VStack(alignment: .leading, spacing: 6) {
                        Text(dayLabel.string(from: day.date))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(BrandTheme.inkSoft)
                        if isSunday {
                            Text("Closed")
                                .font(.headline.weight(.bold))
                                .foregroundStyle(BrandTheme.danger)
                        } else {
                            Text(gbp.string(from: NSNumber(value: day.target)) ?? "£0")
                                .font(.headline.weight(.bold))
                                .foregroundStyle(BrandTheme.ink)
                            Text("Actual: \(gbp.string(from: NSNumber(value: day.actual)) ?? "£0")")
                                .font(.caption)
                                .foregroundStyle(BrandTheme.inkSoft)
                        }
                    }
                    .frame(width: 128, alignment: .leading)
                    .vintageCard()
                    .scaleEffect(animateIn ? 1 : 0.95)
                    .opacity(animateIn ? 1 : 0)
                    .animation(.spring(duration: 0.45).delay(Double(index) * 0.04), value: animateIn)
                }
            }
        }
    }

    private var manualEntryCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(ManualSource.allCases) { source in
                        Button(source.label) {
                            selectedSource = source
                        }
                        .font(.caption.weight(.bold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(
                            Capsule()
                                .fill(selectedSource == source ? BrandTheme.accent.opacity(0.2) : BrandTheme.ink.opacity(0.08))
                        )
                        .foregroundStyle(selectedSource == source ? BrandTheme.accent : BrandTheme.inkSoft)
                    }
                }
            }

            TextField("Amount (GBP)", text: $manualAmount)
                .keyboardType(.decimalPad)
                .textInputAutocapitalization(.never)
                .textFieldStyle(FitsinInputStyle())

            if selectedSource == .other {
                TextField("Brief description", text: $manualDescription)
                    .textInputAutocapitalization(.sentences)
                    .textFieldStyle(FitsinInputStyle())
            }

            TextField("Note (optional)", text: $manualNote)
                .textInputAutocapitalization(.sentences)
                .textFieldStyle(FitsinInputStyle())

            Button {
                guard let amount = parseAmount(manualAmount) else { return }
                let description = selectedSource == .other ? manualDescription.trimmingCharacters(in: .whitespacesAndNewlines) : nil
                Task {
                    await vm.addManualEntry(
                        amount: amount,
                        source: selectedSource,
                        description: description?.isEmpty == true ? nil : description,
                        note: manualNote.trimmingCharacters(in: .whitespacesAndNewlines)
                    )
                    manualAmount = ""
                    manualNote = ""
                    manualDescription = ""
                }
            } label: {
                HStack {
                    if vm.isSavingManualEntry {
                        ProgressView().tint(.white)
                    }
                    Text(vm.isSavingManualEntry ? "Saving..." : "Save Manual Sale")
                        .font(.subheadline.weight(.semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(canSaveManual ? BrandTheme.ink : BrandTheme.ink.opacity(0.35))
                )
                .foregroundStyle(.white)
            }
            .disabled(!canSaveManual || vm.isSavingManualEntry)
        }
        .vintageCard()
    }

    private var canSaveManual: Bool {
        guard parseAmount(manualAmount) != nil else { return false }
        if selectedSource == .other {
            return !manualDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        return true
    }

    private func parseAmount(_ raw: String) -> Double? {
        let normalized = raw.replacingOccurrences(of: ",", with: ".")
        guard let value = Double(normalized), value > 0 else { return nil }
        return value
    }

    private func formatTimestamp(_ raw: String) -> String {
        let parser = ISO8601DateFormatter()
        parser.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let fallback = ISO8601DateFormatter()
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        formatter.locale = Locale(identifier: "en_GB")
        formatter.timeZone = TimeZone(identifier: "Europe/London")

        if let date = parser.date(from: raw) ?? fallback.date(from: raw) {
            return formatter.string(from: date)
        }
        return "-"
    }
}

struct FitsinInputStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(11)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(BrandTheme.surfaceStrong)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(BrandTheme.outline, lineWidth: 1)
            )
    }
}
