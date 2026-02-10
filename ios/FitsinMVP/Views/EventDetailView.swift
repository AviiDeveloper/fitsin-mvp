import SwiftUI

struct EventDetailView: View {
    let eventId: String
    let fallbackEvent: EventItem

    @StateObject private var vm = EventDetailViewModel()

    private var event: EventItem {
        vm.event ?? fallbackEvent
    }

    var body: some View {
        ZStack {
            DashboardBackground()

            ScrollView {
                VStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(event.title.isEmpty ? "Untitled Event" : event.title)
                            .font(.title3.weight(.bold))
                            .foregroundStyle(BrandTheme.ink)

                        HStack(spacing: 8) {
                            Text(formattedDate(event.date))
                                .font(.subheadline)
                                .foregroundStyle(BrandTheme.inkSoft)
                            if let type = event.type, !type.isEmpty {
                                StatusPill(text: type.uppercased(), tone: BrandTheme.accent)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .vintageCard()

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Team Note")
                            .sectionHeaderStyle()
                        Text("Editable in-app and synced to Notion for all users.")
                            .font(.subheadline)
                            .foregroundStyle(BrandTheme.inkSoft)

                        TextEditor(text: $vm.noteDraft)
                            .frame(minHeight: 140)
                            .padding(8)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(BrandTheme.surfaceStrong)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(BrandTheme.outline, lineWidth: 1)
                            )

                        Button {
                            Task { await vm.saveNote(eventId: eventId) }
                        } label: {
                            HStack {
                                if vm.isSaving {
                                    ProgressView().tint(.white)
                                }
                                Text(vm.isSaving ? "Saving..." : "Save Note")
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
                        .disabled(vm.isSaving)
                    }
                    .vintageCard()

                    Link(destination: URL(string: event.url)!) {
                        HStack {
                            Image(systemName: "arrow.up.right.square")
                            Text("Open in Notion")
                                .font(.subheadline.weight(.semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(BrandTheme.accent.opacity(0.16))
                        )
                        .foregroundStyle(BrandTheme.accent)
                    }
                    .buttonStyle(.plain)
                    .vintageCard()

                    if let errorText = vm.errorText {
                        InlineNotice(text: errorText, tone: BrandTheme.danger, systemImage: "exclamationmark.triangle.fill")
                            .vintageCard()
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
        }
        .navigationTitle("Event")
        .task { await vm.load(eventId: eventId) }
        .refreshable { await vm.load(eventId: eventId) }
    }

    private func formattedDate(_ raw: String?) -> String {
        guard let raw else { return "No date" }
        let iso = ISO8601DateFormatter()
        let day = DateFormatter()
        day.dateFormat = "EEE d MMM, HH:mm"
        day.timeZone = TimeZone(identifier: "Europe/London")
        day.locale = Locale(identifier: "en_GB")

        if let parsed = iso.date(from: raw) {
            return day.string(from: parsed)
        }
        return raw
    }
}
