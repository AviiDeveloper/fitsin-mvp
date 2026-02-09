import Foundation

@MainActor
final class EventsViewModel: ObservableObject {
    @Published var events: [EventItem] = []
    @Published var errorText: String?

    func load() async {
        do {
            let payload = try await APIClient.shared.getEvents()
            events = payload.events
            LocalCache.write(payload, key: "events.json")
            errorText = payload.warning
        } catch {
            if case APIError.unauthorized = error {
                errorText = "Access code is invalid. Please re-enter it."
                return
            }
            if case APIError.noCode = error {
                errorText = "No access code saved."
                return
            }
            if let cached: EventsResponse = LocalCache.read(EventsResponse.self, key: "events.json") {
                events = cached.events
                errorText = "Showing cached events."
            } else {
                errorText = "Could not load events."
            }
        }
    }
}
