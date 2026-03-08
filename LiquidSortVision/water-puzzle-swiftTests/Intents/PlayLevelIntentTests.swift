import Foundation
import Testing

@testable import water_puzzle_swift

@Suite("PlayLevelIntent & App Intents")
struct PlayLevelIntentTests {

    // MARK: - GameModeAppEnum Conversion

    @Test("GameModeAppEnum converts to GameMode correctly",
          arguments: [
            (GameModeAppEnum.easy, GameMode.easy),
            (.normal, .normal),
            (.hard, .hard),
            (.expert, .expert),
          ])
    func appEnumToGameMode(appEnum: GameModeAppEnum, expected: GameMode) {
        #expect(appEnum.gameMode == expected)
    }

    @Test("GameModeAppEnum round-trips from GameMode",
          arguments: GameMode.allCases)
    func gameModeRoundTrip(mode: GameMode) {
        let appEnum = GameModeAppEnum(from: mode)
        #expect(appEnum.gameMode == mode)
    }

    @Test("All GameMode cases have corresponding AppEnum cases")
    func allModesHaveAppEnumRepresentation() {
        for mode in GameMode.allCases {
            let appEnum = GameModeAppEnum(from: mode)
            #expect(appEnum.gameMode == mode)
        }
    }

    // MARK: - PlayLevelError

    @Test("PlayLevelError.levelNotFound includes level number and difficulty")
    func levelNotFoundError() {
        let error = PlayLevelError.levelNotFound(42, "Expert")
        let description = String(localized: error.localizedStringResource)
        #expect(description.contains("42"))
        #expect(description.contains("Expert"))
    }

    @Test("PlayLevelError.levelLocked includes level number and difficulty")
    func levelLockedError() {
        let error = PlayLevelError.levelLocked(10, "Hard")
        let description = String(localized: error.localizedStringResource)
        #expect(description.contains("10"))
        #expect(description.contains("Hard"))
    }

    // MARK: - ContinuePlayingError

    @Test("ContinuePlayingError.allCompleted includes difficulty name")
    func allCompletedError() {
        let error = ContinuePlayingError.allCompleted("Easy")
        let description = String(localized: error.localizedStringResource)
        #expect(description.contains("Easy"))
    }

    // MARK: - Intent Metadata

    @Test("PlayLevelIntent has required static properties")
    func playLevelIntentMetadata() {
        #expect(PlayLevelIntent.openAppWhenRun == true)
    }

    @Test("ContinuePlayingIntent has required static properties")
    func continuePlayingIntentMetadata() {
        #expect(ContinuePlayingIntent.openAppWhenRun == true)
    }

    // MARK: - GameModeAppEnum Display Representations

    @Test("GameModeAppEnum has display representations for all cases")
    func allCasesHaveDisplayRepresentations() {
        let representations = GameModeAppEnum.caseDisplayRepresentations
        #expect(representations.count == 4)
        #expect(representations[.easy] != nil)
        #expect(representations[.normal] != nil)
        #expect(representations[.hard] != nil)
        #expect(representations[.expert] != nil)
    }
}
