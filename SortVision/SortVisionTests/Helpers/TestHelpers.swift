import Foundation
import Testing

@testable import SortVision

// MARK: - Level Test Fixtures

/// Factory methods for creating test level data without coupling tests to JSON files.
enum TestFixtures {

    /// Creates a simple 3-tube level: two filled tubes + one empty.
    /// This is the minimal solvable puzzle.
    static func simpleLevel(number: Int = 1) -> Level {
        let json = """
        {
            "no": \(number),
            "map": [
                { "values": [1, 1, 1, 2] },
                { "values": [2, 2, 2, 1] },
                { "values": [] }
            ]
        }
        """
        return try! JSONDecoder().decode(Level.self, from: Data(json.utf8))
    }

    /// Creates a level with a single filled tube and one empty (trivially solved).
    static func solvedLevel(number: Int = 1) -> Level {
        let json = """
        {
            "no": \(number),
            "map": [
                { "values": [1, 1, 1, 1] },
                { "values": [2, 2, 2, 2] },
                { "values": [] }
            ]
        }
        """
        return try! JSONDecoder().decode(Level.self, from: Data(json.utf8))
    }

    /// Creates a level with many tubes (>6) to trigger two-row layout.
    static func largeLevel(tubeCount: Int = 8, number: Int = 1) -> Level {
        var maps: [String] = []
        for i in 0..<tubeCount {
            if i < tubeCount - 2 {
                maps.append("{ \"values\": [\(i % 6), \(i % 6), \((i + 1) % 6), \((i + 1) % 6)] }")
            } else {
                maps.append("{ \"values\": [] }")
            }
        }
        let json = """
        {
            "no": \(number),
            "map": [\(maps.joined(separator: ", "))]
        }
        """
        return try! JSONDecoder().decode(Level.self, from: Data(json.utf8))
    }

    /// Creates a level with a single empty tube.
    static func emptyTubeLevel(number: Int = 1) -> Level {
        let json = """
        {
            "no": \(number),
            "map": [
                { "values": [] }
            ]
        }
        """
        return try! JSONDecoder().decode(Level.self, from: Data(json.utf8))
    }

    /// Creates a level from specific column definitions.
    static func level(number: Int = 1, columns: [[Int]]) -> Level {
        let maps = columns.map { col in
            let vals = col.map(String.init).joined(separator: ", ")
            return "{ \"values\": [\(vals)] }"
        }
        let json = """
        {
            "no": \(number),
            "map": [\(maps.joined(separator: ", "))]
        }
        """
        return try! JSONDecoder().decode(Level.self, from: Data(json.utf8))
    }

    /// Raw JSON string for testing Codable round-trips.
    static let sampleLevelJSON = """
    {
        "no": 42,
        "map": [
            { "values": [1, 1, 2] },
            { "values": [2, 2, 1] },
            { "values": [] }
        ]
    }
    """

    static let sampleLevelGroupJSON = """
    {
        "levels": [
            {
                "no": 1,
                "map": [
                    { "values": [1, 1, 1, 2] },
                    { "values": [2, 2, 2, 1] },
                    { "values": [] }
                ]
            },
            {
                "no": 2,
                "map": [
                    { "values": [0, 1] },
                    { "values": [1, 0] },
                    { "values": [] }
                ]
            }
        ]
    }
    """
}

// MARK: - UserDefaults Test Isolation

/// Saves and restores UserDefaults keys used by GameManager to prevent test pollution.
struct UserDefaultsSnapshot {
    private var savedValues: [String: Any?] = [:]
    private let keys: [String]

    init(keys: [String]) {
        self.keys = keys
        for key in keys {
            savedValues[key] = UserDefaults.standard.object(forKey: key)
        }
    }

    /// Restores all saved values, removing keys that were previously absent.
    func restore() {
        for key in keys {
            if let value = savedValues[key] {
                if let v = value {
                    UserDefaults.standard.set(v, forKey: key)
                } else {
                    UserDefaults.standard.removeObject(forKey: key)
                }
            } else {
                UserDefaults.standard.removeObject(forKey: key)
            }
        }
    }

    /// All GameManager-related UserDefaults keys.
    static var gameManagerKeys: [String] {
        [GameManager.soundEnabledKey, GameManager.completionKey, "stage_progress_migrated"]
    }
}
