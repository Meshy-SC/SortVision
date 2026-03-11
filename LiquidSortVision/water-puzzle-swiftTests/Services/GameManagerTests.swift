import Foundation
import Testing

@testable import water_puzzle_swift

@Suite("GameManager")
@MainActor
struct GameManagerTests {

    // MARK: - Level Loading

    @Test("Levels load for stages with content",
          arguments: [Stage.iron, .bronze, .silver, .gold])
    func levelsLoadForAvailableStages(stage: Stage) {
        let levels = GameManager.shared.levels(for: stage)
        #expect(!levels.isEmpty, "\(stage.displayName) should have levels loaded from bundle")
    }

    @Test("Stages without content have empty level arrays",
          arguments: [Stage.platinum, .diamond, .emerald, .ruby, .obsidian, .legend])
    func noLevelsForUnavailableStages(stage: Stage) {
        let levels = GameManager.shared.levels(for: stage)
        #expect(levels.isEmpty, "\(stage.displayName) should have no levels yet")
    }

    @Test("No loading errors for available stages",
          arguments: [Stage.iron, .bronze, .silver, .gold])
    func noLoadingErrors(stage: Stage) {
        let error = GameManager.shared.levelLoadingErrors[stage]
        #expect(error == nil, "Loading \(stage.displayName) should not produce errors")
    }

