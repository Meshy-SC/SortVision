import SwiftUI
import Observation

/// Central game state manager. Mirrors Unity's ResourceManager + GameManager:
/// - Loads and caches level JSON data for all four game modes
/// - Tracks level completion progress via UserDefaults (replacing Unity PlayerPrefs)
/// - Manages sound enabled state
@Observable
final class GameManager {
    static let shared = GameManager()

    // MARK: - Level Cache

    private var levelCache: [GameMode: [Level]] = [:]

    // MARK: - Observable State

    /// Tracks completed levels per mode. Dictionary mutation triggers SwiftUI updates.
    private(set) var completedLevels: [GameMode: Int] = [:]

    /// Sound on/off toggle, persisted to UserDefaults.
    var soundEnabled: Bool = true {
        didSet {
            UserDefaults.standard.set(soundEnabled, forKey: "soundEnabled")
        }
    }

    // MARK: - Init

    private init() {
        // Load sound preference (default to true on first launch)
        if UserDefaults.standard.object(forKey: "soundEnabled") == nil {
            UserDefaults.standard.set(true, forKey: "soundEnabled")
        }
        soundEnabled = UserDefaults.standard.bool(forKey: "soundEnabled")

        loadAllLevels()
        loadCompletedLevels()
    }

    // MARK: - Level Loading

    private func loadAllLevels() {
        for mode in GameMode.allCases {
            guard let url = Bundle.main.url(forResource: mode.jsonFileName, withExtension: "json"),
                  let data = try? Data(contentsOf: url),
                  let group = try? JSONDecoder().decode(LevelGroup.self, from: data)
            else {
                continue
            }
            levelCache[mode] = group.levels
        }
    }

    private func loadCompletedLevels() {
        for mode in GameMode.allCases {
            completedLevels[mode] = UserDefaults.standard.integer(forKey: mode.completionKey)
        }
    }

    // MARK: - Level Queries

    func levels(for mode: GameMode) -> [Level] {
        levelCache[mode] ?? []
    }

    func level(for mode: GameMode, number: Int) -> Level? {
        let allLevels = levels(for: mode)
        guard number >= 1, number <= allLevels.count else { return nil }
        return allLevels[number - 1]
    }

    func completedLevel(for mode: GameMode) -> Int {
        completedLevels[mode] ?? 0
    }

    func isLevelLocked(mode: GameMode, number: Int) -> Bool {
        number > completedLevel(for: mode) + 1
    }

    func hasNextLevel(mode: GameMode, after number: Int) -> Bool {
        levels(for: mode).count > number
    }

    // MARK: - Level Completion

    func completeLevel(mode: GameMode, number: Int) {
        let current = completedLevel(for: mode)
        if number > current {
            completedLevels[mode] = number
            UserDefaults.standard.set(number, forKey: mode.completionKey)
        }
    }
}
