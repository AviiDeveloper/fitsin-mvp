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
                        Text("Event Details")
                            .font(.title3.weight(.bold))
                            .foregroundStyle(BrandTheme.ink)

                        Text("Edits here sync to Notion for everyone.")
                            .font(.subheadline)
                            .foregroundStyle(BrandTheme.inkSoft)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .vintageCard()

                    VStack(spacing: 10) {
                        FormField(label: "Title", text: $vm.titleDraft, placeholder: "FASHION SHOW")
                        FormField(label: "Date", text: $vm.dateDraft, placeholder: "2026-02-21 or 2026-02-21T15:00:00+00:00")
                        FormField(label: "Event", text: $vm.eventDraft, placeholder: "Show, Drop, Pop-up")
                        FormField(label: "Place", text: $vm.placeDraft, placeholder: "Manchester")
                        FormField(label: "Tags", text: $vm.tagsDraft, placeholder: "runway, collab, press")
                    }
                    .vintageCard()

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Notes")
                            .sectionHeaderStyle()

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
                    }
                    .vintageCard()

                    Button {
                        Task { await vm.saveEvent(eventId: eventId) }
                    } label: {
                        HStack {
                            if vm.isSaving {
                                ProgressView().tint(.white)
                            }
                            Text(vm.isSaving ? "Saving..." : "Save Changes")
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
        .navigationTitle(event.title.isEmpty ? "Event" : event.title)
        .task { await vm.load(eventId: eventId) }
        .refreshable { await vm.load(eventId: eventId) }
    }
}

private struct FormField: View {
    let label: String
    @Binding var text: String
    let placeholder: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(BrandTheme.inkSoft)
            TextField(placeholder, text: $text)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(BrandTheme.surfaceStrong)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(BrandTheme.outline, lineWidth: 1)
                )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
