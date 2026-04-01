import Foundation

@MainActor
final class EventDetailViewModel: ObservableObject {
    @Published var event: EventItem?
    @Published var people: [NotionPerson] = []
    @Published var typeOptions: [String] = ["Photoshoot", "Event", "Meeting"]
    @Published var isEventPeopleField = false
    @Published var titleDraft = ""
    @Published var dateDraft = ""
    @Published var typeDraft = ""
    @Published var eventDraft = ""
    @Published var placeDraft = ""
    @Published var tagsDraft = ""
    @Published var assigneeIds = Set<String>()
    @Published var noteDraft = ""
    @Published var errorText: String?
    @Published var isSaving = false

    private static var cachedMeta: EventMetaResponse?

    func load(eventId: String) async {
        // Show cached meta immediately while network loads
        if let meta = Self.cachedMeta {
            applyMeta(meta)
        }

        do {
            async let detailReq = APIClient.shared.getEvent(id: eventId)
            async let metaReq = APIClient.shared.getEventMeta()
            let (detail, meta) = try await (detailReq, metaReq)

            Self.cachedMeta = meta
            applyMeta(meta)
            applyEvent(detail.event)
            errorText = nil
        } catch {
            errorText = "Could not load event details."
        }
    }

    private func applyMeta(_ meta: EventMetaResponse) {
        people = meta.people.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        typeOptions = Array(Set(typeOptions + meta.type_options)).sorted()
        isEventPeopleField = (meta.event_property_type == "people")
    }

    private func applyEvent(_ item: EventItem) {
        event = item
        titleDraft = item.title
        dateDraft = item.date ?? ""
        typeDraft = item.type ?? ""
        eventDraft = item.event ?? ""
        placeDraft = item.place ?? ""
        tagsDraft = (item.tags ?? []).joined(separator: ", ")
        assigneeIds = Set((item.assignees ?? []).map(\.id))
        noteDraft = item.note ?? ""
    }

    func saveEvent(eventId: String) async {
        isSaving = true
        defer { isSaving = false }

        do {
            let tags = tagsDraft
                .split(separator: ",")
                .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }

            let payload = try await APIClient.shared.updateEvent(
                id: eventId,
                payload: EventUpdatePayload(
                    title: titleDraft,
                    date: dateDraft,
                    type: typeDraft,
                    event: eventDraft,
                    place: placeDraft,
                    tags: tags,
                    assignees: Array(assigneeIds),
                    note: noteDraft
                )
            )
            applyEvent(payload.event)
            errorText = nil
        } catch {
            errorText = "Could not save event."
        }
    }

    func toggleAssignee(_ personId: String) {
        if assigneeIds.contains(personId) {
            assigneeIds.remove(personId)
        } else {
            assigneeIds.insert(personId)
        }
    }

    func setType(_ type: String) {
        typeDraft = type
    }
}
