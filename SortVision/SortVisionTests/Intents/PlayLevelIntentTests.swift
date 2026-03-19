import Foundation
import Testing

@testable import SortVision

@Suite("PlayLevelIntent & App Intents")
struct PlayLevelIntentTests {

    // MARK: - StageAppEnum Conversion

    @Test("StageAppEnum converts to Stage correctly",
          arguments: [
            (StageAppEnum.iron, Stage.iron),
            (.bronze, .bronze),
            (.silver, .silver),
            (.gold, .gold),
            (.platinum, .platinum),
            (.diamond, .diamond),
            (.emerald, .emerald),
            (.master, .master),
            (.grandmaster, .grandmaster),
            (.legend, .legend),
          ])
    func appEnumToStage(appEnum: StageAppEnum, expected: Stage) {
        #expect(appEnum.stage == expected)
    }

    @Test("StageAppEnum round-trips from Stage",
          arguments: Stage.allCases)
    func stageRoundTrip(stage: Stage) {
        let appEnum = StageAppEnum(from: stage)
        #expect(appEnum.stage == stage)
    }

    @Test("All Stage cases have corresponding AppEnum cases")
    func allStagesHaveAppEnumRepresentation() {
        for stage in Stage.allCases {
            let appEnum = StageAppEnum(from: stage)
            #expect(appEnum.stage == stage)
        }
    }

    // MARK: - PlayLevelError

    @Test("PlayLevelError.levelNotFound includes level number and stage")
    func levelNotFoundError() {
        let error = PlayLevelError.levelNotFound(42, "Gold")
        let description = String(localized: error.localizedStringResource)
        #expect(description.contains("42"))
        #expect(description.contains("Gold"))
    }

    @Test("PlayLevelError.levelLocked includes level number and stage")
    func levelLockedError() {
        let error = PlayLevelError.levelLocked(10, "Silver")
        let description = String(localized: error.localizedStringResource)
        #expect(description.contains("10"))
        #expect(description.contains("Silver"))
    }

    // MARK: - ContinuePlayingError

    @Test("ContinuePlayingError.allCompleted has a message")
    func allCompletedError() {
        let error = ContinuePlayingError.allCompleted
        let description = String(localized: error.localizedStringResource)
        #expect(!description.isEmpty)
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

    // MARK: - StageAppEnum Display Representations

    @Test("StageAppEnum has display representations for all cases")
    func allCasesHaveDisplayRepresentations() {
        let representations = StageAppEnum.caseDisplayRepresentations
        #expect(representations.count == 10)
        #expect(representations[.iron] != nil)
        #expect(representations[.bronze] != nil)
        #expect(representations[.silver] != nil)
        #expect(representations[.gold] != nil)
        #expect(representations[.platinum] != nil)
        #expect(representations[.diamond] != nil)
        #expect(representations[.emerald] != nil)
        #expect(representations[.master] != nil)
        #expect(representations[.grandmaster] != nil)
        #expect(representations[.legend] != nil)
    }
}
