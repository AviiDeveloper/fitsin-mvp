import Foundation

@MainActor
final class RotaViewModel: ObservableObject {
    @Published var entries: [RotaEntry] = []
    @Published var errorText: String?

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone(identifier: "Europe/London")
        f.locale = Locale(identifier: "en_GB")
        return f
    }()

    private var londonCalendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Europe/London") ?? .current
        return cal
    }

    var dateRange: (from: String, to: String) {
        let today = londonCalendar.startOfDay(for: Date())
        let end = londonCalendar.date(byAdding: .day, value: 13, to: today) ?? today
        return (Self.dateFormatter.string(from: today), Self.dateFormatter.string(from: end))
    }

    var upcomingDays: [(date: Date, key: String)] {
        let cal = londonCalendar
        let today = cal.startOfDay(for: Date())
        return (0..<14).compactMap { offset in
            guard let date = cal.date(byAdding: .day, value: offset, to: today) else { return nil }
            let weekday = cal.component(.weekday, from: date)
            guard weekday != 1 else { return nil } // skip Sundays
            return (date, Self.dateFormatter.string(from: date))
        }
    }

    func entries(for dateKey: String) -> [RotaEntry] {
        entries.filter { $0.date == dateKey }
    }

    func isSignedUp(for dateKey: String, userName: String) -> Bool {
        entries.contains { $0.date == dateKey && $0.name.lowercased() == userName.lowercased() }
    }

    func myEntry(for dateKey: String, userName: String) -> RotaEntry? {
        entries.first { $0.date == dateKey && $0.name.lowercased() == userName.lowercased() }
    }

    func load() async {
        let range = dateRange
        do {
            let response = try await APIClient.shared.getRotaEntries(from: range.from, to: range.to)
            entries = response.entries
            errorText = nil
        } catch {
            if entries.isEmpty {
                errorText = "Could not load rota."
            }
        }
    }

    func toggle(dateKey: String, userName: String) async {
        if let existing = myEntry(for: dateKey, userName: userName) {
            // Optimistic removal
            entries.removeAll { $0.id == existing.id }
            do {
                try await APIClient.shared.deleteRotaEntry(id: existing.id)
            } catch {
                await load() // revert on failure
            }
        } else {
            // Optimistic add
            let temp = RotaEntry(id: UUID().uuidString, date: dateKey, name: userName, created_at: "")
            entries.append(temp)
            do {
                let real = try await APIClient.shared.addRotaEntry(date: dateKey, name: userName)
                entries.removeAll { $0.id == temp.id }
                entries.append(real)
            } catch {
                entries.removeAll { $0.id == temp.id }
                await load() // revert on failure
            }
        }
    }
}
