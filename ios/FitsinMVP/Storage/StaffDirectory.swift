import Foundation

enum StaffDirectory {
    static let adminName = "Louis"

    static var allNames: [String] {
        let stored = UserDefaults.standard.stringArray(forKey: "staff_names") ?? []
        let defaults = ["Archie", "Louis", "Brad", "Theo", "Tony", "Crawford"]
        return stored.isEmpty ? defaults : stored
    }

    static func addName(_ name: String) {
        var names = allNames
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !names.contains(where: { $0.lowercased() == trimmed.lowercased() }) else { return }
        names.append(trimmed)
        names.sort()
        UserDefaults.standard.set(names, forKey: "staff_names")
    }

    static func removeName(_ name: String) {
        var names = allNames
        names.removeAll { $0.lowercased() == name.lowercased() }
        UserDefaults.standard.set(names, forKey: "staff_names")
    }

    // MARK: - PINs

    private static let pinsKey = "staff_pins"

    private static var allPins: [String: String] {
        get { UserDefaults.standard.dictionary(forKey: pinsKey) as? [String: String] ?? [:] }
        set { UserDefaults.standard.set(newValue, forKey: pinsKey) }
    }

    static func pin(for name: String) -> String? {
        allPins[name.lowercased()]
    }

    static func setPin(_ pin: String, for name: String) {
        var pins = allPins
        pins[name.lowercased()] = pin
        allPins = pins
    }

    static func clearPin(for name: String) {
        var pins = allPins
        pins.removeValue(forKey: name.lowercased())
        allPins = pins
    }

    static func hasPin(_ name: String) -> Bool {
        pin(for: name) != nil
    }

    static func generatePin() -> String {
        String(format: "%06d", Int.random(in: 100000...999999))
    }

    static func verify(name: String, pin: String) -> Bool {
        guard let stored = self.pin(for: name) else { return false }
        return stored == pin
    }

    static func isAdmin(_ name: String?) -> Bool {
        guard let name else { return false }
        return name.lowercased() == adminName.lowercased()
    }
}