    @Test("Level global numbers are sequential within each stage",
          arguments: [Stage.iron, .bronze, .silver, .gold])
    func levelGlobalNumbers(stage: Stage) {
        let levels = GameManager.shared.levels(for: stage)
        let range = stage.levelRange
        for (index, level) in levels.enumerated() {
            let expectedGlobal = range.lowerBound + index
            #expect(level.number == expectedGlobal,
                    "\(stage.displayName) level at index \(index) should have global number \(expectedGlobal), got \(level.number)")
        }
    }

    // MARK: - Level Queries

    @Test("level(globalNumber:) returns correct level for valid number")
    func levelForValidGlobalNumber() {
        let level = GameManager.shared.level(globalNumber: 1)
        #expect(level != nil)
        #expect(level?.number == 1)
    }

    @Test("level(globalNumber:) works across stages")
    func levelAcrossStages() {
        // Iron level
        let ironLevel = GameManager.shared.level(globalNumber: 50)
        #expect(ironLevel != nil)
        #expect(ironLevel?.number == 50)

        // Bronze level
        let bronzeLevel = GameManager.shared.level(globalNumber: 150)
        #expect(bronzeLevel != nil)
        #expect(bronzeLevel?.number == 150)
    }

    @Test("level(globalNumber:) returns nil for number 0 (below range)")
    func levelForZero() {
        let level = GameManager.shared.level(globalNumber: 0)
        #expect(level == nil)
    }

    @Test("level(globalNumber:) returns nil for number beyond available levels")
    func levelBeyondRange() {
        let level = GameManager.shared.level(globalNumber: 99999)
        #expect(level == nil)
    }

    @Test("level(globalNumber:) returns nil for negative number")
    func levelForNegativeNumber() {
        let level = GameManager.shared.level(globalNumber: -1)
        #expect(level == nil)
    }

    // MARK: - Level Locking

    @Test("Level 1 is never locked (always the entry point)")
    func firstLevelNeverLocked() {
        let snapshot = UserDefaultsSnapshot(keys: [GameManager.completionKey])
        defer { snapshot.restore() }

        UserDefaults.standard.set(0, forKey: GameManager.completionKey)
        GameManager.shared.loadCompletedLevel()
        let isLocked = GameManager.shared.isLevelLocked(1)
        #expect(!isLocked, "Level 1 should never be locked")
    }

    @Test("Completed level + 1 is unlocked, completed + 2 is locked")
    func lockingBoundary() {
        let snapshot = UserDefaultsSnapshot(keys: [GameManager.completionKey])
        defer { snapshot.restore() }

        GameManager.shared.completeLevel(number: 5)

        #expect(!GameManager.shared.isLevelLocked(6))
        #expect(GameManager.shared.isLevelLocked(7))
        #expect(!GameManager.shared.isLevelLocked(5))
    }

    // MARK: - Stage Accessibility

    @Test("Iron (first stage) is always accessible")
    func ironAlwaysAccessible() {
        #expect(GameManager.shared.isStageAccessible(.iron))
    }

    @Test("Unavailable stages are never accessible")
    func unavailableStagesNotAccessible() {
        #expect(!GameManager.shared.isStageAccessible(.platinum))
        #expect(!GameManager.shared.isStageAccessible(.legend))
    }

    // MARK: - Completed Count In Stage

    @Test("completedCountInStage returns correct count")
    func completedCountInStage() {
        let snapshot = UserDefaultsSnapshot(keys: [GameManager.completionKey])
        defer { snapshot.restore() }

        GameManager.shared.completeLevel(number: 50)
        #expect(GameManager.shared.completedCountInStage(.iron) == 50)
        #expect(GameManager.shared.completedCountInStage(.bronze) == 0)
    }

    @Test("completedCountInStage caps at levelsPerStage for completed stages")
    func completedCountCapped() {
        let snapshot = UserDefaultsSnapshot(keys: [GameManager.completionKey])
        defer { snapshot.restore() }

        GameManager.shared.completeLevel(number: 150)
        #expect(GameManager.shared.completedCountInStage(.iron) == 100)
        #expect(GameManager.shared.completedCountInStage(.bronze) == 50)
    }

    // MARK: - Level Completion

    @Test("completeLevel advances progress for higher level numbers")
    func completeLevelAdvancesProgress() {
        let snapshot = UserDefaultsSnapshot(keys: [GameManager.completionKey])
        defer { snapshot.restore() }

        UserDefaults.standard.set(0, forKey: GameManager.completionKey)
        GameManager.shared.loadCompletedLevel()
        GameManager.shared.completeLevel(number: 3)

        #expect(GameManager.shared.completedLevel == 3)
    }

    @Test("completeLevel does not regress progress for lower level numbers")
    func completeLevelDoesNotRegress() {
        let snapshot = UserDefaultsSnapshot(keys: [GameManager.completionKey])
        defer { snapshot.restore() }

        GameManager.shared.completeLevel(number: 10)
        GameManager.shared.completeLevel(number: 5)

        #expect(GameManager.shared.completedLevel >= 10,
                "Completing a lower level should not reduce progress")
    }

    @Test("completeLevel persists to UserDefaults")
    func completeLevelPersists() {
        let snapshot = UserDefaultsSnapshot(keys: [GameManager.completionKey])
        defer { snapshot.restore() }

        GameManager.shared.completeLevel(number: 7)

        let persisted = UserDefaults.standard.integer(forKey: GameManager.completionKey)
        #expect(persisted == 7)
    }

    // MARK: - Has Next Level

    @Test("hasNextLevel returns true when more levels exist")
    func hasNextLevelTrue() {
        #expect(GameManager.shared.hasNextLevel(after: 1))
    }

    @Test("hasNextLevel returns false beyond available content")
    func hasNextLevelFalseAtEnd() {
        let totalLevels = [Stage.iron, .bronze, .silver, .gold]
            .reduce(0) { $0 + GameManager.shared.levels(for: $1).count }
        #expect(!GameManager.shared.hasNextLevel(after: totalLevels))
    }

    // MARK: - Sound Preference

    @Test("soundEnabled persists to UserDefaults")
    func soundEnabledPersists() {
        let snapshot = UserDefaultsSnapshot(keys: [GameManager.soundEnabledKey])
        defer { snapshot.restore() }

        GameManager.shared.soundEnabled = false
        #expect(UserDefaults.standard.bool(forKey: GameManager.soundEnabledKey) == false)

        GameManager.shared.soundEnabled = true
        #expect(UserDefaults.standard.bool(forKey: GameManager.soundEnabledKey) == true)
    }
}

// MARK: - LevelLoadingError Tests

@Suite("LevelLoadingError")
struct LevelLoadingErrorTests {

    @Test("resourceNotFound includes filename in description")
    func resourceNotFoundDescription() {
        let error = LevelLoadingError.resourceNotFound("levels-missing")
        let desc = error.errorDescription ?? ""
        #expect(desc.contains("levels-missing"))
    }

    @Test("fileReadFailed includes both filename and underlying error")
    func fileReadFailedDescription() {
        let error = LevelLoadingError.fileReadFailed("levels", "Permission denied")
        let desc = error.errorDescription ?? ""
        #expect(desc.contains("levels"))
        #expect(desc.contains("Permission denied"))
    }

    @Test("decodingFailed includes filename and decoding details")
    func decodingFailedDescription() {
        let error = LevelLoadingError.decodingFailed("levels", "Key not found")
        let desc = error.errorDescription ?? ""
        #expect(desc.contains("levels"))
        #expect(desc.contains("Key not found"))
    }
}
