import Foundation
import Testing

@testable import water_puzzle_swift

@Suite("WidgetDataProvider")
struct WidgetDataProviderTests {

    // MARK: - Completed Level

    @Test("completedLevel reads from UserDefaults",
          arguments: GameMode.allCases)
    func completedLevelReadsDefaults(mode: GameMode) {
        let snapshot = UserDefaultsSnapshot(keys: [mode.completionKey])
        defer { snapshot.restore() }

        UserDefaults.standard.set(15, forKey: mode.completionKey)
        #expect(WidgetDataProvider.completedLevel(for: mode) == 15)
    }

    @Test("completedLevel returns 0 when no progress saved")
    func completedLevelDefaultsToZero() {
        let key = "test_nonexistent_completion_key"
        UserDefaults.standard.removeObject(forKey: key)
        // UserDefaults.integer(forKey:) returns 0 for missing keys
        #expect(UserDefaults.standard.integer(forKey: key) == 0)
    }

    // MARK: - Next Level Number

    @Test("nextLevelNumber is completedLevel + 1",
          arguments: [0, 1, 5, 99])
    func nextLevelNumber(completed: Int) {
        let mode = GameMode.easy
        let snapshot = UserDefaultsSnapshot(keys: [mode.completionKey])
        defer { snapshot.restore() }

        UserDefaults.standard.set(completed, forKey: mode.completionKey)
        #expect(WidgetDataProvider.nextLevelNumber(for: mode) == completed + 1)
    }

    // MARK: - DifficultyProgress

    @Test("DifficultyProgress.isAllComplete when completed equals total")
    func isAllCompleteTrue() {
        let progress = WidgetDataProvider.DifficultyProgress(
            mode: .easy, completedCount: 100, nextLevel: 101, totalLevels: 100
        )
        #expect(progress.isAllComplete)
    }

    @Test("DifficultyProgress.isAllComplete when completed exceeds total")
    func isAllCompleteTrueWhenExceeds() {
        let progress = WidgetDataProvider.DifficultyProgress(
            mode: .easy, completedCount: 150, nextLevel: 151, totalLevels: 100
        )
        #expect(progress.isAllComplete)
    }

    @Test("DifficultyProgress is not complete when progress remains")
    func isNotAllComplete() {
        let progress = WidgetDataProvider.DifficultyProgress(
            mode: .hard, completedCount: 50, nextLevel: 51, totalLevels: 200
        )
        #expect(!progress.isAllComplete)
    }

    @Test("DifficultyProgress.progress ratio is correct",
          arguments: [
            (0, 100, 0.0),
            (50, 100, 0.5),
            (100, 100, 1.0),
            (1, 4, 0.25),
          ] as [(Int, Int, Double)])
    func progressRatio(completed: Int, total: Int, expected: Double) {
        let progress = WidgetDataProvider.DifficultyProgress(
            mode: .easy, completedCount: completed, nextLevel: completed + 1, totalLevels: total
        )
        #expect(abs(progress.progress - expected) < 0.001)
    }

    @Test("DifficultyProgress.progress is 0 when totalLevels is 0 (division safety)")
    func progressZeroDivision() {
        let progress = WidgetDataProvider.DifficultyProgress(
            mode: .easy, completedCount: 5, nextLevel: 6, totalLevels: 0
        )
        #expect(progress.progress == 0)
    }

    @Test("progress(for:totalLevels:) creates correct DifficultyProgress")
    func progressFactory() {
        let mode = GameMode.normal
        let snapshot = UserDefaultsSnapshot(keys: [mode.completionKey])
        defer { snapshot.restore() }

        UserDefaults.standard.set(25, forKey: mode.completionKey)

        let progress = WidgetDataProvider.progress(for: mode, totalLevels: 200)
        #expect(progress.mode == .normal)
        #expect(progress.completedCount == 25)
        #expect(progress.nextLevel == 26)
        #expect(progress.totalLevels == 200)
        #expect(abs(progress.progress - 0.125) < 0.001)
    }
}
