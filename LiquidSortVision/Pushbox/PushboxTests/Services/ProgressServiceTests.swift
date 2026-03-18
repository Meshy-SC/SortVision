// ProgressServiceTests.swift
// Tests for the ProgressService (game progress tracking and persistence).

import Testing
import Foundation
import SwiftData
@testable import Pushbox

@Suite("ProgressService")
@MainActor
struct ProgressServiceTests {

    // MARK: - Push Count Management

    @Test("Initial push count is zero")
    func initialPushCount() {
        let (service, _container) = TestHelpers.makeTestProgressService()
        #expect(service.currentLevelPushes == 0)
    }

    @Test("incrementPushCount increases by one")
    func incrementPushCount() {
        let (service, _container) = TestHelpers.makeTestProgressService()
        service.incrementPushCount()
        #expect(service.currentLevelPushes == 1)
        service.incrementPushCount()
        #expect(service.currentLevelPushes == 2)
    }

    @Test("decrementPushCount decreases by one")
    func decrementPushCount() {
        let (service, _container) = TestHelpers.makeTestProgressService()
        service.currentLevelPushes = 5
        service.decrementPushCount()
        #expect(service.currentLevelPushes == 4)
    }

    @Test("decrementPushCount does not go below zero")
    func decrementPushCountFloor() {
        let (service, _container) = TestHelpers.makeTestProgressService()
        #expect(service.currentLevelPushes == 0)
        service.decrementPushCount()
        #expect(service.currentLevelPushes == 0)
    }

    @Test("resetPushCount sets count to zero")
    func resetPushCount() {
        let (service, _container) = TestHelpers.makeTestProgressService()
        service.currentLevelPushes = 10
        service.resetPushCount()
        #expect(service.currentLevelPushes == 0)
    }

    // MARK: - Star Rating Calculation

    @Test("Completing at optimal push count awards 3 stars")
    func threeStarRating() {
        let (service, _container) = TestHelpers.makeTestProgressService()
        let world = TestHelpers.makeTestWorld(optimalPushCounts: [10])
        service.currentLevelPushes = 10
        service.completeLevel(for: world, levelIndex: 0)
        #expect(service.starRating(worldName: world.worldName, levelIndex: 0) == 3)
    }

    @Test("Completing below optimal push count awards 3 stars")
    func threeStarBelowOptimal() {
        let (service, _container) = TestHelpers.makeTestProgressService()
        let world = TestHelpers.makeTestWorld(optimalPushCounts: [10])
        service.currentLevelPushes = 7
        service.completeLevel(for: world, levelIndex: 0)
        #expect(service.starRating(worldName: world.worldName, levelIndex: 0) == 3)
    }

    @Test("Completing within 20% above optimal awards 2 stars")
    func twoStarRating() {
        let (service, _container) = TestHelpers.makeTestProgressService()
        // Optimal = 10, 20% threshold = 12
        let world = TestHelpers.makeTestWorld(optimalPushCounts: [10])
        service.currentLevelPushes = 12
        service.completeLevel(for: world, levelIndex: 0)
        #expect(service.starRating(worldName: world.worldName, levelIndex: 0) == 2)
    }

    @Test("Completing at exactly 20% above optimal awards 2 stars")
    func twoStarExactThreshold() {
        let (service, _container) = TestHelpers.makeTestProgressService()
        // Optimal = 5, 20% threshold = ceil(5 * 1.2) = 6
        let world = TestHelpers.makeTestWorld(optimalPushCounts: [5])
        service.currentLevelPushes = 6
        service.completeLevel(for: world, levelIndex: 0)
        #expect(service.starRating(worldName: world.worldName, levelIndex: 0) == 2)
    }

    @Test("Completing more than 20% above optimal awards 1 star")
    func oneStarRating() {
        let (service, _container) = TestHelpers.makeTestProgressService()
        // Optimal = 10, 20% threshold = 12, so 13+ = 1 star
        let world = TestHelpers.makeTestWorld(optimalPushCounts: [10])
        service.currentLevelPushes = 20
        service.completeLevel(for: world, levelIndex: 0)
        #expect(service.starRating(worldName: world.worldName, levelIndex: 0) == 1)
    }

