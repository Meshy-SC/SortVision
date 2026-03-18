// CloudKitSyncTests.swift
// Tests for CloudKit sync behavior in ProgressService and InAppPurchaseService.

import Testing
import Foundation
import SwiftData
@testable import Pushbox

// MARK: - CloudKit Sync Tests

@MainActor
@Suite("CloudKit Sync Tests", .tags(.integration))
struct CloudKitSyncTests {

    // MARK: - InAppPurchaseService Remote Changes

    @Test("refreshFromRemoteChanges reloads credits from SwiftData")
    func refreshCredits() {
        let container = TestHelpers.makeTestContainer()
        let context = container.mainContext
        let service = InAppPurchaseService(modelContext: context)

        let initialCredits = service.solutionCredits

        // Simulate a remote change: modify credits directly in SwiftData
        let descriptor = FetchDescriptor<SolutionCreditsModel>()
        if let model = try? context.fetch(descriptor).first {
            model.credits = initialCredits + 3
            try? context.save()
        }

        // Refresh as if CloudKit pushed a change
        service.refreshFromRemoteChanges()

        #expect(service.solutionCredits == initialCredits + 3)
    }

    @Test("refreshFromRemoteChanges reloads unlocked solutions from SwiftData")
    func refreshUnlockedSolutions() {
        let container = TestHelpers.makeTestContainer()
        let context = container.mainContext
        let service = InAppPurchaseService(modelContext: context)

        #expect(service.unlockedSolutions.isEmpty)

        // Simulate a remote unlock
        let model = UnlockedSolutionModel(levelKey: "World1-0")
        context.insert(model)
        try? context.save()

        service.refreshFromRemoteChanges()

        #expect(service.unlockedSolutions.contains("World1-0"))
    }

    @Test("Credits are capped at total levels")
    func creditsCappedAtRemaining() {
        let container = TestHelpers.makeTestContainer()
        let context = container.mainContext
        let service = InAppPurchaseService(modelContext: context)

        let totalLevels = service.totalLevelsAcrossAllWorlds

        // Try to set credits higher than the configured cap
        service.setSolutionCredits(totalLevels + 100)

        #expect(service.solutionCredits <= totalLevels)
    }

    @Test("New service instance reads persisted credits from SwiftData")
    func crossInstanceCredits() {
        let container = TestHelpers.makeTestContainer()
        let context = container.mainContext

        // First instance sets credits
        let service1 = InAppPurchaseService(modelContext: context)
        service1.setSolutionCredits(3)
        #expect(service1.solutionCredits == 3)

        // Second instance should read the same value
        let service2 = InAppPurchaseService(modelContext: context)
        #expect(service2.solutionCredits == 3)
    }

    @Test("New service instance reads persisted unlocked solutions from SwiftData")
    func crossInstanceUnlockedSolutions() {
        let container = TestHelpers.makeTestContainer()
        let context = container.mainContext
        let world = World.allWorlds.first!

        // First instance unlocks a solution
        let service1 = InAppPurchaseService(modelContext: context)
        let consumed = service1.consumeSolutionCredit(for: world, level: 0)
        #expect(consumed == true)
        #expect(service1.hasUnlockedSolution(world: world, level: 0) == true)

        // Second instance should see the unlock
        let service2 = InAppPurchaseService(modelContext: context)
        #expect(service2.hasUnlockedSolution(world: world, level: 0) == true)
    }

    // MARK: - ProgressService Remote Changes

    @Test("ProgressService loadProgress reflects SwiftData changes")
    func progressReflectsChanges() {
        let container = TestHelpers.makeTestContainer()
        let context = container.mainContext
        let service = ProgressService(modelContext: context)

        // No progress initially
        #expect(service.completedCount(for: "World1") == 0)

        // Insert progress directly (simulating CloudKit sync)
        let model = LevelProgressModel(
            worldName: "World1",
            levelIndex: 0,
            isCompleted: true,
            boxPushes: 5,
            starRating: 3
        )
        context.insert(model)
        try? context.save()

        // Reload
        service.loadProgress()

        #expect(service.completedCount(for: "World1") == 1)
        #expect(service.isLevelCompleted(worldName: "World1", levelIndex: 0) == true)
        #expect(service.starRating(worldName: "World1", levelIndex: 0) == 3)
    }

    @Test("ProgressService overallProgress and globalScore update on load")
    func statisticsUpdateOnLoad() {
        let container = TestHelpers.makeTestContainer()
        let context = container.mainContext
        let service = ProgressService(modelContext: context)

        #expect(service.globalScore == 0)
        #expect(service.overallProgress == 0)

        // Insert a completed level
        let model = LevelProgressModel(
            worldName: "World1",
            levelIndex: 0,
            isCompleted: true,
            boxPushes: 5,
            starRating: 3
        )
        context.insert(model)
        try? context.save()
        service.loadProgress()

        #expect(service.globalScore == 10) // 3 stars = 10 points
        #expect(service.overallProgress > 0)
    }
}
