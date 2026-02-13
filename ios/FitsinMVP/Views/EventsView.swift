import SwiftUI

struct EventsView: View {
    @StateObject private var vm = EventsViewModel()
    @State private var animateIn = false

    var body: some View {
        NavigationStack {
            ZStack {
                DashboardBackground()

                ScrollView {
                    VStack(spacing: 14) {
                        summaryCard

                        if let first = vm.events.first {
                            nextEventCard(first)
                        }

                        timelineCard

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
            }
            .navigationTitle("Events")
            .toolbarColorScheme(.light, for: .navigationBar)
        }
    }

    private var summaryCard: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("CALENDAR")
                    .font(.caption.weight(.semibold))
                    .tracking(1)
                    .foregroundStyle(BrandTheme.inkSoft)
                Text("\(vm.events.count)")
                    .font(.system(size: 42, weight: .black, design: .rounded))
                    .foregroundStyle(BrandTheme.ink)
                Text(vm.events.count == 1 ? "Upcoming event" : "Upcoming events")
                    .font(.subheadline)
                    .foregroundStyle(BrandTheme.inkSoft)
            }

            Spacer()

            StatusPill(
                text: vm.events.isEmpty ? "No Events" : "Synced",
                tone: vm.events.isEmpty ? BrandTheme.inkSoft : BrandTheme.success
            )
        }
        .vintageCard()
    }

    private func nextEventCard(_ event: EventItem) -> some View {
        NavigationLink {
            EventDetailView(eventId: event.id, fallbackEvent: event)
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                Text("NEXT UP")
                    .font(.caption.weight(.semibold))
                    .tracking(1)
                    .foregroundStyle(BrandTheme.inkSoft)

                Text(event.title.isEmpty ? "Untitled Event" : event.title)
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .foregroundStyle(BrandTheme.ink)
                    .lineLimit(2)

                HStack(spacing: 8) {
                    Label(formattedDate(event.date), systemImage: "calendar")
                        .font(.subheadline)
                        .foregroundStyle(BrandTheme.inkSoft)

                    if let type = event.type, !type.isEmpty {
                        StatusPill(text: type.uppercased(), tone: BrandTheme.accent)
                    }
                }

                HStack {
                    Text("Open details")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(BrandTheme.accent)
                    Spacer()
                    Image(systemName: "arrow.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(BrandTheme.accent)
                }
                .padding(.top, 2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(BrandTheme.surfaceStrong)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(BrandTheme.outline, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .shadow(color: .black.opacity(0.05), radius: 12, x: 0, y: 7)
    }

    private var timelineCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Timeline")
                .sectionHeaderStyle()

            if vm.events.isEmpty {
                Text("No upcoming events yet. Add events in Notion and pull to refresh.")
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
                    ForEach(Array(vm.events.enumerated()), id: \.element.id) { index, event in
                        NavigationLink {
                            EventDetailView(eventId: event.id, fallbackEvent: event)
                        } label: {
                            HStack(alignment: .top, spacing: 10) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(dayDate(event.date))
                                        .font(.caption.weight(.bold))
                                        .tracking(0.4)
                                        .foregroundStyle(BrandTheme.inkSoft)
                                    Text(dayTime(event.date))
                                        .font(.caption)
                                        .foregroundStyle(BrandTheme.inkSoft)
                                }
                                .frame(width: 92, alignment: .leading)

                                Rectangle()
                                    .fill(BrandTheme.outline)
                                    .frame(width: 1)
                                    .padding(.vertical, 2)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(event.title.isEmpty ? "Untitled Event" : event.title)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(BrandTheme.ink)
                                        .lineLimit(2)

                                    HStack(spacing: 6) {
                                        if let type = event.type, !type.isEmpty {
                                            StatusPill(text: type.uppercased(), tone: BrandTheme.accent)
                                        }
                                        if let place = event.place, !place.isEmpty {
                                            Label(place, systemImage: "mappin.and.ellipse")
                                                .font(.caption)
                                                .foregroundStyle(BrandTheme.inkSoft)
                                                .lineLimit(1)
                                        }
                                    }
                                }

                                Spacer(minLength: 0)

                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(BrandTheme.inkSoft)
                                    .padding(.top, 3)
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
                        .opacity(animateIn ? 1 : 0)
                        .offset(y: animateIn ? 0 : 8)
                        .animation(.easeOut(duration: 0.28).delay(Double(index) * 0.02), value: animateIn)
                    }
                }
            }
        }
        .vintageCard()
    }

    private func parseDate(_ raw: String?) -> Date? {
        guard let raw, !raw.isEmpty else { return nil }

        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = iso.date(from: raw) { return date }

        iso.formatOptions = [.withInternetDateTime]
        if let date = iso.date(from: raw) { return date }

        let dateOnly = DateFormatter()
        dateOnly.dateFormat = "yyyy-MM-dd"
        dateOnly.timeZone = TimeZone(identifier: "Europe/London")
        dateOnly.locale = Locale(identifier: "en_GB")
        return dateOnly.date(from: raw)
    }

    private func formattedDate(_ raw: String?) -> String {
        guard let date = parseDate(raw) else { return "No date" }

        let out = DateFormatter()
        out.dateFormat = "EEE d MMM, HH:mm"
        out.timeZone = TimeZone(identifier: "Europe/London")
        out.locale = Locale(identifier: "en_GB")
        return out.string(from: date)
    }

    private func dayDate(_ raw: String?) -> String {
        guard let date = parseDate(raw) else { return "No date" }

        let out = DateFormatter()
        out.dateFormat = "EEE d MMM"
        out.timeZone = TimeZone(identifier: "Europe/London")
        out.locale = Locale(identifier: "en_GB")
        return out.string(from: date).uppercased()
    }

    private func dayTime(_ raw: String?) -> String {
        guard let raw, !raw.isEmpty else { return "" }
        guard raw.contains("T"), let date = parseDate(raw) else { return "All day" }

        let out = DateFormatter()
        out.dateFormat = "HH:mm"
        out.timeZone = TimeZone(identifier: "Europe/London")
        out.locale = Locale(identifier: "en_GB")
        return out.string(from: date)
    }
}
