import AppIntents
import Foundation

// MARK: - Game Mode App Enum (for Siri & Shortcuts parameter)

/// Exposes `GameMode` to App Intents as a selectable parameter.
///
/// Allows Siri and the Shortcuts app to present a picker for difficulty
/// selection when building or invoking the "Play Level" shortcut.
enum GameModeAppEnum: String, AppEnum, Sendable {
    case easy
    case normal
    case hard
    case expert

    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        "Difficulty"
    }

    static var caseDisplayRepresentations: [GameModeAppEnum: DisplayRepresentation] {
        [
            .easy: "Easy",
            .normal: "Normal",
            .hard: "Hard",
            .expert: "Expert",
        ]
    }

    /// Converts to the app's internal `GameMode` enum.
    var gameMode: GameMode {
        switch self {
        case .easy: .easy
        case .normal: .normal
        case .hard: .hard
        case .expert: .expert
        }
    }

    /// Creates from the app's internal `GameMode` enum.
    init(from mode: GameMode) {
        switch mode {
        case .easy: self = .easy
        case .normal: self = .normal
        case .hard: self = .hard
        case .expert: self = .expert
        }
    }
}

// MARK: - Play Level Intent

/// App Intent that opens the app to a specific level.
///
/// Surfaces in Siri, Shortcuts, and Spotlight:
/// - "Play Easy Level 5 in Water Sort Puzzle"
/// - Configurable via Shortcuts app with difficulty and level number parameters
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

    @Parameter(title: "Difficulty", default: .easy)
    var difficulty: GameModeAppEnum

    @Parameter(title: "Level Number", default: 1)
    var levelNumber: Int

    @MainActor
    func perform() async throws -> some IntentResult {
        let mode = difficulty.gameMode
        let manager = GameManager.shared

        // Validate level exists and is unlocked
        guard manager.level(for: mode, number: levelNumber) != nil else {
            throw PlayLevelError.levelNotFound(levelNumber, mode.displayName)
        }

        guard !manager.isLevelLocked(mode: mode, number: levelNumber) else {
            throw PlayLevelError.levelLocked(levelNumber, mode.displayName)
        }

        // Set the deep link for the app to navigate to on activation
        DeepLinkManager.shared.pendingLevel = (mode: mode, number: levelNumber)

        return .result()
    }
}

/// Errors for the Play Level intent, shown to the user in Shortcuts / Siri.
enum PlayLevelError: LocalizedError, CustomLocalizedStringResourceConvertible {
    case levelNotFound(Int, String)
    case levelLocked(Int, String)

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .levelNotFound(let number, let difficulty):
            "Level \(number) doesn't exist in \(difficulty) mode."
        case .levelLocked(let number, let difficulty):
            "Level \(number) in \(difficulty) mode is still locked. Complete earlier levels first."
        }
    }
}

// MARK: - Continue Playing Intent

/// App Intent that resumes the player's next unsolved level.
///
/// Surfaces in Siri and Shortcuts:
/// - "Continue playing Water Sort Puzzle"
/// - Automatically picks the next unlocked level in the chosen difficulty
struct ContinuePlayingIntent: AppIntent {
    nonisolated static let title: LocalizedStringResource = "Continue Playing"

    nonisolated static let description: IntentDescription = IntentDescription(
        "Resume your next unsolved Water Sort Puzzle level",
        categoryName: "Game"
    )

    nonisolated static let openAppWhenRun: Bool = true

    @Parameter(title: "Difficulty", default: .easy)
    var difficulty: GameModeAppEnum

    @MainActor
    func perform() async throws -> some IntentResult {
        let mode = difficulty.gameMode
        let manager = GameManager.shared
        let nextLevel = manager.completedLevel(for: mode) + 1
        let totalLevels = manager.levels(for: mode).count

        guard nextLevel <= totalLevels else {
            throw ContinuePlayingError.allCompleted(mode.displayName)
        }

        DeepLinkManager.shared.pendingLevel = (mode: mode, number: nextLevel)

        return .result()
    }
}

/// Errors for the Continue Playing intent.
enum ContinuePlayingError: LocalizedError, CustomLocalizedStringResourceConvertible {
    case allCompleted(String)

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .allCompleted(let difficulty):
            "You've completed all \(difficulty) levels! Try a harder difficulty."
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
                "Play a \(\.$difficulty) level in \(.applicationName)",
                "Start \(\.$difficulty) in \(.applicationName)",
            ],
            shortTitle: "Play Level",
            systemImageName: "puzzlepiece.fill"
        )
    }
}
