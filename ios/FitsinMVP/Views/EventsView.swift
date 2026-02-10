import SwiftUI

struct EventsView: View {
    @StateObject private var vm = EventsViewModel()
    @State private var animateIn = false

    var body: some View {
        NavigationStack {
            ZStack {
                DashboardBackground()

                ScrollView {
                    VStack(spacing: 18) {
                        headerCard

                        DashboardSection(title: "Upcoming", subtitle: "Tap any event to open details") {
                            if vm.events.isEmpty {
                                emptyState
                            } else {
                                eventsList
                            }
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
            }
            .navigationTitle("Events")
            .toolbarColorScheme(.light, for: .navigationBar)
        }
    }

    private var headerCard: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Store Calendar")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(BrandTheme.inkSoft)
                Text("\(vm.events.count)")
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .foregroundStyle(BrandTheme.ink)
                Text("Upcoming items")
                    .font(.subheadline)
                    .foregroundStyle(BrandTheme.inkSoft)
            }
            Spacer()
            StatusPill(text: vm.events.isEmpty ? "No Events" : "Active", tone: vm.events.isEmpty ? BrandTheme.inkSoft : BrandTheme.success)
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

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("No upcoming events")
                .font(.headline)
                .foregroundStyle(BrandTheme.ink)
            Text("You can keep Notion disconnected for now and add it later.")
                .font(.subheadline)
                .foregroundStyle(BrandTheme.inkSoft)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .vintageCard()
    }

    private var eventsList: some View {
        VStack(spacing: 8) {
            ForEach(Array(vm.events.enumerated()), id: \.element.id) { index, event in
                NavigationLink {
                    EventDetailView(eventId: event.id, fallbackEvent: event)
                } label: {
                    HStack(alignment: .center, spacing: 10) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(formattedDate(event.date))
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(BrandTheme.inkSoft)
                            Text(event.title.isEmpty ? "Untitled Event" : event.title)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(BrandTheme.ink)
                                .lineLimit(2)
                        }

                        Spacer()

                        if let type = event.type, !type.isEmpty {
                            StatusPill(text: type.uppercased(), tone: BrandTheme.accent)
                        }

                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(BrandTheme.inkSoft)
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(BrandTheme.surfaceStrong)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(BrandTheme.outline, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .opacity(animateIn ? 1 : 0)
                .offset(y: animateIn ? 0 : 10)
                .animation(.easeOut(duration: 0.35).delay(Double(index) * 0.03), value: animateIn)
            }
        }
        .vintageCard()
    }

    private func formattedDate(_ raw: String?) -> String {
        guard let raw else { return "No date" }
        let iso = ISO8601DateFormatter()
        let day = DateFormatter()
        day.dateFormat = "EEE d MMM"
        day.timeZone = TimeZone(identifier: "Europe/London")
        day.locale = Locale(identifier: "en_GB")

        if let parsed = iso.date(from: raw) {
            return day.string(from: parsed)
        }
        return raw
    }
}
