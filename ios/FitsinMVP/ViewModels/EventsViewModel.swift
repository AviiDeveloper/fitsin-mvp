import Foundation

@MainActor
final class EventsViewModel: ObservableObject {
    @Published var displayedMonth: Date = Date()
    @Published var events: [CalendarEvent] = []
    @Published var selectedDate: Date?
    @Published var isLoading = false
    @Published var errorText: String?

    private var londonCalendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Europe/London") ?? .current
        cal.firstWeekday = 2 // Monday
        return cal
    }

    private static let monthKeyFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM"
        f.timeZone = TimeZone(identifier: "Europe/London")
        return f
    }()

    private static let monthDisplayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMMM yyyy"
        f.timeZone = TimeZone(identifier: "Europe/London")
        f.locale = Locale(identifier: "en_GB")
        return f
    }()

    var monthTitle: String {
        Self.monthDisplayFormatter.string(from: displayedMonth)
    }

    var eventsForSelectedDay: [CalendarEvent] {
        guard let selected = selectedDate else { return [] }
        let cal = londonCalendar
        return events.filter { event in
            guard let start = event.startDate else { return false }
            return cal.isDate(start, inSameDayAs: selected)
        }
    }

    var datesWithEvents: Set<DateComponents> {
        let cal = londonCalendar
        var set = Set<DateComponents>()
        for event in events {
            guard let start = event.startDate else { continue }
            set.insert(cal.dateComponents([.year, .month, .day], from: start))
        }
        return set
    }

    var daysInMonth: [Date?] {
        let cal = londonCalendar
        let monthStart = cal.date(from: cal.dateComponents([.year, .month], from: displayedMonth))!
        let range = cal.range(of: .day, in: .month, for: monthStart)!

        let firstWeekday = cal.component(.weekday, from: monthStart)
        // Adjust for Monday start (weekday 2)
        let offset = (firstWeekday - cal.firstWeekday + 7) % 7

        var days: [Date?] = Array(repeating: nil, count: offset)

        for day in range {
            if let date = cal.date(bySetting: .day, value: day, of: monthStart) {
                days.append(date)
            }
        }

        // Pad to fill remaining grid (6 rows x 7 cols = 42)
        while days.count < 42 {
            days.append(nil)
        }

        return days
    }

    func load() async {
        let cal = londonCalendar
        let monthStart = cal.date(from: cal.dateComponents([.year, .month], from: displayedMonth))!
        let monthEnd = cal.date(byAdding: .month, value: 1, to: monthStart)!

        isLoading = true
        defer { isLoading = false }

        do {
            let fetched = try await CalendarService.shared.listEvents(from: monthStart, to: monthEnd)
            events = fetched
            errorText = nil

            let key = "calendar-events-\(Self.monthKeyFormatter.string(from: displayedMonth)).json"
            LocalCache.write(fetched, key: key)
        } catch is CalendarAuthError {
            errorText = nil // Not signed in — show CTA instead
        } catch {
            if events.isEmpty {
                loadCached()
            }
            errorText = events.isEmpty ? "Could not load calendar." : "Showing cached events."
        }
    }

    func loadCached() {
        guard events.isEmpty else { return }
        let key = "calendar-events-\(Self.monthKeyFormatter.string(from: displayedMonth)).json"
        if let cached: [CalendarEvent] = LocalCache.read([CalendarEvent].self, key: key) {
            events = cached
        }
    }

    func selectDay(_ date: Date) {
        selectedDate = date
    }

    func goToPreviousMonth() {
        displayedMonth = londonCalendar.date(byAdding: .month, value: -1, to: displayedMonth) ?? displayedMonth
        selectedDate = nil
        Task { await load() }
    }

    func goToNextMonth() {
        displayedMonth = londonCalendar.date(byAdding: .month, value: 1, to: displayedMonth) ?? displayedMonth
        selectedDate = nil
        Task { await load() }
    }

    func goToToday() {
        displayedMonth = Date()
        selectedDate = Date()
        Task { await load() }
    }

    func isToday(_ date: Date) -> Bool {
        londonCalendar.isDateInToday(date)
    }

    func isSelected(_ date: Date) -> Bool {
        guard let selected = selectedDate else { return false }
        return londonCalendar.isDate(date, inSameDayAs: selected)
    }

    func hasEvents(_ date: Date) -> Bool {
        let comps = londonCalendar.dateComponents([.year, .month, .day], from: date)
        return datesWithEvents.contains(comps)
    }
}
