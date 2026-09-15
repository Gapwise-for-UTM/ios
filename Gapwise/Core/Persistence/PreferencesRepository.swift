import Foundation

protocol PreferencesRepository: Sendable {
    func load() async -> UserPreferences
    func save(_ preferences: UserPreferences) async
}

actor UserDefaultsPreferencesRepository: PreferencesRepository {
    private let defaults: UserDefaults
    private let key: String

    init(defaults: UserDefaults = .standard, key: String = "gapwise.preferences") {
        self.defaults = defaults
        self.key = key
    }

    func load() async -> UserPreferences {
        guard
            let data = defaults.data(forKey: key),
            let preferences = try? JSONDecoder().decode(UserPreferences.self, from: data)
        else {
            return .defaults
        }

        return preferences
    }

    func save(_ preferences: UserPreferences) async {
        guard let data = try? JSONEncoder().encode(preferences) else { return }
        defaults.set(data, forKey: key)
    }
}

actor InMemoryPreferencesRepository: PreferencesRepository {
    private var preferences: UserPreferences

    init(preferences: UserPreferences = .defaults) {
        self.preferences = preferences
    }

    func load() async -> UserPreferences {
        preferences
    }

    func save(_ preferences: UserPreferences) async {
        self.preferences = preferences
    }
}