    // MARK: - Level Completion Tracking

    @Test("Level is not completed initially")
    func notCompletedInitially() {
        let (service, _container) = TestHelpers.makeTestProgressService()
        #expect(!service.isLevelCompleted(worldName: "World1", levelIndex: 0))
    }

    @Test("Level is marked completed after completeLevel")
    func markedCompleted() {
        let (service, _container) = TestHelpers.makeTestProgressService()
        let world = TestHelpers.makeTestWorld()
        service.currentLevelPushes = 5
        service.completeLevel(for: world, levelIndex: 0)
        #expect(service.isLevelCompleted(worldName: world.worldName, levelIndex: 0))
    }

    @Test("Star rating is zero for uncompleted level")
    func zeroStarForUncompleted() {
        let (service, _container) = TestHelpers.makeTestProgressService()
        #expect(service.starRating(worldName: "World1", levelIndex: 0) == 0)
    }

    @Test("Completed count starts at zero")
    func completedCountZero() {
        let (service, _container) = TestHelpers.makeTestProgressService()
        #expect(service.completedCount(for: "World1") == 0)
    }

    @Test("Completed count increments with each level completion")
    func completedCountIncrements() {
        let (service, _container) = TestHelpers.makeTestProgressService()
        let world = TestHelpers.makeTestWorld(optimalPushCounts: [5, 10, 15])

        service.currentLevelPushes = 5
        service.completeLevel(for: world, levelIndex: 0)
        #expect(service.completedCount(for: world.worldName) == 1)

        service.currentLevelPushes = 10
        service.completeLevel(for: world, levelIndex: 1)
        #expect(service.completedCount(for: world.worldName) == 2)
    }

    @Test("completeLevel resets push count after recording")
    func completeLevelResetsPushCount() {
        let (service, _container) = TestHelpers.makeTestProgressService()
        let world = TestHelpers.makeTestWorld()
        service.currentLevelPushes = 8
        service.completeLevel(for: world, levelIndex: 0)
        #expect(service.currentLevelPushes == 0)
    }

    // MARK: - Statistics

    @Test("Overall progress starts at zero")
    func overallProgressZero() {
        let (service, _container) = TestHelpers.makeTestProgressService()
        #expect(service.overallProgress == 0)
    }

    @Test("Global score starts at zero")
    func globalScoreZero() {
        let (service, _container) = TestHelpers.makeTestProgressService()
        #expect(service.globalScore == 0)
    }

    @Test("Global score accumulates: 3 stars = 10, 2 stars = 7, 1 star = 5")
    func globalScoreAccumulation() {
        let (service, _container) = TestHelpers.makeTestProgressService()
        let world = TestHelpers.makeTestWorld(optimalPushCounts: [10, 10, 10])

        // 3-star completion (10 points)
        service.currentLevelPushes = 10
        service.completeLevel(for: world, levelIndex: 0)

        // 1-star completion (5 points)
        service.currentLevelPushes = 30
        service.completeLevel(for: world, levelIndex: 1)

        #expect(service.globalScore == 15) // 10 + 5
    }

    @Test("maximumGlobalScore is 10 per level across all worlds")
    func maximumGlobalScore() {
        let (service, _container) = TestHelpers.makeTestProgressService()
        let totalLevels = World.totalLevelsPerWorld.values.reduce(0, +)
        #expect(service.maximumGlobalScore == totalLevels * 10)
    }

    // MARK: - Reset

    @Test("resetAllProgress clears all progress data")
    func resetAllProgress() {
        let (service, _container) = TestHelpers.makeTestProgressService()
        let world = TestHelpers.makeTestWorld()
        service.currentLevelPushes = 5
        service.completeLevel(for: world, levelIndex: 0)
        #expect(service.completedCount(for: world.worldName) == 1)

        service.resetAllProgress()
        #expect(service.completedCount(for: world.worldName) == 0)
        #expect(service.globalScore == 0)
        #expect(service.overallProgress == 0)
        #expect(service.currentLevelPushes == 0)
    }

