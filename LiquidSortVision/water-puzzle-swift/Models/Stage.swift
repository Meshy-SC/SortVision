import SwiftUI

/// Metal/Material-based world tier for the game's level progression.
///
/// The game features 10 worlds, each containing 100 levels numbered
/// globally from 1 to 1000.
///
/// ## Progression
/// ```
/// World 1: Iron (1–100) → World 2: Bronze (101–200) → …
/// → World 10: Legend (901–1000)
/// ```
///
/// Worlds 1–4 have level content shipped in the bundle. Worlds 5–10
/// are reserved for future content.
enum Stage: Int, CaseIterable, Codable, Sendable, Identifiable, Hashable {
    case iron = 0
    case bronze = 1
    case silver = 2
    case gold = 3
    case platinum = 4
    case diamond = 5
    case emerald = 6
    case ruby = 7
    case obsidian = 8
    case legend = 9

    var id: Int { rawValue }

    /// Number of levels each world contains.
    static let levelsPerStage = 100

    // MARK: - Display Properties

    /// 1-based world number for display (1–10).
    var worldNumber: Int { rawValue + 1 }

    /// Human-readable world name.
    var displayName: String {
        switch self {
        case .iron:     "Iron"
        case .bronze:   "Bronze"
        case .silver:   "Silver"
        case .gold:     "Gold"
        case .platinum: "Platinum"
        case .diamond:  "Diamond"
        case .emerald:  "Emerald"
        case .ruby:     "Ruby"
        case .obsidian: "Obsidian"
        case .legend:   "Legend"
        }
    }

    /// Thematic subtitle for the world.
    var subtitle: String {
        switch self {
        case .iron:     "The Forge"
        case .bronze:   "Age of Valor"
        case .silver:   "Moonlit Trials"
        case .gold:     "Crown Jewels"
        case .platinum: "Ethereal Heights"
        case .diamond:  "Crystal Depths"
        case .emerald:  "Verdant Maze"
        case .ruby:     "Crimson Gauntlet"
        case .obsidian: "Shadow Realm"
        case .legend:   "Hall of Fame"
        }
    }

    /// SF Symbol icon for the world.
    var iconName: String {
        switch self {
        case .iron:     "hammer.fill"
        case .bronze:   "shield.fill"
        case .silver:   "star.fill"
        case .gold:     "crown.fill"
        case .platinum: "sparkles"
        case .diamond:  "suit.diamond.fill"
        case .emerald:  "leaf.fill"
        case .ruby:     "flame.fill"
        case .obsidian: "moon.fill"
        case .legend:   "trophy.fill"
        }
    }

    /// Theme color for the world, adapts to light/dark mode.
    var themeColor: Color {
        switch self {
        case .iron:     .gray
        case .bronze:   Color(red: 0.80, green: 0.50, blue: 0.20)
        case .silver:   Color(red: 0.75, green: 0.75, blue: 0.78)
        case .gold:     .yellow
        case .platinum: .mint
        case .diamond:  .cyan
        case .emerald:  .green
        case .ruby:     .red
        case .obsidian: .indigo
        case .legend:   .purple
        }
    }

    /// Secondary gradient color for the world card.
    var secondaryColor: Color {
        switch self {
        case .iron:     Color(red: 0.45, green: 0.45, blue: 0.50)
        case .bronze:   Color(red: 0.60, green: 0.35, blue: 0.10)
        case .silver:   Color(red: 0.55, green: 0.55, blue: 0.60)
        case .gold:     Color(red: 0.85, green: 0.65, blue: 0.00)
        case .platinum: Color(red: 0.40, green: 0.80, blue: 0.75)
        case .diamond:  Color(red: 0.10, green: 0.60, blue: 0.80)
        case .emerald:  Color(red: 0.10, green: 0.55, blue: 0.25)
        case .ruby:     Color(red: 0.75, green: 0.10, blue: 0.15)
        case .obsidian: Color(red: 0.20, green: 0.15, blue: 0.50)
        case .legend:   Color(red: 0.50, green: 0.20, blue: 0.60)
        }
    }

    // MARK: - Level Range

    /// Global level number range for this stage (e.g. Iron = 1...100).
    var levelRange: ClosedRange<Int> {
        let start = rawValue * Self.levelsPerStage + 1
        let end = start + Self.levelsPerStage - 1
        return start...end
    }

    // MARK: - Resource Mapping

    /// JSON resource filename (without extension). `nil` if content not yet available.
    var levelResourceName: String? {
        switch self {
        case .iron:   "levels"
        case .bronze: "levels-normal"
        case .silver: "levels-hard"
        case .gold:   "levels-ex"
        default:      nil
        }
    }

    /// Whether this stage has level content shipped in the app bundle.
    var isAvailable: Bool {
        levelResourceName != nil
    }

    // MARK: - UserDefaults

    /// UserDefaults key for legacy per-stage tracking (used in migration).
    var completionKey: String {
        "stage_\(rawValue)_completed"
    }

    // MARK: - Helpers

    /// Returns the stage that contains the given global level number.
    ///
    /// - Parameter globalLevelNumber: A 1-based global level number (1–1000).
    /// - Returns: The corresponding stage, or `nil` if the number is out of range.
    static func stage(for globalLevelNumber: Int) -> Stage? {
        guard globalLevelNumber >= 1 else { return nil }
        let index = (globalLevelNumber - 1) / levelsPerStage
        return Stage(rawValue: index)
    }

    /// Converts a global level number to its local (1–100) display number within the stage.
    ///
    /// - Parameter globalLevelNumber: A 1-based global level number.
    /// - Returns: The local level number (1–100) within the stage.
    static func localLevelNumber(for globalLevelNumber: Int) -> Int {
        ((globalLevelNumber - 1) % levelsPerStage) + 1
    }
}
