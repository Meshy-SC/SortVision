import Foundation
import Testing

@testable import water_puzzle_swift

@Suite("GameMode Enum")
struct GameModeTests {

    // MARK: - Display Names

    @Test("Each game mode has a human-readable display name",
          arguments: zip(
            GameMode.allCases,
            ["Easy", "Normal", "Hard", "Expert"]
          ))
    func displayNames(mode: GameMode, expectedName: String) {
        #expect(mode.displayName == expectedName)
    }

    // MARK: - Resource Names

    @Test("Each game mode maps to correct JSON resource filename",
          arguments: zip(
            GameMode.allCases,
            ["levels", "levels-normal", "levels-hard", "levels-ex"]
          ))
    func levelResourceNames(mode: GameMode, expectedResource: String) {
        #expect(mode.levelResourceName == expectedResource)
    }

    // MARK: - Completion Keys

    @Test("Each game mode has a unique completion key")
    func completionKeysAreUnique() {
        let keys = GameMode.allCases.map(\.completionKey)
        let uniqueKeys = Set(keys)
        #expect(keys.count == uniqueKeys.count, "Completion keys must be unique across modes")
    }

    @Test("Completion keys contain mode name for debuggability",
          arguments: GameMode.allCases)
    func completionKeyContainsModeName(mode: GameMode) {
        let key = mode.completionKey
        #expect(key.contains("Level_Complete"))
    }

    // MARK: - Raw Value & Identifiable

    @Test("Raw values are sequential starting from 0")
    func rawValuesSequential() {
        #expect(GameMode.easy.rawValue == 0)
        #expect(GameMode.normal.rawValue == 1)
        #expect(GameMode.hard.rawValue == 2)
        #expect(GameMode.expert.rawValue == 3)
    }

    @Test("Identifiable id equals rawValue",
          arguments: GameMode.allCases)
    func identifiableId(mode: GameMode) {
        #expect(mode.id == mode.rawValue)
    }

    // MARK: - CaseIterable

    @Test("All four game modes are iterable")
    func allCasesCount() {
        #expect(GameMode.allCases.count == 4)
    }

    // MARK: - Codable

    @Test("GameMode Codable round-trip preserves value",
          arguments: GameMode.allCases)
    func codableRoundTrip(mode: GameMode) throws {
        let encoded = try JSONEncoder().encode(mode)
        let decoded = try JSONDecoder().decode(GameMode.self, from: encoded)
        #expect(decoded == mode)
    }

    @Test("GameMode decodes from raw integer values",
          arguments: [(0, GameMode.easy), (1, .normal), (2, .hard), (3, .expert)])
    func decodesFromRawValue(rawValue: Int, expected: GameMode) throws {
        let data = Data("\(rawValue)".utf8)
        let decoded = try JSONDecoder().decode(GameMode.self, from: data)
        #expect(decoded == expected)
    }

    @Test("GameMode init from invalid rawValue returns nil")
    func invalidRawValue() {
        #expect(GameMode(rawValue: -1) == nil)
        #expect(GameMode(rawValue: 4) == nil)
        #expect(GameMode(rawValue: 100) == nil)
    }
}
