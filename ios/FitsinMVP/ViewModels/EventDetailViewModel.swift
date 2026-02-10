import Foundation

@MainActor
final class EventDetailViewModel: ObservableObject {
    @Published var event: EventItem?
    @Published var titleDraft = ""
    @Published var dateDraft = ""
    @Published var eventDraft = ""
    @Published var placeDraft = ""
    @Published var tagsDraft = ""
    @Published var noteDraft = ""
    @Published var errorText: String?
    @Published var isSaving = false

    func load(eventId: String) async {
        do {
            let payload = try await APIClient.shared.getEvent(id: eventId)
            event = payload.event
            titleDraft = payload.event.title
            dateDraft = payload.event.date ?? ""
            eventDraft = payload.event.event ?? ""
            placeDraft = payload.event.place ?? ""
            tagsDraft = (payload.event.tags ?? []).joined(separator: ", ")
            noteDraft = payload.event.note ?? ""
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
                    event: eventDraft,
                    place: placeDraft,
                    tags: tags,
                    note: noteDraft
                )
            )
            event = payload.event
            titleDraft = payload.event.title
            dateDraft = payload.event.date ?? ""
            eventDraft = payload.event.event ?? ""
            placeDraft = payload.event.place ?? ""
            tagsDraft = (payload.event.tags ?? []).joined(separator: ", ")
            noteDraft = payload.event.note ?? ""
            errorText = nil
        } catch {
            errorText = "Could not save event."
        }
    }
}
