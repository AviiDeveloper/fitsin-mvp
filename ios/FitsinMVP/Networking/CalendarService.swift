import Foundation

enum CalendarServiceError: Error {
    case notSignedIn
    case unauthorized
    case notFound
    case rateLimited
    case server(Int, String)
    case decoding
}

final class CalendarService {
    static let shared = CalendarService()

    private let baseURL = "https://www.googleapis.com/calendar/v3"
    private let calendarId = "4c0eb4894bf742004e0801d8a164d4ceefc64cbc0fb3fb9126ac3ed94556061e@group.calendar.google.com"
    private let timeZone = "Europe/London"

    var authManager: CalendarAuthManager?

    private func authorizedRequest(path: String, method: String = "GET", query: [String: String] = [:], body: Data? = nil) async throws -> URLRequest {
        guard let auth = authManager else { throw CalendarServiceError.notSignedIn }
        let token = try await auth.validAccessToken()

        let encodedCalId = calendarId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? calendarId
        var urlString = "\(baseURL)/calendars/\(encodedCalId)\(path)"

        if !query.isEmpty {
            let queryString = query.map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? $0.value)" }.joined(separator: "&")
            urlString += "?\(queryString)"
        }

        guard let url = URL(string: urlString) else {
            throw CalendarServiceError.server(0, "Invalid URL")
        }

        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        if let body {
            req.httpBody = body
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        req.timeoutInterval = 20
        return req
    }

    private func fetch<T: Decodable>(_ type: T.Type, path: String, method: String = "GET", query: [String: String] = [:], body: Data? = nil) async throws -> T {
        let req = try await authorizedRequest(path: path, method: method, query: query, body: body)
        let (data, response) = try await URLSession.shared.data(for: req)

        guard let http = response as? HTTPURLResponse else {
            throw CalendarServiceError.server(0, "No HTTP response")
        }

        switch http.statusCode {
        case 200...299: break
        case 401, 403: throw CalendarServiceError.unauthorized
        case 404: throw CalendarServiceError.notFound
        case 429: throw CalendarServiceError.rateLimited
        default: throw CalendarServiceError.server(http.statusCode, String(data: data, encoding: .utf8) ?? "")
        }

        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw CalendarServiceError.decoding
        }
    }

    // MARK: - Public API

    func listEvents(from: Date, to: Date) async throws -> [CalendarEvent] {
        let rfc3339 = ISO8601DateFormatter()
        rfc3339.formatOptions = [.withInternetDateTime]
        let query: [String: String] = [
            "timeMin": rfc3339.string(from: from),
            "timeMax": rfc3339.string(from: to),
            "singleEvents": "true",
            "orderBy": "startTime",
            "maxResults": "250",
            "timeZone": timeZone
        ]
        let response = try await fetch(GoogleCalendarEventsResponse.self, path: "/events", query: query)
        return response.items ?? []
    }

    func getEvent(id: String) async throws -> CalendarEvent {
        let encoded = id.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? id
        return try await fetch(CalendarEvent.self, path: "/events/\(encoded)")
    }

    func createEvent(_ draft: CalendarEventDraft) async throws -> CalendarEvent {
        let body = try JSONSerialization.data(withJSONObject: draft.toRequestBody(timeZone: timeZone), options: [])
        return try await fetch(CalendarEvent.self, path: "/events", method: "POST", body: body)
    }

    func updateEvent(id: String, _ draft: CalendarEventDraft) async throws -> CalendarEvent {
        let encoded = id.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? id
        let body = try JSONSerialization.data(withJSONObject: draft.toRequestBody(timeZone: timeZone), options: [])
        return try await fetch(CalendarEvent.self, path: "/events/\(encoded)", method: "PUT", body: body)
    }

    func deleteEvent(id: String) async throws {
        let encoded = id.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? id
        let req = try await authorizedRequest(path: "/events/\(encoded)", method: "DELETE")
        let (_, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            if let http = response as? HTTPURLResponse {
                throw CalendarServiceError.server(http.statusCode, "Delete failed")
            }
            throw CalendarServiceError.server(0, "No response")
        }
    }
}
