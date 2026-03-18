// LevelGridQueriesTests.swift
// Tests for LevelGridQueries static query methods.

import Testing
import Foundation
@testable import Pushbox

// MARK: - LevelGridQueries Tests

@MainActor
@Suite("LevelGridQueries Tests")
struct LevelGridQueriesTests {

    // MARK: - isLevelActive

    @Test("isLevelActive returns true when activeWorld and index match")
    func levelActiveMatch() {
        let appModel = TestHelpers.makeTestAppModel()
        let world = World.allWorlds.first!
        appModel.activeWorld = world
        appModel.selectedLevelIndex = 2

        let result = LevelGridQueries.isLevelActive(2, in: world, appModel: appModel)
        #expect(result == true)
    }

    @Test("isLevelActive returns false when world does not match")
    func levelActiveDifferentWorld() {
        let appModel = TestHelpers.makeTestAppModel()
        let world1 = World.allWorlds[0]
        let world2 = World.allWorlds.count > 1 ? World.allWorlds[1] : TestHelpers.makeTestWorld(worldName: "Other")
        appModel.activeWorld = world1
        appModel.selectedLevelIndex = 0

        let result = LevelGridQueries.isLevelActive(0, in: world2, appModel: appModel)
        #expect(result == false)
    }

    @Test("isLevelActive returns false when index does not match")
    func levelActiveDifferentIndex() {
        let appModel = TestHelpers.makeTestAppModel()
        let world = World.allWorlds.first!
        appModel.activeWorld = world
        appModel.selectedLevelIndex = 0

        let result = LevelGridQueries.isLevelActive(5, in: world, appModel: appModel)
        #expect(result == false)
    }

    @Test("isLevelActive returns false when no activeWorld set")
    func levelActiveNoActiveWorld() {
        let appModel = TestHelpers.makeTestAppModel()
        appModel.activeWorld = nil
        appModel.selectedLevelIndex = 0
        let world = World.allWorlds.first!

        let result = LevelGridQueries.isLevelActive(0, in: world, appModel: appModel)
        #expect(result == false)
    }

    // MARK: - isLevelCompleted

    @Test("isLevelCompleted delegates to progressService")
    func levelCompletedDelegation() {
        let appModel = TestHelpers.makeTestAppModel()
        let world = World.allWorlds.first!

        // Not completed initially
        #expect(LevelGridQueries.isLevelCompleted(0, in: world, appModel: appModel) == false)

        // Complete the level
        appModel.progressService.currentLevelPushes = 5
        appModel.progressService.completeLevel(for: world, levelIndex: 0)

        #expect(LevelGridQueries.isLevelCompleted(0, in: world, appModel: appModel) == true)
    }

    // MARK: - starRating

    @Test("starRating delegates to progressService")
    func starRatingDelegation() {
        let appModel = TestHelpers.makeTestAppModel()
        let world = World.allWorlds.first!

        // No rating initially
        #expect(LevelGridQueries.starRating(for: 0, in: world, appModel: appModel) == 0)

        // Complete at optimal push count → 3 stars
        let optimal = world.optimalPushCounts.first ?? 5
        appModel.progressService.currentLevelPushes = optimal
        appModel.progressService.completeLevel(for: world, levelIndex: 0)

        #expect(LevelGridQueries.starRating(for: 0, in: world, appModel: appModel) == 3)
    }
}
