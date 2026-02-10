import SwiftUI

struct EventDetailView: View {
    let eventId: String
    let fallbackEvent: EventItem

    @StateObject private var vm = EventDetailViewModel()
    @State private var isEditing = false

    private var event: EventItem {
        vm.event ?? fallbackEvent
    }

    var body: some View {
        ZStack {
            DashboardBackground()

            ScrollView {
                VStack(spacing: 14) {
                    headerCard

                    if isEditing {
                        editCard
                        notesEditorCard
                    } else {
                        infoCard
                        notesReadOnlyCard
                    }

                    notionButton

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
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(isEditing ? "Save" : "Edit") {
                    if isEditing {
                        Task {
                            await vm.saveEvent(eventId: eventId)
                            if vm.errorText == nil {
                                isEditing = false
                            }
                        }
                    } else {
                        resetDraftsFromEvent()
                        isEditing = true
                    }
                }
                .disabled(vm.isSaving)
            }

            if isEditing {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        resetDraftsFromEvent()
                        vm.errorText = nil
                        isEditing = false
                    }
                    .disabled(vm.isSaving)
                }
            }
        }
        .task { await vm.load(eventId: eventId) }
        .refreshable { await vm.load(eventId: eventId) }
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(event.title.isEmpty ? "UNTITLED" : event.title.uppercased())
                .font(.system(size: 30, weight: .black, design: .rounded))
                .foregroundStyle(BrandTheme.ink)
                .lineLimit(2)

            HStack(spacing: 8) {
                if !vm.typeDraft.isEmpty {
                    StatusPill(text: vm.typeDraft.uppercased(), tone: BrandTheme.accent)
                }
                if let firstTag = event.tags?.first, !firstTag.isEmpty {
                    StatusPill(text: firstTag.uppercased(), tone: BrandTheme.inkSoft)
                }
            }

            Text(formattedDate(event.date))
                .font(.headline)
                .foregroundStyle(BrandTheme.inkSoft)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .vintageCard()
    }

    private var infoCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Details")
                .sectionHeaderStyle()

            DetailRow(label: "Date", value: formattedDate(event.date), symbol: "calendar")
            DetailRow(label: "Type", value: event.type ?? "-", symbol: "calendar.badge.clock")
            if vm.isEventPeopleField {
                DetailRow(label: "Assigned", value: assigneesLine(event.assignees), symbol: "person.2")
            } else {
                DetailRow(label: "Event", value: event.event ?? "-", symbol: "person.2")
            }
            DetailRow(label: "Place", value: event.place ?? "-", symbol: "mappin.and.ellipse")
            DetailRow(label: "Tags", value: tagsLine(event.tags), symbol: "tag")
        }
        .vintageCard()
    }

    private var notesReadOnlyCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Notes")
                .sectionHeaderStyle()

            Text((event.note?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false) ? (event.note ?? "") : "No notes yet.")
                .font(.body)
                .foregroundStyle(BrandTheme.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
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
        .vintageCard()
    }

    private var editCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            FormField(label: "Title", text: $vm.titleDraft, placeholder: "FASHION SHOW")
            FormField(label: "Date", text: $vm.dateDraft, placeholder: "2026-02-21 or 2026-02-21T15:00:00+00:00")
            FormField(label: "Place", text: $vm.placeDraft, placeholder: "Manchester")

            VStack(alignment: .leading, spacing: 8) {
                Text("Event Type")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(BrandTheme.inkSoft)

                FlowChips(options: vm.typeOptions, selected: vm.typeDraft) { option in
                    vm.setType(option)
                }

                if vm.typeOptions.isEmpty {
                    FormField(label: "Type", text: $vm.typeDraft, placeholder: "Photoshoot")
                }
            }

            if vm.isEventPeopleField {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Assign People")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(BrandTheme.inkSoft)

                    if vm.people.isEmpty {
                        Text("No people found from Notion integration access.")
                            .font(.footnote)
                            .foregroundStyle(BrandTheme.inkSoft)
                    } else {
                        AssignPeopleGrid(people: vm.people, selectedIds: vm.assigneeIds) { personId in
                            vm.toggleAssignee(personId)
                        }
                    }
                }
            } else {
                FormField(label: "Event", text: $vm.eventDraft, placeholder: "Show, Drop, Pop-up")
            }

            FormField(label: "Tags", text: $vm.tagsDraft, placeholder: "runway, collab, press")
        }
        .vintageCard()
    }

    private var notesEditorCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Notes")
                .sectionHeaderStyle()

            TextEditor(text: $vm.noteDraft)
                .frame(minHeight: 160)
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
    }

    private var notionButton: some View {
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
    }

    private func resetDraftsFromEvent() {
        vm.titleDraft = event.title
        vm.dateDraft = event.date ?? ""
        vm.typeDraft = event.type ?? ""
        vm.eventDraft = event.event ?? ""
        vm.placeDraft = event.place ?? ""
        vm.tagsDraft = (event.tags ?? []).joined(separator: ", ")
        vm.assigneeIds = Set((event.assignees ?? []).map(\.id))
        vm.noteDraft = event.note ?? ""
    }

    private func tagsLine(_ tags: [String]?) -> String {
        let cleaned = (tags ?? []).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        return cleaned.isEmpty ? "-" : cleaned.joined(separator: "  •  ")
    }

    private func assigneesLine(_ assignees: [NotionPerson]?) -> String {
        let names = (assignees ?? []).map(\.name).filter { !$0.isEmpty }
        return names.isEmpty ? "-" : names.joined(separator: ", ")
    }

    private func formattedDate(_ raw: String?) -> String {
        guard let raw, !raw.isEmpty else { return "No date" }

        let zone = TimeZone(identifier: "Europe/London") ?? .current
        let dateOnly = DateFormatter()
        dateOnly.timeZone = zone
        dateOnly.locale = Locale(identifier: "en_GB")
        dateOnly.dateFormat = "yyyy-MM-dd"

        let displayDay = DateFormatter()
        displayDay.timeZone = zone
        displayDay.locale = Locale(identifier: "en_GB")
        displayDay.dateFormat = "EEE d MMM yyyy"

        let displayTime = DateFormatter()
        displayTime.timeZone = zone
        displayTime.locale = Locale(identifier: "en_GB")
        displayTime.dateFormat = "EEE d MMM yyyy, HH:mm"

        if raw.count == 10, let d = dateOnly.date(from: raw) {
            return displayDay.string(from: d)
        }

        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = iso.date(from: raw) {
            return displayTime.string(from: d)
        }

        iso.formatOptions = [.withInternetDateTime]
        if let d = iso.date(from: raw) {
            return displayTime.string(from: d)
        }

        return raw
    }
}

