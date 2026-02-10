import Foundation

struct TodayMetrics: Codable {
    let actual_today: Double
    let target_today: Double
    let month_goal: Double?
    let remaining: Double
    let pct: Double
    let updated_at: String
    let data_delayed: Bool?
    let warning: String?
}

struct MonthDay: Codable, Identifiable {
    var id: String { date }
    let date: String
    let actual: Double
    let target: Double
}

struct MonthMetrics: Codable {
    let month_goal: Double?
    let mtd_actual: Double
    let mtd_target: Double
    let ahead_behind: Double
    let days: [MonthDay]
    let updated_at: String
    let data_delayed: Bool?
    let warning: String?
}

struct MonthGoalResponse: Codable {
    let month: String
    let goal: Double?
    let updated_at: String
}

struct EventItem: Codable, Identifiable {
    let id: String
    let title: String
    let date: String?
    let type: String?
    let url: String
}

struct EventsResponse: Codable {
    let events: [EventItem]
    let updated_at: String
    let data_delayed: Bool?
    let warning: String?
}

enum ManualSource: String, Codable, CaseIterable, Identifiable {
    case vinted
    case website
    case cash
    case other

    var id: String { rawValue }
    var label: String { rawValue.capitalized }
}

struct ManualEntry: Codable, Identifiable {
    let id: String
    let date: String
    let amount: Double
    let source: ManualSource
    let description: String?
    let note: String?
    let created_at: String
}

struct ManualEntriesResponse: Codable {
    let entries: [ManualEntry]
    let updated_at: String
}

struct DaySaleItem: Codable, Identifiable {
    let id: String
    let kind: String
    let sold_at: String
    let description: String
    let quantity: Int
    let amount: Double?
    let source: String?
    let note: String?
    let order_name: String?
}

struct DaySalesResponse: Codable {
    let date: String
    let items: [DaySaleItem]
    let updated_at: String
    let data_delayed: Bool?
    let warning: String?
}
