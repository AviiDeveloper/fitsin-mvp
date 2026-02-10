import Foundation

@MainActor
final class EventDetailViewModel: ObservableObject {
    @Published var event: EventItem?
    @Published var noteDraft = ""
    @Published var errorText: String?
    @Published var isSaving = false

    func load(eventId: String) async {
        do {
            let payload = try await APIClient.shared.getEvent(id: eventId)
            event = payload.event
            noteDraft = payload.event.note ?? ""
            errorText = nil
        } catch {
            errorText = "Could not load event details."
        }
    }

    func saveNote(eventId: String) async {
        isSaving = true
        defer { isSaving = false }

        do {
            let payload = try await APIClient.shared.updateEventNote(id: eventId, note: noteDraft)
            event = payload.event
            noteDraft = payload.event.note ?? ""
            errorText = nil
        } catch {
            errorText = "Could not save note."
        }
    }
}