private struct DetailRow: View {
    let label: String
    let value: String
    let symbol: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: symbol)
                .font(.subheadline)
                .foregroundStyle(BrandTheme.inkSoft)
                .frame(width: 18)
            Text(label)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(BrandTheme.inkSoft)
                .frame(width: 72, alignment: .leading)
            Text(value)
                .font(.subheadline)
                .foregroundStyle(BrandTheme.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct FlowChips: View {
    let options: [String]
    let selected: String
    let onSelect: (String) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(options, id: \.self) { option in
                    let isSelected = option.caseInsensitiveCompare(selected) == .orderedSame
                    Button(option) {
                        onSelect(option)
                    }
                    .font(.footnote.weight(.semibold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(
                        Capsule()
                            .fill(isSelected ? BrandTheme.ink : BrandTheme.surfaceStrong)
                    )
                    .foregroundStyle(isSelected ? Color.white : BrandTheme.ink)
                    .overlay(
                        Capsule().stroke(BrandTheme.outline, lineWidth: isSelected ? 0 : 1)
                    )
                }
            }
            .padding(.vertical, 2)
        }
    }
}

private struct AssignPeopleGrid: View {
    let people: [NotionPerson]
    let selectedIds: Set<String>
    let onToggle: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(people) { person in
                let isSelected = selectedIds.contains(person.id)
                Button {
                    onToggle(person.id)
                } label: {
                    HStack(spacing: 10) {
                        Circle()
                            .fill(isSelected ? BrandTheme.accent : BrandTheme.surfaceStrong)
                            .frame(width: 10, height: 10)
                        Text(person.name)
                            .font(.subheadline)
                            .foregroundStyle(BrandTheme.ink)
                        Spacer(minLength: 0)
                        if isSelected {
                            Image(systemName: "checkmark")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(BrandTheme.accent)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(BrandTheme.surfaceStrong)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? BrandTheme.accent : BrandTheme.outline, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
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
