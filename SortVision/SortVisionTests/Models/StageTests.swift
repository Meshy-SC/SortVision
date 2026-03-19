import Foundation
import Testing

@testable import SortVision

@Suite("Stage Enum")
struct StageTests {

    // MARK: - Display Names

    @Test("Each stage has a human-readable display name",
          arguments: zip(
            Stage.allCases,
            ["Iron", "Bronze", "Silver", "Gold", "Platinum", "Emerald", "Diamond", "Master", "Grandmaster", "Legend"]
          ))
    func displayNames(stage: Stage, expectedName: String) {
        #expect(stage.displayName == expectedName)
    }

    // MARK: - Level Ranges

    @Test("Level ranges are correct and non-overlapping")
    func levelRanges() {
        var allNumbers: Set<Int> = []
        for stage in Stage.allCases {
            let range = stage.levelRange
            #expect(range.count == Stage.levelsPerStage,
                    "\(stage.displayName) range should contain \(Stage.levelsPerStage) levels")
            for n in range {
                #expect(!allNumbers.contains(n), "Level \(n) overlaps between stages")
                allNumbers.insert(n)
            }
        }
        #expect(allNumbers.count == Stage.allCases.count * Stage.levelsPerStage)
    }

    @Test("Iron starts at 1, Legend ends at 1000")
    func rangeEndpoints() {
        #expect(Stage.iron.levelRange.lowerBound == 1)
        #expect(Stage.iron.levelRange.upperBound == 100)
        #expect(Stage.legend.levelRange.lowerBound == 901)
        #expect(Stage.legend.levelRange.upperBound == 1000)
    }

    // MARK: - Resource Mapping

    @Test("All stages have level resource names",
          arguments: Stage.allCases)
    func levelResources(stage: Stage) {
        #expect(!stage.levelResourceName.isEmpty)
    }

    @Test("All stages are available",
          arguments: Stage.allCases)
    func isAvailable(stage: Stage) {
        #expect(stage.isAvailable)
    }

    // MARK: - Stage Lookup

    @Test("stage(for:) returns correct stage for global level numbers",
          arguments: [
            (1, Stage.iron),
            (100, .iron),
            (101, .bronze),
            (200, .bronze),
            (201, .silver),
            (300, .silver),
            (301, .gold),
            (400, .gold),
            (401, .platinum),
            (500, .platinum),
            (901, .legend),
            (1000, .legend),
          ] as [(Int, Stage)])
    func stageForGlobalNumber(globalNumber: Int, expectedStage: Stage) {
        #expect(Stage.stage(for: globalNumber) == expectedStage)
    }

    @Test("stage(for:) returns nil for invalid numbers")
    func stageForInvalidNumber() {
        #expect(Stage.stage(for: 0) == nil)
        #expect(Stage.stage(for: -1) == nil)
        #expect(Stage.stage(for: 1001) == nil)
    }

    // MARK: - Local Level Number

    @Test("localLevelNumber converts global to local correctly",
          arguments: [
            (1, 1),
            (100, 100),
            (101, 1),
            (150, 50),
            (200, 100),
            (301, 1),
            (1000, 100),
          ] as [(Int, Int)])
    func localLevelNumber(global: Int, expectedLocal: Int) {
        #expect(Stage.localLevelNumber(for: global) == expectedLocal)
    }

    // MARK: - Raw Value & Identifiable

    @Test("Raw values are sequential starting from 0")
    func rawValuesSequential() {
        for (index, stage) in Stage.allCases.enumerated() {
            #expect(stage.rawValue == index)
        }
    }

    @Test("Identifiable id equals rawValue",
          arguments: Stage.allCases)
    func identifiableId(stage: Stage) {
        #expect(stage.id == stage.rawValue)
    }

    // MARK: - CaseIterable

    @Test("All ten stages are iterable")
    func allCasesCount() {
        #expect(Stage.allCases.count == 10)
    }

    // MARK: - Codable

    @Test("Stage Codable round-trip preserves value",
          arguments: Stage.allCases)
    func codableRoundTrip(stage: Stage) throws {
        let encoded = try JSONEncoder().encode(stage)
        let decoded = try JSONDecoder().decode(Stage.self, from: encoded)
        #expect(decoded == stage)
    }

    @Test("Stage decodes from raw integer values",
          arguments: [(0, Stage.iron), (1, .bronze), (9, .legend)])
    func decodesFromRawValue(rawValue: Int, expected: Stage) throws {
        let data = Data("\(rawValue)".utf8)
        let decoded = try JSONDecoder().decode(Stage.self, from: data)
        #expect(decoded == expected)
    }

    @Test("Stage init from invalid rawValue returns nil")
    func invalidRawValue() {
        #expect(Stage(rawValue: -1) == nil)
        #expect(Stage(rawValue: 10) == nil)
        #expect(Stage(rawValue: 100) == nil)
    }

}
