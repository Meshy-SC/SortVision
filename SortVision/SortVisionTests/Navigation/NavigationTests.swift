import Foundation
import Testing

@testable import SortVision

// MARK: - Navigation Tests

@Suite("AppScreen")
struct AppScreenTests {

    @Test("AppScreen.levelGrid Hashable conformance")
    func levelGridHashable() {
        let a = AppScreen.levelGrid(.iron)
        let b = AppScreen.levelGrid(.iron)
        let c = AppScreen.levelGrid(.bronze)

        #expect(a == b)
        #expect(a != c)
    }

    @Test("AppScreen.gameplay Hashable conformance")
    func gameplayHashable() {
        let level1 = TestFixtures.simpleLevel(number: 1)
        let level2 = TestFixtures.simpleLevel(number: 2)

        let a = AppScreen.gameplay(.iron, level1)
        let b = AppScreen.gameplay(.iron, level1)
        let c = AppScreen.gameplay(.iron, level2)
        let d = AppScreen.gameplay(.bronze, level1)

        #expect(a == b)
        #expect(a != c)
        #expect(a != d)
    }

    @Test("AppScreen cases can be stored in a Set")
    func appScreenSetStorage() {
        let level = TestFixtures.simpleLevel(number: 1)
        let screens: Set<AppScreen> = [
            .levelGrid(.iron),
            .levelGrid(.bronze),
            .gameplay(.iron, level),
        ]
        #expect(screens.count == 3)
    }
}

// MARK: - Stage Display Properties

@Suite("Stage Display Properties")
struct StageDisplayPropertiesTests {

    @Test("Every stage has a subtitle",
          arguments: Stage.allCases)
    func subtitles(stage: Stage) {
        #expect(!stage.subtitle.isEmpty)
    }

    @Test("Every stage has an SF Symbol icon",
          arguments: Stage.allCases)
    func iconNames(stage: Stage) {
        #expect(!stage.iconName.isEmpty)
    }

    @Test("worldNumber is rawValue + 1",
          arguments: Stage.allCases)
    func worldNumber(stage: Stage) {
        #expect(stage.worldNumber == stage.rawValue + 1)
    }

    @Test("Resource names follow 'World{N}' pattern",
          arguments: Stage.allCases)
    func resourceNamePattern(stage: Stage) {
        #expect(stage.levelResourceName == "World\(stage.worldNumber)")
        #expect(stage.worldDataResourceName == "World\(stage.worldNumber)Data")
    }
}

// MARK: - WidgetDataProvider Extended Tests

@Suite("WidgetDataProvider GameProgress Edge Cases")
struct WidgetDataProviderEdgeCaseTests {

    @Test("GameProgress.stageProgress is 0.0 when no levels completed in stage")
    func stageProgressZero() {
        let progress = WidgetDataProvider.GameProgress(
            completedCount: 0, currentStage: .iron, nextLevel: 1
        )
        #expect(progress.stageProgress == 0.0)
    }

    @Test("GameProgress.stageProgress is 1.0 when stage fully completed")
    func stageProgressFull() {
        let progress = WidgetDataProvider.GameProgress(
            completedCount: 100, currentStage: .iron, nextLevel: 101
        )
        #expect(progress.stageProgress == 1.0)
    }

    @Test("GameProgress.isAllComplete is false for partial completion")
    func isAllCompletePartial() {
        let progress = WidgetDataProvider.GameProgress(
            completedCount: 500, currentStage: .emerald, nextLevel: 501
        )
        #expect(!progress.isAllComplete)
    }

    @Test("GameProgress.isAllComplete checks all 10 stages × 100 levels = 1000")
    func isAllCompleteTotal() {
        let progress = WidgetDataProvider.GameProgress(
            completedCount: 1000, currentStage: .legend, nextLevel: 1001
        )
        #expect(progress.isAllComplete)
    }

    @Test("GameProgress.stageCompletedCount clamps to levelsPerStage")
    func stageCompletedCountClamped() {
        // If completedCount extends beyond the current stage
        let progress = WidgetDataProvider.GameProgress(
            completedCount: 200, currentStage: .iron, nextLevel: 201
        )
        #expect(progress.stageCompletedCount == 100)
    }

    @Test("GameProgress.stageCompletedCount handles 0 completed")
    func stageCompletedCountZero() {
        let progress = WidgetDataProvider.GameProgress(
            completedCount: 0, currentStage: .iron, nextLevel: 1
        )
        #expect(progress.stageCompletedCount == 0)
    }
}

// MARK: - PlatformInfo Tests

@Suite("PlatformInfo")
struct PlatformInfoTests {

    @Test("platformName returns a non-empty string")
    func platformNameNotEmpty() {
        #expect(!PlatformInfo.platformName.isEmpty)
    }

    @Test("systemName returns a non-empty string")
    func systemNameNotEmpty() {
        #expect(!PlatformInfo.systemName.isEmpty)
    }

    @Test("systemVersion is a version-like string")
    func systemVersionFormat() {
        let version = PlatformInfo.systemVersion
        #expect(!version.isEmpty)
        // Should contain at least one dot (e.g., "26.0" or "26.0.1")
        #expect(version.contains("."))
    }

    @Test("deviceModel returns a non-empty string")
    func deviceModelNotEmpty() {
        #expect(!PlatformInfo.deviceModel.isEmpty)
    }

    @Test("appVersion is non-empty")
    func appVersionNotEmpty() {
        #expect(!PlatformInfo.appVersion.isEmpty)
    }

    @Test("buildNumber is non-empty")
    func buildNumberNotEmpty() {
        #expect(!PlatformInfo.buildNumber.isEmpty)
    }

    @Test("versionDisplay contains both version and build number")
    func versionDisplayFormat() {
        let display = PlatformInfo.versionDisplay
        #expect(display.contains(PlatformInfo.appVersion))
        #expect(display.contains(PlatformInfo.buildNumber))
        #expect(display.contains("("))
        #expect(display.contains(")"))
    }
}
