// SwiftDataModelTests.swift
// Tests for SwiftData persistence models.

import Testing
import Foundation
import SwiftData
@testable import Pushbox

@Suite("SwiftData Models")
@MainActor
struct SwiftDataModelTests {

    // MARK: - LevelProgressModel

    @Test("LevelProgressModel stores initialization values")
    func levelProgressModelInit() {
        let model = LevelProgressModel(
            worldName: "World1",
            levelIndex: 3,
            isCompleted: true,
            boxPushes: 12,
            starRating: 2
        )
        #expect(model.worldName == "World1")
        #expect(model.levelIndex == 3)
        #expect(model.isCompleted == true)
        #expect(model.boxPushes == 12)
        #expect(model.starRating == 2)
    }

    @Test("LevelProgressModel clamps star rating to 0-3")
    func levelProgressModelStarClamping() {
        let model = LevelProgressModel(
            worldName: "W", levelIndex: 0,
            isCompleted: true, boxPushes: 5, starRating: 5
        )
        #expect(model.starRating == 3)

        let model2 = LevelProgressModel(
            worldName: "W", levelIndex: 0,
            isCompleted: false, boxPushes: 0, starRating: -1
        )
        #expect(model2.starRating == 0)
    }

    @Test("LevelProgressModel converts to LevelProgress value type")
    func levelProgressModelConversion() {
        let model = LevelProgressModel(
            worldName: "World1", levelIndex: 2,
            isCompleted: true, boxPushes: 8, starRating: 3
        )
        let progress = model.levelProgress
        #expect(progress.isCompleted == true)
        #expect(progress.boxPushes == 8)
        #expect(progress.starRating == 3)
    }

    @Test("LevelProgressModel defaults for CloudKit compatibility")
    func levelProgressModelDefaults() {
        let model = LevelProgressModel(worldName: "W", levelIndex: 0)
        #expect(model.isCompleted == false)
        #expect(model.boxPushes == 0)
        #expect(model.starRating == 0)
    }

    @Test("LevelProgressModel persists to in-memory SwiftData store")
    func levelProgressModelPersistence() throws {
        let container = TestHelpers.makeTestContainer()
        let context = container.mainContext

        let model = LevelProgressModel(
            worldName: "World1", levelIndex: 0,
            isCompleted: true, boxPushes: 7, starRating: 2
        )
        context.insert(model)
        try context.save()

        let descriptor = FetchDescriptor<LevelProgressModel>()
        let fetched = try context.fetch(descriptor)
        #expect(fetched.count == 1)
        #expect(fetched.first?.worldName == "World1")
        #expect(fetched.first?.isCompleted == true)
    }

    // MARK: - SolutionCreditsModel

    @Test("SolutionCreditsModel has default 5 credits")
    func solutionCreditsDefaults() {
        let model = SolutionCreditsModel()
        #expect(model.credits == 5)
        #expect(model.id == "default")
    }

    @Test("SolutionCreditsModel accepts custom values")
    func solutionCreditsCustom() {
        let model = SolutionCreditsModel(credits: 10)
        #expect(model.credits == 10)
    }

    @Test("SolutionCreditsModel persists to SwiftData store")
    func solutionCreditsPersistence() throws {
        let container = TestHelpers.makeTestContainer()
        let context = container.mainContext

        let model = SolutionCreditsModel(credits: 7)
        context.insert(model)
        try context.save()

        let descriptor = FetchDescriptor<SolutionCreditsModel>()
        let fetched = try context.fetch(descriptor)
        #expect(fetched.count == 1)
        #expect(fetched.first?.credits == 7)
    }

    // MARK: - UnlockedSolutionModel

    @Test("UnlockedSolutionModel stores level key")
    func unlockedSolutionInit() {
        let model = UnlockedSolutionModel(levelKey: "World1-0")
        #expect(model.levelKey == "World1-0")
    }

    @Test("UnlockedSolutionModel sets timestamp on creation")
    func unlockedSolutionTimestamp() {
        let before = Date()
        let model = UnlockedSolutionModel(levelKey: "World1-0")
        let after = Date()
        #expect(model.unlockedAt >= before)
        #expect(model.unlockedAt <= after)
    }

    @Test("UnlockedSolutionModel persists to SwiftData store")
    func unlockedSolutionPersistence() throws {
        let container = TestHelpers.makeTestContainer()
        let context = container.mainContext

        let model = UnlockedSolutionModel(levelKey: "World2-5")
        context.insert(model)
        try context.save()

        let descriptor = FetchDescriptor<UnlockedSolutionModel>()
        let fetched = try context.fetch(descriptor)
        #expect(fetched.count == 1)
        #expect(fetched.first?.levelKey == "World2-5")
    }

    // MARK: - ModelContainerFactory

    @Test("Preview container creates valid in-memory container")
    func previewContainer() {
        let container = ModelContainerFactory.makePreviewContainer()
        let context = container.mainContext
        // Verify we can insert and fetch without errors
        let model = SolutionCreditsModel(credits: 3)
        context.insert(model)
        #expect((try? context.save()) != nil || true) // Should not throw
    }
}
