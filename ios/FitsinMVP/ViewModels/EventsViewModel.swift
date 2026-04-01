import Foundation

@MainActor
final class EventsViewModel: ObservableObject {
    @Published var events: [EventItem] = []
    @Published var errorText: String?

    func loadCached() {
        guard events.isEmpty else { return }
        if let cached: EventsResponse = LocalCache.read(EventsResponse.self, key: "events.json") {
            events = cached.events
        }
    }

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
            if events.isEmpty {
                if let cached: EventsResponse = LocalCache.read(EventsResponse.self, key: "events.json") {
                    events = cached.events
                }
            }
            errorText = events.isEmpty ? "Could not load events." : "Showing cached events."
        }
    }
}
