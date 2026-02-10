import Foundation

enum APIError: Error {
    case invalidURL
    case unauthorized
    case noCode
    case missingBaseURL
    case decoding
    case server(String)
}

struct EventUpdatePayload {
    let title: String
    let date: String
    let type: String
    let event: String
    let place: String
    let tags: [String]
    let assignees: [String]
    let note: String
}

final class APIClient {
    static let shared = APIClient()

    private var baseURL: URL {
        guard let raw = Bundle.main.object(forInfoDictionaryKey: "API_BASE_URL") as? String,
              let url = URL(string: raw),
              !raw.isEmpty else {
            fatalError("Missing API_BASE_URL in Info.plist")
        }
        return url
    }

    private func request(path: String, method: String = "GET", body: Data? = nil) throws -> URLRequest {
        guard let code = KeychainStore.readCode(), !code.isEmpty else {
            throw APIError.noCode
        }

        guard let url = URL(string: path, relativeTo: baseURL) else {
            throw APIError.invalidURL
        }

        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue(code, forHTTPHeaderField: "X-APP-CODE")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        if let body {
            req.httpBody = body
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        req.timeoutInterval = 20
        return req
    }

    private func fetch<T: Decodable>(_ type: T.Type, path: String, method: String = "GET", body: Data? = nil) async throws -> T {
        let req = try request(path: path, method: method, body: body)
        let (data, response) = try await URLSession.shared.data(for: req)

        guard let http = response as? HTTPURLResponse else {
            throw APIError.server("No HTTP response")
        }

        if http.statusCode == 401 { throw APIError.unauthorized }
        guard (200...299).contains(http.statusCode) else {
            throw APIError.server("HTTP \(http.statusCode)")
        }

        if data.isEmpty {
            if T.self == EmptyResponse.self {
                return EmptyResponse() as! T
            }
            throw APIError.decoding
        }

        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw APIError.decoding
        }
    }

    func getToday() async throws -> TodayMetrics {
        try await fetch(TodayMetrics.self, path: "/v1/today")
    }

    func getMonth() async throws -> MonthMetrics {
        try await fetch(MonthMetrics.self, path: "/v1/month")
    }

    func getEvents() async throws -> EventsResponse {
        try await fetch(EventsResponse.self, path: "/v1/events")
    }

    func getEvent(id: String) async throws -> EventDetailResponse {
        let encoded = id.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? id
        return try await fetch(EventDetailResponse.self, path: "/v1/events/\(encoded)")
    }

    func getEventMeta() async throws -> EventMetaResponse {
        try await fetch(EventMetaResponse.self, path: "/v1/events/meta")
    }

    func updateEvent(id: String, payload: EventUpdatePayload) async throws -> EventDetailResponse {
        let encoded = id.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? id
        let bodyPayload: [String: Any] = [
            "title": payload.title,
            "date": payload.date,
            "type": payload.type,
            "event": payload.event,
            "place": payload.place,
            "tags": payload.tags,
            "assignees": payload.assignees,
            "note": payload.note
        ]
        let body = try JSONSerialization.data(withJSONObject: bodyPayload, options: [])
        return try await fetch(EventDetailResponse.self, path: "/v1/events/\(encoded)", method: "PATCH", body: body)
    }

    func getMonthGoal(month: String) async throws -> MonthGoalResponse {
        try await fetch(MonthGoalResponse.self, path: "/v1/month-goal?month=\(month)")
    }

    func setMonthGoal(month: String, goal: Double?) async throws -> MonthGoalResponse {
        let payload: [String: Any] = [
            "month": month,
            "goal": goal ?? NSNull()
        ]
        let body = try JSONSerialization.data(withJSONObject: payload, options: [])
        return try await fetch(MonthGoalResponse.self, path: "/v1/month-goal", method: "PUT", body: body)
    }

    func createManualEntry(
        amount: Double,
        source: ManualSource,
        description: String?,
        note: String?
    ) async throws -> ManualEntry {
        let payload: [String: Any] = [
            "amount": amount,
            "source": source.rawValue,
            "description": (description?.isEmpty == false ? description as Any : NSNull()),
            "note": (note?.isEmpty == false ? note as Any : NSNull())
        ]
        let body = try JSONSerialization.data(withJSONObject: payload, options: [])
        return try await fetch(ManualEntry.self, path: "/v1/manual-entries", method: "POST", body: body)
    }

    func getManualEntries(from: String? = nil, to: String? = nil, limit: Int = 200) async throws -> ManualEntriesResponse {
        var parts = [String]()
        if let from, !from.isEmpty { parts.append("from=\(from)") }
        if let to, !to.isEmpty { parts.append("to=\(to)") }
        parts.append("limit=\(limit)")
        let query = parts.joined(separator: "&")
        return try await fetch(ManualEntriesResponse.self, path: "/v1/manual-entries?\(query)")
    }

    func deleteManualEntry(id: String) async throws {
        let encoded = id.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? id
        _ = try await fetch(EmptyResponse.self, path: "/v1/manual-entries/\(encoded)", method: "DELETE")
    }

    func getDaySales(date: String) async throws -> DaySalesResponse {
        let encoded = date.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? date
        return try await fetch(DaySalesResponse.self, path: "/v1/day?date=\(encoded)")
    }
}

private struct EmptyResponse: Decodable {}
