import Foundation
import Testing

@testable import water_puzzle_swift

@Suite("WidgetDataProvider")
struct WidgetDataProviderTests {

    // MARK: - Completed Level

    @Test("completedLevel reads from UserDefaults")
    func completedLevelReadsDefaults() {
        let snapshot = UserDefaultsSnapshot(keys: [GameManager.completionKey])
        defer { snapshot.restore() }

        UserDefaults.standard.set(15, forKey: GameManager.completionKey)
        #expect(WidgetDataProvider.completedLevel() == 15)
    }

    @Test("completedLevel returns 0 when no progress saved")
    func completedLevelDefaultsToZero() {
        let key = "test_nonexistent_completion_key"
        UserDefaults.standard.removeObject(forKey: key)
        #expect(UserDefaults.standard.integer(forKey: key) == 0)
    }

    // MARK: - Next Level Number

    @Test("nextLevelNumber is completedLevel + 1",
          arguments: [0, 1, 5, 99])
    func nextLevelNumber(completed: Int) {
        let snapshot = UserDefaultsSnapshot(keys: [GameManager.completionKey])
        defer { snapshot.restore() }

        UserDefaults.standard.set(completed, forKey: GameManager.completionKey)
        #expect(WidgetDataProvider.nextLevelNumber() == completed + 1)
    }

    // MARK: - Current Stage

    @Test("currentStage returns Iron when no progress")
    func currentStageAtStart() {
        let snapshot = UserDefaultsSnapshot(keys: [GameManager.completionKey])
        defer { snapshot.restore() }

        UserDefaults.standard.set(0, forKey: GameManager.completionKey)
        #expect(WidgetDataProvider.currentStage() == .iron)
    }

    @Test("currentStage reflects completed progress",
          arguments: [
            (50, Stage.iron),
            (100, .iron),
            (150, .bronze),
            (250, .silver),
            (350, .gold),
          ] as [(Int, Stage)])
    func currentStageReflectsProgress(completed: Int, expectedStage: Stage) {
        let snapshot = UserDefaultsSnapshot(keys: [GameManager.completionKey])
        defer { snapshot.restore() }

        UserDefaults.standard.set(completed, forKey: GameManager.completionKey)
        #expect(WidgetDataProvider.currentStage() == expectedStage)
    }

    // MARK: - GameProgress

    @Test("GameProgress.isAllComplete when all available levels done")
    func isAllCompleteTrue() {
        let progress = WidgetDataProvider.GameProgress(
            completedCount: 400, currentStage: .gold, nextLevel: 401
        )
        #expect(progress.isAllComplete)
    }

    @Test("GameProgress is not complete when progress remains")
    func isNotAllComplete() {
        let progress = WidgetDataProvider.GameProgress(
            completedCount: 50, currentStage: .iron, nextLevel: 51
        )
        #expect(!progress.isAllComplete)
    }

    @Test("GameProgress.stageCompletedCount is correct",
          arguments: [
            (50, Stage.iron, 50),
            (100, Stage.iron, 100),
            (150, Stage.bronze, 50),
            (0, Stage.iron, 0),
          ] as [(Int, Stage, Int)])
    func stageCompletedCount(completed: Int, stage: Stage, expected: Int) {
        let progress = WidgetDataProvider.GameProgress(
            completedCount: completed, currentStage: stage, nextLevel: completed + 1
        )
        #expect(progress.stageCompletedCount == expected)
    }

    @Test("GameProgress.stageProgress ratio is correct")
    func stageProgressRatio() {
        let progress = WidgetDataProvider.GameProgress(
            completedCount: 50, currentStage: .iron, nextLevel: 51
        )
        #expect(abs(progress.stageProgress - 0.5) < 0.001)
    }

    @Test("progress() factory creates correct GameProgress")
    func progressFactory() {
        let snapshot = UserDefaultsSnapshot(keys: [GameManager.completionKey])
        defer { snapshot.restore() }

        UserDefaults.standard.set(25, forKey: GameManager.completionKey)

        let progress = WidgetDataProvider.progress()
        #expect(progress.completedCount == 25)
        #expect(progress.nextLevel == 26)
        #expect(progress.currentStage == .iron)
    }
}
