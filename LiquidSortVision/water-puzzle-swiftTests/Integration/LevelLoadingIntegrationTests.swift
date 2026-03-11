import Foundation
import Testing

@testable import water_puzzle_swift

@Suite("Level Loading Integration")
@MainActor
struct LevelLoadingIntegrationTests {

    // MARK: - Bundle JSON Files

    @Test("All JSON resource files exist in the app bundle",
          arguments: GameMode.allCases)
    func jsonResourcesExist(mode: GameMode) {
        let url = Bundle.main.url(forResource: mode.levelResourceName, withExtension: "json")
        #expect(url != nil, "\(mode.levelResourceName).json should exist in app bundle")
    }

    @Test("All JSON files decode without errors",
          arguments: GameMode.allCases)
    func jsonFilesDecodeSuccessfully(mode: GameMode) throws {
        let url = try #require(
            Bundle.main.url(forResource: mode.levelResourceName, withExtension: "json")
        )
        let data = try Data(contentsOf: url)
        let group = try JSONDecoder().decode(LevelGroup.self, from: data)
        #expect(!group.levels.isEmpty, "\(mode.displayName) should have at least one level")
    }

    // MARK: - Level Data Integrity

    @Test("Every level has at least one column",
          arguments: GameMode.allCases)
    func everyLevelHasColumns(mode: GameMode) {
        let levels = GameManager.shared.levels(for: mode)
        for level in levels {
            #expect(!level.columns.isEmpty,
                    "\(mode.displayName) level \(level.number) should have columns")
        }
    }

    @Test("Every level has at least one empty tube (needed for solvability)",
          arguments: GameMode.allCases)
    func everyLevelHasEmptyTube(mode: GameMode) {
        let levels = GameManager.shared.levels(for: mode)
        for level in levels {
            let hasEmpty = level.columns.contains { $0.values.isEmpty }
            #expect(hasEmpty,
                    "\(mode.displayName) level \(level.number) should have at least one empty tube")
        }
    }

    @Test("No level column exceeds max capacity of 4",
          arguments: GameMode.allCases)
    func columnsDoNotExceedCapacity(mode: GameMode) {
        let levels = GameManager.shared.levels(for: mode)
        for level in levels {
            for (colIdx, column) in level.columns.enumerated() {
                #expect(column.values.count <= TubeState.maxValue,
                        "\(mode.displayName) level \(level.number) column \(colIdx) exceeds max capacity")
            }
        }
    }

    @Test("All color groupIds in levels are valid palette indices",
          arguments: GameMode.allCases)
    func allGroupIdsAreValid(mode: GameMode) {
        let levels = GameManager.shared.levels(for: mode)
        let validRange = 0..<ColorPalette.colors.count

        for level in levels {
            for (colIdx, column) in level.columns.enumerated() {
                for value in column.values {
                    #expect(validRange.contains(value),
                            "\(mode.displayName) level \(level.number) column \(colIdx) has invalid groupId \(value)")
                }
            }
        }
    }

    // MARK: - Level Count Expectations

    @Test("Expected level counts per difficulty")
    func expectedLevelCounts() {
        // These counts should match the known level file contents
        let easyCnt = GameManager.shared.levels(for: .easy).count
        let normalCnt = GameManager.shared.levels(for: .normal).count
        let hardCnt = GameManager.shared.levels(for: .hard).count
        let expertCnt = GameManager.shared.levels(for: .expert).count

        #expect(easyCnt > 0, "Easy should have levels")
        #expect(normalCnt > 0, "Normal should have levels")
        #expect(hardCnt > 0, "Hard should have levels")
        #expect(expertCnt > 0, "Expert should have levels")

        // Total levels should be substantial for a puzzle game
        let total = easyCnt + normalCnt + hardCnt + expertCnt
        #expect(total >= 100, "Total level count should be at least 100 for a complete game")
    }

    // MARK: - Cross-Mode Data Consistency

    @Test("GameManager.level(for:number:) returns same data as levels(for:)[index]",
          arguments: GameMode.allCases)
    func levelQueryConsistency(mode: GameMode) {
        let levels = GameManager.shared.levels(for: mode)
        guard let firstLevel = levels.first else { return }

        let queried = GameManager.shared.level(for: mode, number: firstLevel.number)
        #expect(queried?.number == firstLevel.number)
        #expect(queried?.columns.count == firstLevel.columns.count)
    }
}
