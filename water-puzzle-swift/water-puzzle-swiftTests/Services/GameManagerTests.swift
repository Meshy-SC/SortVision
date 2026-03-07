import Foundation
import Testing

@testable import water_puzzle_swift

@Suite("GameManager")
@MainActor
struct GameManagerTests {

    // MARK: - Level Loading

    @Test("Levels load for all game modes from bundle JSON",
          arguments: GameMode.allCases)
    func levelsLoadForAllModes(mode: GameMode) {
        let levels = GameManager.shared.levels(for: mode)
        #expect(!levels.isEmpty, "\(mode.displayName) should have levels loaded from bundle")
    }

    @Test("No loading errors for any game mode",
          arguments: GameMode.allCases)
    func noLoadingErrors(mode: GameMode) {
        let error = GameManager.shared.levelLoadingErrors[mode]
        #expect(error == nil, "Loading \(mode.displayName) should not produce errors")
    }

    @Test("Level numbers are sequential starting from 1",
          arguments: GameMode.allCases)
    func levelNumbersSequential(mode: GameMode) {
        let levels = GameManager.shared.levels(for: mode)
        for (index, level) in levels.enumerated() {
            #expect(level.number == index + 1,
                    "\(mode.displayName) level at index \(index) should be number \(index + 1)")
        }
    }

    // MARK: - Level Queries

    @Test("level(for:number:) returns correct level for valid number")
    func levelForValidNumber() {
        let level = GameManager.shared.level(for: .easy, number: 1)
        #expect(level != nil)
        #expect(level?.number == 1)
    }

    @Test("level(for:number:) returns nil for number 0 (below range)")
    func levelForZero() {
        let level = GameManager.shared.level(for: .easy, number: 0)
        #expect(level == nil)
    }

    @Test("level(for:number:) returns nil for number beyond range")
    func levelBeyondRange() {
        let totalLevels = GameManager.shared.levels(for: .easy).count
        let level = GameManager.shared.level(for: .easy, number: totalLevels + 1)
        #expect(level == nil)
    }

    @Test("level(for:number:) returns nil for negative number")
    func levelForNegativeNumber() {
        let level = GameManager.shared.level(for: .easy, number: -1)
        #expect(level == nil)
    }

    // MARK: - Level Locking

    @Test("Level 1 is never locked (always the entry point)")
    func firstLevelNeverLocked() {
        // Level 1 is unlocked when completedLevel is 0 (nothing completed)
        // because 1 > 0 + 1 is false
        let snapshot = UserDefaultsSnapshot(keys: [GameMode.easy.completionKey])
        defer { snapshot.restore() }

        UserDefaults.standard.set(0, forKey: GameMode.easy.completionKey)
        // Reload to pick up changes
        let isLocked = GameManager.shared.isLevelLocked(mode: .easy, number: 1)
        #expect(!isLocked, "Level 1 should never be locked")
    }

    @Test("Completed level + 1 is unlocked, completed + 2 is locked")
    func lockingBoundary() {
        let snapshot = UserDefaultsSnapshot(keys: [GameMode.normal.completionKey])
        defer { snapshot.restore() }

        // Simulate completing level 5
        GameManager.shared.completeLevel(mode: .normal, number: 5)

        // Level 6 should be unlocked (next playable)
        #expect(!GameManager.shared.isLevelLocked(mode: .normal, number: 6))
        // Level 7 should be locked
        #expect(GameManager.shared.isLevelLocked(mode: .normal, number: 7))
        // Level 5 (already completed) should not be locked
        #expect(!GameManager.shared.isLevelLocked(mode: .normal, number: 5))
    }

    // MARK: - Level Completion

    @Test("completeLevel advances progress for higher level numbers")
    func completeLevelAdvancesProgress() {
        let snapshot = UserDefaultsSnapshot(keys: [GameMode.hard.completionKey])
        defer { snapshot.restore() }

        // Reset progress
        UserDefaults.standard.set(0, forKey: GameMode.hard.completionKey)
        GameManager.shared.completeLevel(mode: .hard, number: 3)

        #expect(GameManager.shared.completedLevel(for: .hard) == 3)
    }

    @Test("completeLevel does not regress progress for lower level numbers")
    func completeLevelDoesNotRegress() {
        let snapshot = UserDefaultsSnapshot(keys: [GameMode.hard.completionKey])
        defer { snapshot.restore() }

        GameManager.shared.completeLevel(mode: .hard, number: 10)
        GameManager.shared.completeLevel(mode: .hard, number: 5)

        #expect(GameManager.shared.completedLevel(for: .hard) >= 10,
                "Completing a lower level should not reduce progress")
    }

    @Test("completeLevel persists to UserDefaults")
    func completeLevelPersists() {
        let snapshot = UserDefaultsSnapshot(keys: [GameMode.expert.completionKey])
        defer { snapshot.restore() }

        GameManager.shared.completeLevel(mode: .expert, number: 7)

        let persisted = UserDefaults.standard.integer(forKey: GameMode.expert.completionKey)
        #expect(persisted == 7)
    }

    // MARK: - Has Next Level

    @Test("hasNextLevel returns true when more levels exist")
    func hasNextLevelTrue() {
        let totalLevels = GameManager.shared.levels(for: .easy).count
        guard totalLevels > 1 else { return }

        #expect(GameManager.shared.hasNextLevel(mode: .easy, after: 1))
    }

    @Test("hasNextLevel returns false for the last level")
    func hasNextLevelFalseAtEnd() {
        let totalLevels = GameManager.shared.levels(for: .easy).count
        #expect(!GameManager.shared.hasNextLevel(mode: .easy, after: totalLevels))
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
