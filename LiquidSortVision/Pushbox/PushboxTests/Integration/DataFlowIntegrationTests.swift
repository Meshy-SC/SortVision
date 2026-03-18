// DataFlowIntegrationTests.swift
// Integration tests for end-to-end data flow paths.

import Testing
import Foundation
import SwiftData
@testable import Pushbox

@Suite("Data Flow Integration", .tags(.integration))
@MainActor
struct DataFlowIntegrationTests {

    // MARK: - Progress Persistence Round-Trip

    @Test("Completed level persists across ProgressService instances")
    func progressPersistsAcrossInstances() {
        let container = TestHelpers.makeTestContainer()
        let world = TestHelpers.makeTestWorld(optimalPushCounts: [10])

        // First service: complete a level
        let service1 = ProgressService(modelContext: container.mainContext)
        service1.currentLevelPushes = 10
        service1.completeLevel(for: world, levelIndex: 0)
        service1.saveProgress()

        // Second service on same container: verify data loaded
        let service2 = ProgressService(modelContext: container.mainContext)
        #expect(service2.isLevelCompleted(worldName: world.worldName, levelIndex: 0))
        #expect(service2.starRating(worldName: world.worldName, levelIndex: 0) == 3)
    }

    @Test("Multiple level completions are tracked independently")
    func multipleLevelCompletions() {
        let container = TestHelpers.makeTestContainer()
        let world = TestHelpers.makeTestWorld(optimalPushCounts: [5, 10, 15])
        let service = ProgressService(modelContext: container.mainContext)

        // Complete level 0 with 3 stars
        service.currentLevelPushes = 5
        service.completeLevel(for: world, levelIndex: 0)

        // Complete level 1 with 1 star
        service.currentLevelPushes = 30
        service.completeLevel(for: world, levelIndex: 1)

        // Verify independent tracking
        #expect(service.starRating(worldName: world.worldName, levelIndex: 0) == 3)
        #expect(service.starRating(worldName: world.worldName, levelIndex: 1) == 1)
        #expect(!service.isLevelCompleted(worldName: world.worldName, levelIndex: 2))
        #expect(service.completedCount(for: world.worldName) == 2)
    }

    @Test("Reset clears all persisted data across worlds")
    func resetClearsAllData() {
        let container = TestHelpers.makeTestContainer()
        let world1 = TestHelpers.makeTestWorld(worldName: "World1", optimalPushCounts: [5])
        let world2 = TestHelpers.makeTestWorld(worldName: "World2", optimalPushCounts: [10])
        let service = ProgressService(modelContext: container.mainContext)

        service.currentLevelPushes = 5
        service.completeLevel(for: world1, levelIndex: 0)
        service.currentLevelPushes = 10
        service.completeLevel(for: world2, levelIndex: 0)

        service.resetAllProgress()

        #expect(!service.isLevelCompleted(worldName: "World1", levelIndex: 0))
        #expect(!service.isLevelCompleted(worldName: "World2", levelIndex: 0))

        // Verify SwiftData store is also cleared
        let service2 = ProgressService(modelContext: container.mainContext)
        #expect(service2.completedCount(for: "World1") == 0)
        #expect(service2.completedCount(for: "World2") == 0)
    }

    // MARK: - Star Rating End-to-End

    @Test("Star rating calculation verified end-to-end",
          arguments: [
            (pushes: 5, optimal: 10, expectedStars: 3),  // Below optimal → 3 stars
            (pushes: 10, optimal: 10, expectedStars: 3),  // At optimal → 3 stars
            (pushes: 11, optimal: 10, expectedStars: 2),  // Within 20% → 2 stars
            (pushes: 12, optimal: 10, expectedStars: 2),  // At 20% boundary → 2 stars
            (pushes: 13, optimal: 10, expectedStars: 1),  // Above 20% → 1 star
            (pushes: 100, optimal: 10, expectedStars: 1), // Way above → 1 star
          ])
    func starRatingEndToEnd(pushes: Int, optimal: Int, expectedStars: Int) {
        let container = TestHelpers.makeTestContainer()
        let world = TestHelpers.makeTestWorld(optimalPushCounts: [optimal])
        let service = ProgressService(modelContext: container.mainContext)

        service.currentLevelPushes = pushes
        service.completeLevel(for: world, levelIndex: 0)
        #expect(service.starRating(worldName: world.worldName, levelIndex: 0) == expectedStars)
    }

    // MARK: - Global Score End-to-End

    @Test("Global score accumulates correctly across multiple completions")
    func globalScoreEndToEnd() {
        let container = TestHelpers.makeTestContainer()
        let world = TestHelpers.makeTestWorld(optimalPushCounts: [10, 10, 10])
        let service = ProgressService(modelContext: container.mainContext)

        // 3 stars = 10 points
        service.currentLevelPushes = 10
        service.completeLevel(for: world, levelIndex: 0)
        #expect(service.globalScore == 10)

        // 2 stars = 7 points
        service.currentLevelPushes = 12
        service.completeLevel(for: world, levelIndex: 1)
        #expect(service.globalScore == 17)

        // 1 star = 5 points
        service.currentLevelPushes = 50
        service.completeLevel(for: world, levelIndex: 2)
        #expect(service.globalScore == 22)
    }

    // MARK: - Push Count Lifecycle

    @Test("Push count lifecycle: increment → complete → reset")
    func pushCountLifecycle() {
        let container = TestHelpers.makeTestContainer()
        let world = TestHelpers.makeTestWorld()
        let service = ProgressService(modelContext: container.mainContext)

        // Simulate game play
        service.incrementPushCount()
        service.incrementPushCount()
        service.incrementPushCount()
        #expect(service.currentLevelPushes == 3)

        // Undo one move
        service.decrementPushCount()
        #expect(service.currentLevelPushes == 2)

        // Complete level — push count resets
        service.completeLevel(for: world, levelIndex: 0)
        #expect(service.currentLevelPushes == 0)
    }

    // MARK: - AppModel ↔ ProgressService Integration

    @Test("AppModel.optimalPushes flows through to ProgressService")
    func appModelOptimalPushesFlow() {
        let appModel = TestHelpers.makeTestAppModel()
        let world = World.allWorlds.first!
        appModel.selectedWorld = world
        appModel.activeWorld = world
        appModel.selectedLevelIndex = 0

        let expected = world.optimalPushCounts[0]
        #expect(appModel.optimalPushes == expected)
    }

    // MARK: - IAP ↔ Solution Integration

    @Test("Solution unlock persists across InAppPurchaseService instances")
    func solutionUnlockPersistence() {
        let container = TestHelpers.makeTestContainer()
        let world = TestHelpers.makeTestWorld()

        let service1 = InAppPurchaseService(modelContext: container.mainContext)
        _ = service1.consumeSolutionCredit(for: world, level: 0)
        #expect(service1.hasUnlockedSolution(world: world, level: 0))

        // New instance should load the unlocked solution
        let service2 = InAppPurchaseService(modelContext: container.mainContext)
        #expect(service2.hasUnlockedSolution(world: world, level: 0))
    }

    // MARK: - SolutionCrypto ↔ World Integration

    @Test("Encrypted solutions in World decrypt correctly end-to-end")
    func encryptedSolutionsEndToEnd() {
        let solutions = ["udlr", "RRDDLL", "uulldd"]
        let world = TestHelpers.makeTestWorldWithSolutions(plaintextSolutions: solutions)

        let decrypted = world.decryptedSolutions
        #expect(decrypted != nil)
        #expect(decrypted?.count == solutions.count)
        for (index, expected) in solutions.enumerated() {
            #expect(decrypted?[index] == expected)
        }
    }
}