    // MARK: - Optimal Pushes

    @Test("optimalPushes returns correct value for valid index")
    func optimalPushesValid() {
        let (service, _container) = TestHelpers.makeTestProgressService()
        let world = TestHelpers.makeTestWorld(optimalPushCounts: [5, 10, 15])
        #expect(service.optimalPushes(for: world, levelIndex: 1) == 10)
    }

    @Test("optimalPushes returns nil for nil world")
    func optimalPushesNilWorld() {
        let (service, _container) = TestHelpers.makeTestProgressService()
        #expect(service.optimalPushes(for: nil, levelIndex: 0) == nil)
    }

    @Test("optimalPushes returns nil for nil level index")
    func optimalPushesNilIndex() {
        let (service, _container) = TestHelpers.makeTestProgressService()
        let world = TestHelpers.makeTestWorld()
        #expect(service.optimalPushes(for: world, levelIndex: nil) == nil)
    }

    @Test("optimalPushes returns nil for out-of-bounds index")
    func optimalPushesOutOfBounds() {
        let (service, _container) = TestHelpers.makeTestProgressService()
        let world = TestHelpers.makeTestWorld(optimalPushCounts: [5])
        #expect(service.optimalPushes(for: world, levelIndex: 99) == nil)
    }

    // MARK: - Persistence Round-Trip

    @Test("Progress persists and loads correctly via SwiftData")
    func persistenceRoundTrip() {
        let container = TestHelpers.makeTestContainer()
        let world = TestHelpers.makeTestWorld(optimalPushCounts: [10])

        // Complete a level with the first service instance
        let service1 = ProgressService(modelContext: container.mainContext)
        service1.currentLevelPushes = 10
        service1.completeLevel(for: world, levelIndex: 0)
        service1.saveProgress()

        // Load progress with a fresh service instance on the same container
        let service2 = ProgressService(modelContext: container.mainContext)
        #expect(service2.isLevelCompleted(worldName: world.worldName, levelIndex: 0))
        #expect(service2.starRating(worldName: world.worldName, levelIndex: 0) == 3)
    }
    
    // MARK: - Level Progression & Unlocking

    @Test("First world is always unlocked")
    func firstWorldAlwaysUnlocked() {
        let (service, _container) = TestHelpers.makeTestProgressService()
        let firstWorld = World.allWorlds.first!
        #expect(service.isWorldUnlocked(firstWorld))
    }

    @Test("Second world is locked when first world has no completions")
    func secondWorldLockedInitially() {
        let (service, _container) = TestHelpers.makeTestProgressService()
        guard World.allWorlds.count >= 2 else { return }
        let secondWorld = World.allWorlds[1]
        #expect(!service.isWorldUnlocked(secondWorld))
    }

    @Test("Second world unlocks when 50% of first world is completed")
    func secondWorldUnlocksAtThreshold() {
        let (service, _container) = TestHelpers.makeTestProgressService()
        guard World.allWorlds.count >= 2 else { return }
        let firstWorld = World.allWorlds[0]
        let secondWorld = World.allWorlds[1]
        
        let totalLevels = firstWorld.levelCount
        let requiredCompletions = Int(ceil(Double(totalLevels) * ProgressService.worldUnlockThreshold))
        
        // Complete just under the threshold
        for i in 0..<(requiredCompletions - 1) {
            service.currentLevelPushes = 5
            service.completeLevel(for: firstWorld, levelIndex: i)
        }
        #expect(!service.isWorldUnlocked(secondWorld))
        
        // Complete one more to reach the threshold
        service.currentLevelPushes = 5
        service.completeLevel(for: firstWorld, levelIndex: requiredCompletions - 1)
        #expect(service.isWorldUnlocked(secondWorld))
    }

    @Test("First group of levels (0-9) is always unlocked when world is unlocked")
    func firstGroupAlwaysUnlocked() {
        let (service, _container) = TestHelpers.makeTestProgressService()
        let firstWorld = World.allWorlds.first!
        
        for i in 0..<min(10, firstWorld.levelCount) {
            #expect(service.isLevelUnlocked(i, in: firstWorld))
        }
    }

