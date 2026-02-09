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

    var body: some View {
        NavigationStack {
            ZStack {
                DashboardBackground()

                ScrollView {
                    VStack(spacing: 14) {

                        if let data = vm.data {
                            if isSundayToday {
                                closedCard
                                    .transition(.opacity.combined(with: .scale))
                            } else {
                                headlineCard(data: data)
                                    .transition(.opacity.combined(with: .move(edge: .top)))
                                metricCard(title: "Actual Today", value: data.actual_today)
                                metricCard(title: "Target Today", value: data.target_today)
                                metricCard(title: "Remaining", value: data.remaining)
                            }

                            if !vm.weekAhead.isEmpty {
                                weekAheadStrip
                                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                            }

                            manualEntryCard
                        }

                        if let error = vm.errorText {
                            Text(error)
                                .font(.footnote)
                                .foregroundStyle(BrandTheme.inkSoft)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .vintageCard()
                        }

                        if let manualStatus = vm.manualEntryStatus {
                            Text(manualStatus)
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
                withAnimation(.spring(duration: 0.45, bounce: 0.25)) {
                    animateIn = true
                }
                vm.startAutoRefresh(intervalSeconds: 15)
            }
            .onDisappear { vm.stopAutoRefresh() }
            .navigationTitle("Today")
            .toolbarColorScheme(.light, for: .navigationBar)
        }
    }

    private func headlineCard(data: TodayMetrics) -> some View {
        let progress = min(max(data.pct / 100.0, 0), 1)
        return VStack(alignment: .leading, spacing: 10) {
            Text("Daily Performance")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(BrandTheme.inkSoft)

            Text(gbp.string(from: NSNumber(value: data.actual_today)) ?? "£0")
                .font(.system(size: 40, weight: .bold, design: .rounded))
                .foregroundStyle(BrandTheme.ink)

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(BrandTheme.ink.opacity(0.08))
                    .frame(height: 14)
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [BrandTheme.accent, BrandTheme.accent.opacity(0.65)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: max(6, animatedProgress * 280), height: 14)
            }

            HStack {
                Text("\(Int(data.pct))% of target")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(data.pct >= 100 ? BrandTheme.success : BrandTheme.inkSoft)
                Spacer()
                Text(data.pct >= 100 ? "On pace" : "Needs push")
                    .font(.caption.weight(.bold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        Capsule()
                            .fill((data.pct >= 100 ? BrandTheme.success : BrandTheme.accent).opacity(0.16))
                    )
                    .foregroundStyle(data.pct >= 100 ? BrandTheme.success : BrandTheme.accent)
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
        .onAppear {
            animatedProgress = 0
            withAnimation(.easeOut(duration: 0.75)) {
                animatedProgress = progress
            }
        }
        .onChange(of: data.pct) { _, newValue in
            withAnimation(.easeOut(duration: 0.5)) {
                animatedProgress = min(max(newValue / 100.0, 0), 1)
            }
        }
    }

    private func metricCard(title: String, value: Double) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(BrandTheme.inkSoft)
            Text(gbp.string(from: NSNumber(value: value)) ?? "£0")
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(BrandTheme.ink)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .vintageCard()
    }

    private var weekAheadStrip: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Week Ahead")
                .font(.headline.weight(.semibold))
                .foregroundStyle(BrandTheme.ink)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(Array(vm.weekAhead.enumerated()), id: \.element.id) { index, day in
                        let isSunday = londonCalendar.component(.weekday, from: day.date) == 1
                        VStack(alignment: .leading, spacing: 4) {
                            Text(dayLabel.string(from: day.date))
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(BrandTheme.inkSoft)
                            if isSunday {
                                Text("Closed")
                                    .font(.subheadline.weight(.bold))
                                    .foregroundStyle(BrandTheme.danger)
                            } else {
                                Text("T: \(gbp.string(from: NSNumber(value: day.target)) ?? "£0")")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(BrandTheme.ink)
                                Text("A: \(gbp.string(from: NSNumber(value: day.actual)) ?? "£0")")
                                    .font(.caption)
                                    .foregroundStyle(BrandTheme.inkSoft)
                            }
                        }
                        .frame(width: 120, alignment: .leading)
                        .vintageCard()
                        .scaleEffect(animateIn ? 1 : 0.95)
                        .opacity(animateIn ? 1 : 0)
                        .animation(.spring(duration: 0.45).delay(Double(index) * 0.05), value: animateIn)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var closedCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Today")
                .font(.headline)
                .foregroundStyle(BrandTheme.inkSoft)
            Text("Closed")
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(BrandTheme.danger)
            Text("Store is closed on Sundays.")
                .font(.subheadline)
                .foregroundStyle(BrandTheme.inkSoft)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .vintageCard()
    }

    private var manualEntryCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Add Manual Sale")
                .font(.headline.weight(.semibold))
                .foregroundStyle(BrandTheme.ink)

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

            TextField("Amount (GBP)", text: $manualAmount)
                .keyboardType(.decimalPad)
                .textInputAutocapitalization(.never)
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(BrandTheme.surfaceStrong)
                )

            if selectedSource == .other {
                TextField("Brief description", text: $manualDescription)
                    .textInputAutocapitalization(.sentences)
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(BrandTheme.surfaceStrong)
                    )
            }

            TextField("Note (optional)", text: $manualNote)
                .textInputAutocapitalization(.sentences)
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(BrandTheme.surfaceStrong)
                )

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
                        ProgressView()
                            .tint(.white)
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
}
