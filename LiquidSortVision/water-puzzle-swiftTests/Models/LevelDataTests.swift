import Foundation
import Testing

@testable import water_puzzle_swift

// MARK: - Level Codable Tests

@Suite("Level Data Model")
struct LevelDataTests {

    // MARK: - Codable Round-Trip

    @Test("Level decodes from JSON with correct number and column count")
    func decodeLevelFromJSON() throws {
        let data = Data(TestFixtures.sampleLevelJSON.utf8)
        let level = try JSONDecoder().decode(Level.self, from: data)

        #expect(level.number == 42)
        #expect(level.columns.count == 3)
        #expect(level.id == 42)
    }

    @Test("Level encodes and decodes round-trip preserves data")
    func levelCodableRoundTrip() throws {
        let original = TestFixtures.simpleLevel(number: 7)
        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Level.self, from: encoded)

        #expect(decoded.number == original.number)
        #expect(decoded.columns.count == original.columns.count)
        for i in 0..<original.columns.count {
            #expect(decoded.columns[i].values == original.columns[i].values)
        }
    }

    @Test("LevelGroup decodes array of levels")
    func decodeLevelGroup() throws {
        let data = Data(TestFixtures.sampleLevelGroupJSON.utf8)
        let group = try JSONDecoder().decode(LevelGroup.self, from: data)

        #expect(group.levels.count == 2)
        #expect(group.levels[0].number == 1)
        #expect(group.levels[1].number == 2)
    }

    @Test("Level id equals number for Identifiable conformance")
    func levelIdentifiable() {
        let level = TestFixtures.simpleLevel(number: 99)
        #expect(level.id == level.number)
        #expect(level.id == 99)
    }

    // MARK: - Hashable

    @Test("Level Hashable: same data produces same hash")
    func levelHashableEquality() {
        let level1 = TestFixtures.simpleLevel(number: 5)
        let level2 = TestFixtures.simpleLevel(number: 5)

        #expect(level1 == level2)
        #expect(level1.hashValue == level2.hashValue)
    }

    @Test("Level Hashable: different levels produce different hashes")
    func levelHashableDifference() {
        let level1 = TestFixtures.simpleLevel(number: 1)
        let level2 = TestFixtures.simpleLevel(number: 2)

        #expect(level1 != level2)
    }

    // MARK: - Liquid Segment Compression

    @Test("Consecutive same values compress into single segment",
          arguments: [
            ([1, 1, 1, 1], [(1, 4.0)]),
            ([1, 1, 2, 2], [(1, 2.0), (2, 2.0)]),
            ([1, 2, 1, 2], [(1, 1.0), (2, 1.0), (1, 1.0), (2, 1.0)]),
          ] as [([Int], [(Int, CGFloat)])])
    func liquidSegmentCompression(input: [Int], expected: [(Int, CGFloat)]) {
        let column = LevelColumn(values: input)
        let segments = Level.liquidSegments(from: column)

        #expect(segments.count == expected.count)
        for (segment, exp) in zip(segments, expected) {
            #expect(segment.groupId == exp.0)
            #expect(segment.value == exp.1)
        }
    }

    @Test("Empty column produces empty segments")
    func emptyColumnProducesNoSegments() {
        let column = LevelColumn(values: [])
        let segments = Level.liquidSegments(from: column)

        #expect(segments.isEmpty)
    }

    @Test("Single value column produces single segment with value 1")
    func singleValueColumn() {
        let column = LevelColumn(values: [3])
        let segments = Level.liquidSegments(from: column)

        #expect(segments.count == 1)
        #expect(segments[0].groupId == 3)
        #expect(segments[0].value == 1.0)
    }

    @Test("compressedLiquidSegments maps all columns correctly")
    func compressedLiquidSegmentsAllColumns() {
        let level = TestFixtures.level(columns: [
            [1, 1, 2],
            [2, 2, 1],
            [],
        ])
        let compressed = level.compressedLiquidSegments

        #expect(compressed.count == 3)
        // First column: [1,1,2] → [(1,2), (2,1)]
        #expect(compressed[0].count == 2)
        #expect(compressed[0][0] == LiquidSegment(groupId: 1, value: 2.0))
        #expect(compressed[0][1] == LiquidSegment(groupId: 2, value: 1.0))
        // Second column: [2,2,1] → [(2,2), (1,1)]
        #expect(compressed[1].count == 2)
        // Third column: empty
        #expect(compressed[2].isEmpty)
    }

    // MARK: - LevelColumn

    @Test("LevelColumn Hashable conformance")
    func levelColumnHashable() {
        let col1 = LevelColumn(values: [1, 2, 3])
        let col2 = LevelColumn(values: [1, 2, 3])
        let col3 = LevelColumn(values: [3, 2, 1])

        #expect(col1 == col2)
        #expect(col1 != col3)
    }

    // MARK: - LiquidSegment

    @Test("LiquidSegment Equatable and Hashable")
    func liquidSegmentEquatable() {
        let seg1 = LiquidSegment(groupId: 1, value: 2.0)
        let seg2 = LiquidSegment(groupId: 1, value: 2.0)
        let seg3 = LiquidSegment(groupId: 2, value: 2.0)

        #expect(seg1 == seg2)
        #expect(seg1 != seg3)
    }

    // MARK: - Malformed JSON

    @Test("Decoding malformed JSON throws DecodingError")
    func decodingMalformedJSON() {
        let badJSON = Data("{\"no\": \"not_a_number\"}".utf8)
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(Level.self, from: badJSON)
        }
    }

    @Test("Decoding JSON missing required fields throws")
    func decodingMissingFields() {
        let incompleteJSON = Data("{\"no\": 1}".utf8)
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(Level.self, from: incompleteJSON)
        }
    }
}
