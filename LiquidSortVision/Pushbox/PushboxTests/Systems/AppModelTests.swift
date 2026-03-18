// AppModelTests.swift
// Tests for the AppModel central coordinator.

import Testing
import Foundation
import SwiftData
@testable import Pushbox

@Suite("AppModel")
@MainActor
struct AppModelTests {

    // MARK: - Initialization

    @Test("ModelContext initializer creates all services")
    func initWithModelContext() {
        let appModel = TestHelpers.makeTestAppModel()
        // Verify all services are non-nil (they're non-optional lets, so this tests init doesn't crash)
        #expect(appModel.selectedWorld != nil)
        #expect(appModel.isControlPanelOpen == true)
    }

    @Test("DI initializer accepts injected services")
    func initWithDependencyInjection() {
        let container = TestHelpers.makeTestContainer()
        let context = container.mainContext
        let appModel = AppModel(
            inAppPurchaseService: InAppPurchaseService(modelContext: context),
            audioService: AudioService(),
            animationService: AnimationService(),
            progressService: ProgressService(modelContext: context),
            levelLoader: LevelLoader()
        )
        #expect(appModel.selectedWorld != nil)
    }

    @Test("Preview helper creates valid model")
    func previewHelper() {
        let appModel = AppModel.preview
        #expect(appModel.selectedWorld != nil)
    }

    // MARK: - Navigation

    @Test("canGoToPreviousLevel is false when no level selected")
    func canGoToPreviousNoSelection() {
        let appModel = TestHelpers.makeTestAppModel()
        appModel.selectedLevelIndex = nil
        #expect(!appModel.canGoToPreviousLevel)
    }

    @Test("canGoToPreviousLevel is false at first level")
    func canGoToPreviousAtFirst() {
        let appModel = TestHelpers.makeTestAppModel()
        appModel.selectedLevelIndex = 0
        #expect(!appModel.canGoToPreviousLevel)
    }

    @Test("canGoToPreviousLevel is true when not at first level")
    func canGoToPreviousAtMiddle() {
        let appModel = TestHelpers.makeTestAppModel()
        appModel.selectedLevelIndex = 2
        #expect(appModel.canGoToPreviousLevel)
    }

    @Test("canGoToNextLevel is false when no level selected")
    func canGoToNextNoSelection() {
        let appModel = TestHelpers.makeTestAppModel()
        appModel.selectedLevelIndex = nil
        #expect(!appModel.canGoToNextLevel)
    }

    @Test("canGoToNextLevel is false when no levels cached")
    func canGoToNextNoCache() {
        let appModel = TestHelpers.makeTestAppModel()
        appModel.selectedLevelIndex = 0
        // No levels loaded into cache
        #expect(!appModel.canGoToNextLevel)
    }

    @Test("canGoToNextLevel requires cached levels", .tags(.integration))
    func canGoToNextWithCache() async throws {
        let appModel = TestHelpers.makeTestAppModel()
        let world = World.allWorlds.first!
        appModel.selectedWorld = world
        _ = try await appModel.levelLoader.loadLevels(for: world.worldName)
        appModel.selectedLevelIndex = 0
        #expect(appModel.canGoToNextLevel)
    }

    @Test("canGoToNextLevel is false at last level", .tags(.integration))
    func canGoToNextAtLast() async throws {
        let appModel = TestHelpers.makeTestAppModel()
        let world = World.allWorlds.first!
        appModel.selectedWorld = world
        let levels = try await appModel.levelLoader.loadLevels(for: world.worldName)
        appModel.selectedLevelIndex = levels.count - 1
        #expect(!appModel.canGoToNextLevel)
    }

    // MARK: - Optimal Pushes

    @Test("optimalPushes delegates to progressService")
    func optimalPushesDelegation() {
        let appModel = TestHelpers.makeTestAppModel()
        let world = World.allWorlds.first!
        appModel.selectedWorld = world
        appModel.selectedLevelIndex = 0
        #expect(appModel.optimalPushes == world.optimalPushCounts[0])
    }

    @Test("optimalPushes is nil when no world or level selected")
    func optimalPushesNil() {
        let appModel = TestHelpers.makeTestAppModel()
        appModel.selectedWorld = nil
        appModel.selectedLevelIndex = nil
        #expect(appModel.optimalPushes == nil)
    }

    // MARK: - Solution Playback State

    @Test("Solution playback starts inactive")
    func solutionPlaybackInactive() {
        let appModel = TestHelpers.makeTestAppModel()
        #expect(!appModel.isPlayingSolution)
        #expect(!appModel.isSolutionPaused)
        #expect(!appModel.isStartingSolution)
        #expect(appModel.solutionMoves.isEmpty)
    }

    // MARK: - Layout Helpers

    @Test("Default layout values are set")
    func defaultLayoutValues() {
        let appModel = TestHelpers.makeTestAppModel()
        #expect(appModel.cellDisplaySize == 100)
        #expect(appModel.levelWidth == 1)
        #expect(appModel.levelDepth == 1)
    }

    // MARK: - World Total Levels

    @Test("worldTotalLevels returns same as World.totalLevelsPerWorld")
    func worldTotalLevels() {
        let appModel = TestHelpers.makeTestAppModel()
        #expect(appModel.worldTotalLevels == World.totalLevelsPerWorld)
    }
}
