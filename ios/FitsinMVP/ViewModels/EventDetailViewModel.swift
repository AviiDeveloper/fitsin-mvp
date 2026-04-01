import Foundation

@MainActor
final class EventDetailViewModel: ObservableObject {
    @Published var event: CalendarEvent?
    @Published var draft = CalendarEventDraft()
    @Published var isLoading = false
    @Published var isSaving = false
    @Published var isDeleting = false
    @Published var didDelete = false
    @Published var errorText: String?

    func load(eventId: String) async {
        isLoading = true
        defer { isLoading = false }

        do {
            let fetched = try await CalendarService.shared.getEvent(id: eventId)
            event = fetched
            populateDraft(from: fetched)
            errorText = nil
        } catch {
            errorText = "Could not load event details."
        }
    }

    func save(eventId: String) async {
        isSaving = true
        defer { isSaving = false }

        do {
            let updated = try await CalendarService.shared.updateEvent(id: eventId, draft)
            event = updated
            populateDraft(from: updated)
            errorText = nil
        } catch {
            errorText = "Could not save event."
        }
    }

    func delete(eventId: String) async {
        isDeleting = true
        defer { isDeleting = false }

        do {
            try await CalendarService.shared.deleteEvent(id: eventId)
            didDelete = true
        } catch {
            errorText = "Could not delete event."
        }
    }

    func resetDraft() {
        if let event { populateDraft(from: event) }
    }

    private func populateDraft(from event: CalendarEvent) {
        draft.title = event.title
        draft.description = event.description ?? ""
        draft.location = event.location ?? ""
        draft.isAllDay = event.isAllDay
        draft.startDate = event.startDate ?? Date()
        draft.endDate = event.endDate ?? Date().addingTimeInterval(3600)
    }
}
