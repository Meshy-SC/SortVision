import SwiftUI

/// Metal/Material-based ranking tier for the game's level progression.
///
/// Replaces the old difficulty-based system with a 10-tier sequential
/// progression. Each stage contains up to 100 levels, numbered globally
/// from 1 to 1000.
///
/// ## Progression
/// ```
/// Iron (1–100) → Bronze (101–200) → Silver (201–300) → Gold (301–400)
/// → Platinum (401–500) → Diamond (501–600) → Emerald (601–700)
/// → Ruby (701–800) → Obsidian (801–900) → Legend (901–1000)
/// ```
///
/// Stages 1–4 have level content shipped in the bundle. Stages 5–10
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

    /// Number of levels each stage contains.
    static let levelsPerStage = 100

    // MARK: - Display Properties

    /// Human-readable stage name.
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

    /// SF Symbol icon for the stage.
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

    /// Theme color for the stage, adapts to light/dark mode.
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
