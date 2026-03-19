import Foundation
import Testing

@testable import SortVision

@Suite("Level Loading Integration")
@MainActor
struct LevelLoadingIntegrationTests {

    // MARK: - Bundle JSON Files

    @Test("All JSON resource files exist in the app bundle",
          arguments: Stage.allCases)
    func jsonResourcesExist(stage: Stage) {
        let resourceName = stage.levelResourceName
        let url = Bundle.main.url(forResource: resourceName, withExtension: "json")
        #expect(url != nil, "\(resourceName).json should exist in app bundle")
    }

    @Test("All JSON files decode without errors",
          arguments: Stage.allCases)
    func jsonFilesDecodeSuccessfully(stage: Stage) throws {
        let resourceName = stage.levelResourceName
        let url = try #require(
            Bundle.main.url(forResource: resourceName, withExtension: "json")
        )
        let data = try Data(contentsOf: url)
        let group = try JSONDecoder().decode(LevelGroup.self, from: data)
        #expect(!group.levels.isEmpty, "\(stage.displayName) should have at least one level")
    }

    // MARK: - Level Data Integrity

    @Test("Every level has at least one column",
          arguments: Stage.allCases)
    func everyLevelHasColumns(stage: Stage) {
        let levels = GameManager.shared.levels(for: stage)
        for level in levels {
            #expect(!level.columns.isEmpty,
                    "\(stage.displayName) level \(level.number) should have columns")
        }
    }

    @Test("Every level has at least one empty tube (needed for solvability)",
          arguments: Stage.allCases)
    func everyLevelHasEmptyTube(stage: Stage) {
        let levels = GameManager.shared.levels(for: stage)
        for level in levels {
            let hasEmpty = level.columns.contains { $0.values.isEmpty }
            #expect(hasEmpty,
                    "\(stage.displayName) level \(level.number) should have at least one empty tube")
        }
    }

    @Test("No level column exceeds max capacity of 4",
          arguments: Stage.allCases)
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
          arguments: Stage.allCases)
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
        for stage in Stage.allCases {
            let count = GameManager.shared.levels(for: stage).count
            #expect(count > 0, "\(stage.displayName) should have levels")
        }

        let total = Stage.allCases.reduce(0) { $0 + GameManager.shared.levels(for: $1).count }
        #expect(total >= 1000, "Total level count should be at least 1000 for a complete game")
    }

    // MARK: - Cross-Stage Data Consistency

    @Test("GameManager.level(globalNumber:) returns same data as levels(for:)[index]",
          arguments: Stage.allCases)
    func levelQueryConsistency(stage: Stage) {
        let levels = GameManager.shared.levels(for: stage)
        guard let firstLevel = levels.first else { return }

        let queried = GameManager.shared.level(globalNumber: firstLevel.number)
        #expect(queried?.number == firstLevel.number)
        #expect(queried?.columns.count == firstLevel.columns.count)
    }

    @Test("Global numbering is continuous across stages")
    func globalNumberingContinuous() {
        let stages = Stage.allCases
        for i in 0..<(stages.count - 1) {
            let currentLevels = GameManager.shared.levels(for: stages[i])
            let nextLevels = GameManager.shared.levels(for: stages[i + 1])

            guard let lastCurrent = currentLevels.last,
                  let firstNext = nextLevels.first
            else { continue }

            #expect(firstNext.number == lastCurrent.number + 1,
                    "\(stages[i + 1].displayName) should start right after \(stages[i].displayName) ends")
        }
    }
}
