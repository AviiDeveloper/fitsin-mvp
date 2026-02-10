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

    func load(eventId: String) async {
        do {
            async let detailReq = APIClient.shared.getEvent(id: eventId)
            async let metaReq = APIClient.shared.getEventMeta()
            let (detail, meta) = try await (detailReq, metaReq)

            people = meta.people.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            typeOptions = Array(Set(typeOptions + meta.type_options)).sorted()
            isEventPeopleField = (meta.event_property_type == "people")

            event = detail.event
            titleDraft = detail.event.title
            dateDraft = detail.event.date ?? ""
            typeDraft = detail.event.type ?? ""
            eventDraft = detail.event.event ?? ""
            placeDraft = detail.event.place ?? ""
            tagsDraft = (detail.event.tags ?? []).joined(separator: ", ")
            assigneeIds = Set((detail.event.assignees ?? []).map(\.id))
            noteDraft = detail.event.note ?? ""
            errorText = nil
        } catch {
            errorText = "Could not load event details."
        }
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
            event = payload.event
            titleDraft = payload.event.title
            dateDraft = payload.event.date ?? ""
            typeDraft = payload.event.type ?? ""
            eventDraft = payload.event.event ?? ""
            placeDraft = payload.event.place ?? ""
            tagsDraft = (payload.event.tags ?? []).joined(separator: ", ")
            assigneeIds = Set((payload.event.assignees ?? []).map(\.id))
            noteDraft = payload.event.note ?? ""
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
