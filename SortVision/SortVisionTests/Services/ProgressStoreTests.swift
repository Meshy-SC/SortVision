import Foundation
import Testing

@testable import SortVision

// MARK: - ProgressStore Tests

@Suite("ProgressStore")
@MainActor
struct ProgressStoreTests {

    // MARK: - Sound Preference

    @Test("loadSoundPreference defaults to true on first launch")
    func soundPreferenceDefaultsToTrue() {
        let snapshot = UserDefaultsSnapshot(keys: [ProgressStore.soundEnabledKey])
        defer { snapshot.restore() }

        UserDefaults.standard.removeObject(forKey: ProgressStore.soundEnabledKey)
        let result = ProgressStore.loadSoundPreference()

        #expect(result == true)
    }

    @Test("saveSoundPreference round-trips correctly")
    func soundPreferenceRoundTrip() {
        let snapshot = UserDefaultsSnapshot(keys: [ProgressStore.soundEnabledKey])
        defer { snapshot.restore() }

        ProgressStore.saveSoundPreference(false)
        #expect(ProgressStore.loadSoundPreference() == false)

        ProgressStore.saveSoundPreference(true)
        #expect(ProgressStore.loadSoundPreference() == true)
    }

    // MARK: - Level Completion

    @Test("loadCompletedLevel returns 0 when no progress saved")
    func completedLevelDefaultsToZero() {
        let snapshot = UserDefaultsSnapshot(keys: [ProgressStore.completionKey])
        defer { snapshot.restore() }

        UserDefaults.standard.removeObject(forKey: ProgressStore.completionKey)
        #expect(ProgressStore.loadCompletedLevel() == 0)
    }

    @Test("saveCompletedLevel and loadCompletedLevel round-trip")
    func completedLevelRoundTrip() {
        let snapshot = UserDefaultsSnapshot(keys: [ProgressStore.completionKey])
        defer { snapshot.restore() }

        ProgressStore.saveCompletedLevel(42)
        #expect(ProgressStore.loadCompletedLevel() == 42)
    }

    // MARK: - Best Moves & Star Ratings

    @Test("loadBestMoves returns empty dict when no data saved")
    func bestMovesEmpty() {
        let snapshot = UserDefaultsSnapshot(keys: [ProgressStore.bestMovesKey])
        defer { snapshot.restore() }

        UserDefaults.standard.removeObject(forKey: ProgressStore.bestMovesKey)
        #expect(ProgressStore.loadBestMoves().isEmpty)
    }

    @Test("loadStarRatings returns empty dict when no data saved")
    func starRatingsEmpty() {
        let snapshot = UserDefaultsSnapshot(keys: [ProgressStore.starRatingsKey])
        defer { snapshot.restore() }

        UserDefaults.standard.removeObject(forKey: ProgressStore.starRatingsKey)
        #expect(ProgressStore.loadStarRatings().isEmpty)
    }

    @Test("saveBestMovesAndRatings round-trips correctly")
    func bestMovesAndRatingsRoundTrip() {
        let snapshot = UserDefaultsSnapshot(keys: [
            ProgressStore.bestMovesKey,
            ProgressStore.starRatingsKey,
        ])
        defer { snapshot.restore() }

        let bestMoves: [Int: Int] = [1: 5, 2: 8, 100: 12]
        let starRatings: [Int: Int] = [1: 3, 2: 2, 100: 1]

        ProgressStore.saveBestMovesAndRatings(
            bestMoves: bestMoves,
            starRatings: starRatings
        )

        let loadedMoves = ProgressStore.loadBestMoves()
        let loadedStars = ProgressStore.loadStarRatings()

        #expect(loadedMoves == bestMoves)
        #expect(loadedStars == starRatings)
    }

    // MARK: - Legacy Migration

