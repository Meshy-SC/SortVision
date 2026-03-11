import Foundation
import Testing

@testable import water_puzzle_swift

@Suite("Level Loading Integration")
@MainActor
struct LevelLoadingIntegrationTests {

    /// Stages that have level content shipped in the bundle.
    private static let availableStages: [Stage] = [.iron, .bronze, .silver, .gold]

    // MARK: - Bundle JSON Files

    @Test("All JSON resource files exist in the app bundle",
          arguments: availableStages)
    func jsonResourcesExist(stage: Stage) {
        guard let resourceName = stage.levelResourceName else { return }
        let url = Bundle.main.url(forResource: resourceName, withExtension: "json")
        #expect(url != nil, "\(resourceName).json should exist in app bundle")
    }

    @Test("All JSON files decode without errors",
          arguments: availableStages)
    func jsonFilesDecodeSuccessfully(stage: Stage) throws {
        guard let resourceName = stage.levelResourceName else { return }
        let url = try #require(
            Bundle.main.url(forResource: resourceName, withExtension: "json")
        )
        let data = try Data(contentsOf: url)
        let group = try JSONDecoder().decode(LevelGroup.self, from: data)
        #expect(!group.levels.isEmpty, "\(stage.displayName) should have at least one level")
    }

    // MARK: - Level Data Integrity

    @Test("Every level has at least one column",
          arguments: availableStages)
    func everyLevelHasColumns(stage: Stage) {
        let levels = GameManager.shared.levels(for: stage)
        for level in levels {
            #expect(!level.columns.isEmpty,
                    "\(stage.displayName) level \(level.number) should have columns")
        }
    }

    @Test("Every level has at least one empty tube (needed for solvability)",
          arguments: availableStages)
    func everyLevelHasEmptyTube(stage: Stage) {
        let levels = GameManager.shared.levels(for: stage)
        for level in levels {
            let hasEmpty = level.columns.contains { $0.values.isEmpty }
            #expect(hasEmpty,
                    "\(stage.displayName) level \(level.number) should have at least one empty tube")
        }
    }

    @Test("No level column exceeds max capacity of 4",
          arguments: availableStages)
    func columnsDoNotExceedCapacity(stage: Stage) {
        let levels = GameManager.shared.levels(for: stage)
        for level in levels {
            for (colIdx, column) in level.columns.enumerated() {
                #expect(column.values.count <= TubeState.maxValue,
                        "\(stage.displayName) level \(level.number) column \(colIdx) exceeds max capacity")
            }
        }
    }

    @Test("All color groupIds in levels are valid palette indices",
          arguments: availableStages)
    func allGroupIdsAreValid(stage: Stage) {
        let levels = GameManager.shared.levels(for: stage)
        let validRange = 0..<ColorPalette.colors.count

        for level in levels {
            for (colIdx, column) in level.columns.enumerated() {
                for value in column.values {
                    #expect(validRange.contains(value),
                            "\(stage.displayName) level \(level.number) column \(colIdx) has invalid groupId \(value)")
                }
            }
        }
    }

    // MARK: - Level Count Expectations

    @Test("Expected level counts per stage")
    func expectedLevelCounts() {
        let ironCount = GameManager.shared.levels(for: .iron).count
        let bronzeCount = GameManager.shared.levels(for: .bronze).count
        let silverCount = GameManager.shared.levels(for: .silver).count
        let goldCount = GameManager.shared.levels(for: .gold).count

        #expect(ironCount > 0, "Iron should have levels")
        #expect(bronzeCount > 0, "Bronze should have levels")
        #expect(silverCount > 0, "Silver should have levels")
        #expect(goldCount > 0, "Gold should have levels")

        let total = ironCount + bronzeCount + silverCount + goldCount
        #expect(total >= 100, "Total level count should be at least 100 for a complete game")
    }

    // MARK: - Cross-Stage Data Consistency

    @Test("GameManager.level(globalNumber:) returns same data as levels(for:)[index]",
          arguments: availableStages)
    func levelQueryConsistency(stage: Stage) {
        let levels = GameManager.shared.levels(for: stage)
        guard let firstLevel = levels.first else { return }

        let queried = GameManager.shared.level(globalNumber: firstLevel.number)
        #expect(queried?.number == firstLevel.number)
        #expect(queried?.columns.count == firstLevel.columns.count)
    }

    @Test("Global numbering is continuous across stages")
    func globalNumberingContinuous() {
        let ironLevels = GameManager.shared.levels(for: .iron)
        let bronzeLevels = GameManager.shared.levels(for: .bronze)

        guard let lastIron = ironLevels.last,
              let firstBronze = bronzeLevels.first
        else { return }

        #expect(firstBronze.number == lastIron.number + 1,
                "Bronze should start right after Iron ends")
    }
}
