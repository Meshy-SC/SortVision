// PushBoxShortcuts.swift
// App Intents and Shortcuts support for Spotlight and Siri integration.

import AppIntents
import SwiftData

// MARK: - Continue Puzzle Intent

/// Allows users to resume their last puzzle from Spotlight or Siri.
/// Opens the app, which automatically restores the last navigation state.
struct ContinuePuzzleIntent: AppIntent {
    static let title: LocalizedStringResource = "Continue Puzzle"
    static let description = IntentDescription("Resume your last Push Box puzzle.")
    static let openAppWhenRun = true

    func perform() async throws -> some IntentResult & ProvidesDialog {
        return .result(dialog: "Resuming your last Push Box puzzle")
    }
}

// MARK: - Show Progress Intent

/// Allows users to check their game progress from Spotlight or Siri.
/// Reads completion data from SwiftData and returns a summary dialog.
struct ShowProgressIntent: AppIntent {
    static let title: LocalizedStringResource = "Show Progress"
    static let description = IntentDescription("Check your Push Box game progress.")
    static let openAppWhenRun = true

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let container = ModelContainerFactory.makeContainer()
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<LevelProgressModel>()
        let models = (try? context.fetch(descriptor)) ?? []
        let completed = models.filter(\.isCompleted).count
        let totalLevels = World.allWorlds.reduce(0) { $0 + $1.levelCount }
        let percentage = totalLevels > 0 ? Int(Double(completed) / Double(totalLevels) * 100) : 0
        return .result(dialog: "You've completed \(completed) of \(totalLevels) levels (\(percentage)%)")
    }
}

// MARK: - App Shortcuts Provider

/// Registers PushBox shortcuts with the system for Spotlight and Siri.
struct PushBoxShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: ContinuePuzzleIntent(),
            phrases: [
                "Continue my \(.applicationName) puzzle",
                "Play \(.applicationName)",
                "Open \(.applicationName)"
            ],
            shortTitle: "Continue Puzzle",
            systemImageName: "cube.box"
        )
        AppShortcut(
            intent: ShowProgressIntent(),
            phrases: [
                "Show my \(.applicationName) progress",
                "\(.applicationName) progress"
            ],
            shortTitle: "Show Progress",
            systemImageName: "chart.bar.fill"
        )
    }
}