    @Test("migrateFromLegacyProgress runs only once")
    func migrationRunsOnce() {
        let snapshot = UserDefaultsSnapshot(keys: [
            ProgressStore.migrationKey,
            ProgressStore.completionKey,
            "easy_Level_Complete",
            "normal_Level_Complete",
            "hard_Level_Complete",
            "expert_Level_Complete",
        ])
        defer { snapshot.restore() }

        // Clear migration flag
        UserDefaults.standard.removeObject(forKey: ProgressStore.migrationKey)
        UserDefaults.standard.set(50, forKey: "easy_Level_Complete")

        let firstRun = ProgressStore.migrateFromLegacyProgress()
        #expect(firstRun == true)

        let secondRun = ProgressStore.migrateFromLegacyProgress()
        #expect(secondRun == false)
    }

    @Test("Legacy migration calculates correct global level from difficulty offsets")
    func migrationCalculatesCorrectGlobal() {
        let snapshot = UserDefaultsSnapshot(keys: [
            ProgressStore.migrationKey,
            ProgressStore.completionKey,
            "easy_Level_Complete",
            "normal_Level_Complete",
            "hard_Level_Complete",
            "expert_Level_Complete",
        ])
        defer { snapshot.restore() }

        UserDefaults.standard.removeObject(forKey: ProgressStore.migrationKey)
        UserDefaults.standard.set(100, forKey: "easy_Level_Complete") // offset 0 → 100
        UserDefaults.standard.set(50, forKey: "normal_Level_Complete") // offset 100 → 150
        UserDefaults.standard.set(0, forKey: "hard_Level_Complete") // 0 → not counted
        UserDefaults.standard.set(25, forKey: "expert_Level_Complete") // offset 300 → 325

        ProgressStore.migrateFromLegacyProgress()

        let result = ProgressStore.loadCompletedLevel()
        #expect(result == 325, "Should take the maximum across all difficulties")
    }

    @Test("Legacy migration with no legacy data leaves progress at 0")
    func migrationWithNoLegacyData() {
        let snapshot = UserDefaultsSnapshot(keys: [
            ProgressStore.migrationKey,
            ProgressStore.completionKey,
            "easy_Level_Complete",
            "normal_Level_Complete",
            "hard_Level_Complete",
            "expert_Level_Complete",
        ])
        defer { snapshot.restore() }

        UserDefaults.standard.removeObject(forKey: ProgressStore.migrationKey)
        UserDefaults.standard.removeObject(forKey: "easy_Level_Complete")
        UserDefaults.standard.removeObject(forKey: "normal_Level_Complete")
        UserDefaults.standard.removeObject(forKey: "hard_Level_Complete")
        UserDefaults.standard.removeObject(forKey: "expert_Level_Complete")
        UserDefaults.standard.set(0, forKey: ProgressStore.completionKey)

        ProgressStore.migrateFromLegacyProgress()

        #expect(ProgressStore.loadCompletedLevel() == 0)
    }

    // MARK: - Reset

    @Test("resetAllProgress clears completion, bestMoves, and starRatings")
    func resetAllProgress() {
        let snapshot = UserDefaultsSnapshot(keys: [
            ProgressStore.completionKey,
            ProgressStore.bestMovesKey,
            ProgressStore.starRatingsKey,
        ])
        defer { snapshot.restore() }

        ProgressStore.saveCompletedLevel(50)
        ProgressStore.saveBestMovesAndRatings(
            bestMoves: [1: 5],
            starRatings: [1: 3]
        )

        ProgressStore.resetAllProgress()

        #expect(ProgressStore.loadCompletedLevel() == 0)
        #expect(ProgressStore.loadBestMoves().isEmpty)
        #expect(ProgressStore.loadStarRatings().isEmpty)
    }

    // MARK: - Key Constants

    @Test("UserDefaults keys are stable strings")
    func keyConstants() {
        #expect(ProgressStore.soundEnabledKey == "soundEnabled")
        #expect(ProgressStore.completionKey == "globalLevelCompleted")
        #expect(ProgressStore.bestMovesKey == "bestMoves")
        #expect(ProgressStore.starRatingsKey == "starRatings")
        #expect(ProgressStore.migrationKey == "stage_progress_migrated")
    }
}