    @Test("Second group of levels is locked with no completions in first group")
    func secondGroupLockedInitially() {
        let (service, _container) = TestHelpers.makeTestProgressService()
        let firstWorld = World.allWorlds.first!
        guard firstWorld.levelCount > 10 else { return }
        
        #expect(!service.isLevelUnlocked(10, in: firstWorld))
    }

    @Test("Second group unlocks when 60% of first group is completed")
    func secondGroupUnlocksAtThreshold() {
        let (service, _container) = TestHelpers.makeTestProgressService()
        let firstWorld = World.allWorlds.first!
        guard firstWorld.levelCount > 10 else { return }
        
        let groupSize = ProgressService.levelsPerGroup
        let requiredCompletions = Int(ceil(Double(groupSize) * ProgressService.groupUnlockThreshold))
        
        // Complete just under the threshold
        for i in 0..<(requiredCompletions - 1) {
            service.currentLevelPushes = 5
            service.completeLevel(for: firstWorld, levelIndex: i)
        }
        #expect(!service.isLevelUnlocked(10, in: firstWorld))
        
        // Complete one more to reach the threshold
        service.currentLevelPushes = 5
        service.completeLevel(for: firstWorld, levelIndex: requiredCompletions - 1)
        #expect(service.isLevelUnlocked(10, in: firstWorld))
    }

    @Test("Levels in locked world are not unlocked")
    func levelsInLockedWorldNotUnlocked() {
        let (service, _container) = TestHelpers.makeTestProgressService()
        guard World.allWorlds.count >= 2 else { return }
        let secondWorld = World.allWorlds[1]
        
        // Second world should be locked, so its first level should also be locked
        #expect(!service.isWorldUnlocked(secondWorld))
        #expect(!service.isLevelUnlocked(0, in: secondWorld))
    }

    @Test("nextPlayableLevel returns first incomplete unlocked level")
    func nextPlayableLevelReturnsFirst() {
        let (service, _container) = TestHelpers.makeTestProgressService()
        let firstWorld = World.allWorlds.first!
        
        // Initially, level 0 should be the next playable level
        #expect(service.nextPlayableLevel(in: firstWorld) == 0)
        
        // Complete level 0 — next playable should be level 1
        service.currentLevelPushes = 5
        service.completeLevel(for: firstWorld, levelIndex: 0)
        #expect(service.nextPlayableLevel(in: firstWorld) == 1)
    }

    @Test("firstLockedLevelIndex returns correct boundary")
    func firstLockedLevelIndexCorrect() {
        let (service, _container) = TestHelpers.makeTestProgressService()
        let firstWorld = World.allWorlds.first!
        guard firstWorld.levelCount > 10 else { return }
        
        // With no completions, level 10 should be the first locked level
        #expect(service.firstLockedLevelIndex(in: firstWorld) == 10)
    }

    @Test("completionsNeededForNextWorld returns correct value")
    func completionsNeededCorrect() {
        let (service, _container) = TestHelpers.makeTestProgressService()
        let firstWorld = World.allWorlds.first!
        let expected = Int(ceil(Double(firstWorld.levelCount) * ProgressService.worldUnlockThreshold))
        #expect(service.completionsNeededForNextWorld(after: firstWorld.worldName) == expected)
    }

    @Test("Reset progress re-locks worlds and levels")
    func resetRelocks() {
        let (service, _container) = TestHelpers.makeTestProgressService()
        guard World.allWorlds.count >= 2 else { return }
        let firstWorld = World.allWorlds[0]
        let secondWorld = World.allWorlds[1]
        
        // Unlock the second world
        let requiredCompletions = Int(ceil(Double(firstWorld.levelCount) * ProgressService.worldUnlockThreshold))
        for i in 0..<requiredCompletions {
            service.currentLevelPushes = 5
            service.completeLevel(for: firstWorld, levelIndex: i)
        }
        #expect(service.isWorldUnlocked(secondWorld))
        
        // Reset should re-lock
        service.resetAllProgress()
        #expect(!service.isWorldUnlocked(secondWorld))
    }
}
