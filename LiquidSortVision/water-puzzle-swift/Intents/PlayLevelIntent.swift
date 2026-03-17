import AppIntents
import Foundation

// MARK: - Stage App Enum (for Siri & Shortcuts parameter)

/// Exposes `Stage` (World) to App Intents as a selectable parameter.
///
/// Allows Siri and the Shortcuts app to present a picker for world
/// selection when building or invoking the "Play Level" shortcut.
enum StageAppEnum: String, AppEnum, Sendable {
    case iron
    case bronze
    case silver
    case gold
    case platinum
    case diamond
    case emerald
    case ruby
    case obsidian
    case legend

    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        "World"
    }

    static var caseDisplayRepresentations: [StageAppEnum: DisplayRepresentation] {
        [
            .iron: "Iron",
            .bronze: "Bronze",
            .silver: "Silver",
            .gold: "Gold",
            .platinum: "Platinum",
            .diamond: "Diamond",
            .emerald: "Emerald",
            .ruby: "Ruby",
            .obsidian: "Obsidian",
            .legend: "Legend",
        ]
    }

    /// Converts to the app's internal `Stage` enum.
    var stage: Stage {
        switch self {
        case .iron:     .iron
        case .bronze:   .bronze
        case .silver:   .silver
        case .gold:     .gold
        case .platinum: .platinum
        case .diamond:  .diamond
        case .emerald:  .emerald
        case .ruby:     .ruby
        case .obsidian: .obsidian
        case .legend:   .legend
        }
    }

    /// Creates from the app's internal `Stage` enum.
    init(from stage: Stage) {
        switch stage {
        case .iron:     self = .iron
        case .bronze:   self = .bronze
        case .silver:   self = .silver
        case .gold:     self = .gold
        case .platinum: self = .platinum
        case .diamond:  self = .diamond
        case .emerald:  self = .emerald
        case .ruby:     self = .ruby
        case .obsidian: self = .obsidian
        case .legend:   self = .legend
        }
    }
}

// MARK: - Play Level Intent

/// App Intent that opens the app to a specific level.
///
/// Surfaces in Siri, Shortcuts, and Spotlight:
/// - "Play Iron Level 5 in Water Sort Puzzle"
/// - Configurable via Shortcuts app with stage and level number parameters
///
/// Uses `OpenIntent` protocol to bring the app to the foreground and
/// passes the selected level via the shared `DeepLinkManager`.
struct PlayLevelIntent: AppIntent {
    nonisolated static let title: LocalizedStringResource = "Play Level"

    nonisolated static let description: IntentDescription = IntentDescription(
        "Open a specific Water Sort Puzzle level",
        categoryName: "Game"
    )

    nonisolated static let openAppWhenRun: Bool = true

    @Parameter(title: "World", default: .iron)
    var stage: StageAppEnum

    @Parameter(title: "Level Number", default: 1)
    var levelNumber: Int

    @MainActor
    func perform() async throws -> some IntentResult {
        let stageValue = stage.stage
        let globalNumber = stageValue.levelRange.lowerBound + levelNumber - 1
        let manager = GameManager.shared

        // Validate level exists and is unlocked
        guard manager.level(globalNumber: globalNumber) != nil else {
            throw PlayLevelError.levelNotFound(levelNumber, stageValue.displayName)
        }

        guard !manager.isLevelLocked(globalNumber) else {
            throw PlayLevelError.levelLocked(levelNumber, stageValue.displayName)
        }

        // Set the deep link for the app to navigate to on activation
        DeepLinkManager.shared.pendingLevel = globalNumber

        return .result()
    }
}

/// Errors for the Play Level intent, shown to the user in Shortcuts / Siri.
enum PlayLevelError: LocalizedError, CustomLocalizedStringResourceConvertible {
    case levelNotFound(Int, String)
    case levelLocked(Int, String)

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .levelNotFound(let number, let world):
            "Level \(number) doesn't exist in \(world) world."
        case .levelLocked(let number, let world):
            "Level \(number) in \(world) world is still locked. Complete earlier levels first."
        }
    }
}

// MARK: - Continue Playing Intent

/// App Intent that resumes the player's next unsolved level.
///
/// Surfaces in Siri and Shortcuts:
/// - "Continue playing Water Sort Puzzle"
/// - Automatically picks the next unlocked level
struct ContinuePlayingIntent: AppIntent {
    nonisolated static let title: LocalizedStringResource = "Continue Playing"

    nonisolated static let description: IntentDescription = IntentDescription(
        "Resume your next unsolved Water Sort Puzzle level",
        categoryName: "Game"
    )

    nonisolated static let openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult {
        let manager = GameManager.shared
        let nextLevel = manager.completedLevel + 1

        guard manager.level(globalNumber: nextLevel) != nil else {
            throw ContinuePlayingError.allCompleted
        }

        DeepLinkManager.shared.pendingLevel = nextLevel

        return .result()
    }
}

/// Errors for the Continue Playing intent.
enum ContinuePlayingError: LocalizedError, CustomLocalizedStringResourceConvertible {
    case allCompleted

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .allCompleted:
            "You've completed all available levels! More worlds are coming soon."
        }
    }
}

// MARK: - App Shortcuts Provider

/// Registers predefined Shortcuts phrases for Spotlight and Siri discovery.
///
/// These appear automatically in the Shortcuts app and can be triggered
/// by voice via Siri without any user configuration.
struct WaterPuzzleShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: ContinuePlayingIntent(),
            phrases: [
                "Continue playing \(.applicationName)",
                "Resume \(.applicationName)",
                "Play \(.applicationName)",
            ],
            shortTitle: "Continue Playing",
            systemImageName: "play.fill"
        )
        AppShortcut(
            intent: PlayLevelIntent(),
            phrases: [
                "Play a \(\.$stage) level in \(.applicationName)",
                "Start \(\.$stage) world in \(.applicationName)",
            ],
            shortTitle: "Play Level",
            systemImageName: "puzzlepiece.fill"
        )
    }
}
