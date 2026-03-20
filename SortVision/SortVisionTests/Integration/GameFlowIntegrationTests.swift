import CoreGraphics
import Foundation
import Testing

@testable import SortVision

// MARK: - Game Flow Integration Tests

@Suite("Game Flow Integration")
@MainActor
struct GameFlowIntegrationTests {

    // MARK: - Helpers

    private func makeEngine(level: Level) -> (GameEngine, MockSoundPlayer) {
        let engine = GameEngine()
        let mockSound = MockSoundPlayer()
        engine.soundPlayer = mockSound
        engine.level = level
        engine.setup()
        return (engine, mockSound)
    }

    // MARK: - Level → Engine → State Flow

    @Test("Level data flows correctly to GameEngine tube states")
    func levelToEngineFlow() {
        let level = TestFixtures.level(columns: [
            [1, 1, 1, 1],
            [2, 2, 2, 2],
            [],
        ])
        let (engine, _) = makeEngine(level: level)

        // Verify tube 0 has one color
        #expect(engine.tubes[0].liquids.count == 1)
        #expect(engine.tubes[0].liquids[0].groupId == 1)
        #expect(engine.tubes[0].liquids[0].volume == 4.0)
        #expect(engine.tubes[0].isFull)

        // Verify tube 1 has one color
        #expect(engine.tubes[1].liquids.count == 1)
        #expect(engine.tubes[1].liquids[0].groupId == 2)

        // Verify tube 2 is empty
        #expect(engine.tubes[2].isEmpty)
    }

    @Test("Selecting and deselecting produces correct sound sequence")
    func selectDeselectSoundSequence() {
        let level = TestFixtures.simpleLevel()
        let (engine, mockSound) = makeEngine(level: level)

        engine.handleTubeTap(engine.tubes[0]) // Select → pop
        engine.handleTubeTap(engine.tubes[0]) // Deselect → push

        #expect(mockSound.playedSounds == [.pop, .push])
    }

    @Test("Restart preserves level configuration")
    func restartPreservesLevel() {
        let level = TestFixtures.simpleLevel(number: 42)
        let (engine, _) = makeEngine(level: level)

        let originalTubeCount = engine.tubes.count
        engine.restart()

        #expect(engine.tubes.count == originalTubeCount)
        #expect(engine.level?.number == 42)
    }

    // MARK: - Level Completion → GameManager Flow

    @Test("GameManager.completeLevel updates progress and persists")
    func completionUpdatesAndPersists() {
        let snapshot = UserDefaultsSnapshot(keys: UserDefaultsSnapshot.gameManagerKeys + [
            ProgressStore.bestMovesKey, ProgressStore.starRatingsKey
        ])
        defer { snapshot.restore() }

        UserDefaults.standard.set(0, forKey: GameManager.completionKey)
        GameManager.shared.loadCompletedLevel()

        GameManager.shared.completeLevel(number: 5, moves: 10)

        #expect(GameManager.shared.completedLevel == 5)
        #expect(GameManager.shared.bestMoveCount(for: 5) == 10)
        #expect(GameManager.shared.starRating(for: 5) >= 1)

        // Verify persistence
        let persisted = UserDefaults.standard.integer(forKey: GameManager.completionKey)
        #expect(persisted == 5)
    }

    // MARK: - Stage Progression Integration

    @Test("Completing all Iron levels unlocks Bronze")
    func completingIronUnlocksBronze() {
        let snapshot = UserDefaultsSnapshot(keys: UserDefaultsSnapshot.gameManagerKeys)
        defer { snapshot.restore() }

        GameManager.shared.completeLevel(number: 100, moves: 5)

        #expect(GameManager.shared.isStageAccessible(.bronze))
        #expect(!GameManager.shared.isLevelLocked(101))
    }

    @Test("Stage accessibility chain is monotonic")
    func stageAccessibilityChain() {
        let snapshot = UserDefaultsSnapshot(keys: UserDefaultsSnapshot.gameManagerKeys)
        defer { snapshot.restore() }

        GameManager.shared.completeLevel(number: 250, moves: 5)

        // Iron, Bronze, Silver should be accessible
        #expect(GameManager.shared.isStageAccessible(.iron))
        #expect(GameManager.shared.isStageAccessible(.bronze))
        #expect(GameManager.shared.isStageAccessible(.silver))

        // Gold should not be accessible (need 300 to unlock)
        #expect(!GameManager.shared.isStageAccessible(.gold))
    }

    // MARK: - Level Query Consistency

    @Test("level(globalNumber:) matches levels(for:) at boundary transitions")
    func levelQueryBoundaryConsistency() {
        // Iron level 100
        let iron100 = GameManager.shared.level(globalNumber: 100)
        let ironLevels = GameManager.shared.levels(for: .iron)
        #expect(iron100?.number == ironLevels.last?.number)

        // Bronze level 101
        let bronze101 = GameManager.shared.level(globalNumber: 101)
        let bronzeLevels = GameManager.shared.levels(for: .bronze)
        #expect(bronze101?.number == bronzeLevels.first?.number)
    }
}

// MARK: - Data Integrity Integration Tests

@Suite("Data Integrity Integration")
@MainActor
struct DataIntegrityIntegrationTests {

    @Test("WorldData JSON files exist for all stages",
          arguments: Stage.allCases)
    func worldDataJsonExists(stage: Stage) {
        let url = Bundle.main.url(
            forResource: stage.worldDataResourceName,
            withExtension: "json"
        )
        #expect(url != nil, "\(stage.worldDataResourceName).json should exist")
    }

    @Test("WorldData has optimal counts matching level count",
          arguments: Stage.allCases)
    func worldDataCountsMatchLevels(stage: Stage) throws {
        guard let url = Bundle.main.url(
            forResource: stage.worldDataResourceName,
            withExtension: "json"
        ) else { return }

        let data = try Data(contentsOf: url)
        let worldData = try JSONDecoder().decode(WorldData.self, from: data)
        let levels = GameManager.shared.levels(for: stage)

        #expect(worldData.optimalMoveCounts.count == levels.count,
                "\(stage.displayName): WorldData count (\(worldData.optimalMoveCounts.count)) should match level count (\(levels.count))")
    }

    @Test("All optimal move counts are positive",
          arguments: Stage.allCases)
    func optimalMoveCountsPositive(stage: Stage) throws {
        guard let url = Bundle.main.url(
            forResource: stage.worldDataResourceName,
            withExtension: "json"
        ) else { return }

        let data = try Data(contentsOf: url)
        let worldData = try JSONDecoder().decode(WorldData.self, from: data)

        for (index, count) in worldData.optimalMoveCounts.enumerated() {
            #expect(count > 0,
                    "\(stage.displayName) level \(index + 1) optimal count should be positive, got \(count)")
        }
    }

    @Test("Every level has balanced colors (total of each color is a multiple of maxValue)",
          arguments: Stage.allCases)
    func levelColorBalance(stage: Stage) {
        let levels = GameManager.shared.levels(for: stage)
        for level in levels {
            var colorCounts: [Int: Int] = [:]
            for column in level.columns {
                for colorId in column.colorGroupIds {
                    colorCounts[colorId, default: 0] += 1
                }
            }
            for (colorId, count) in colorCounts {
                #expect(count % TubeState.maxValue == 0,
                        "\(stage.displayName) level \(level.number): color \(colorId) has \(count) units, not a multiple of \(TubeState.maxValue)")
            }
        }
    }
}
