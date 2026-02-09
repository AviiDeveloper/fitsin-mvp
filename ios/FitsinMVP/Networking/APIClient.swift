import Foundation

enum APIError: Error {
    case invalidURL
    case unauthorized
    case noCode
    case missingBaseURL
    case decoding
    case server(String)
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
            "description": (description?.isEmpty == false ? description : NSNull()),
            "note": (note?.isEmpty == false ? note : NSNull())
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
}
