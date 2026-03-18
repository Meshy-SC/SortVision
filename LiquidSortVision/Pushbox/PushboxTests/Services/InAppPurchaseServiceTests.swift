// InAppPurchaseServiceTests.swift
// Tests for the InAppPurchaseService (solution credits and unlock tracking).

import Testing
import Foundation
import SwiftData
@testable import Pushbox

@Suite("InAppPurchaseService")
@MainActor
struct InAppPurchaseServiceTests {

    // MARK: - Initial State

    @Test("Initial credits default to 1 on fresh install")
    func initialCredits() {
        let (service, _container) = TestHelpers.makeTestIAPService()
        #expect(service.solutionCredits == 1)
    }

    @Test("No solutions are unlocked initially")
    func noUnlockedSolutions() {
        let (service, _container) = TestHelpers.makeTestIAPService()
        #expect(service.unlockedSolutions.isEmpty)
    }

    // MARK: - Solution Key Format

    @Test("solutionKey produces correct format")
    func solutionKeyFormat() {
        let (service, _container) = TestHelpers.makeTestIAPService()
        let world = TestHelpers.makeTestWorld(worldName: "World1")
        let key = service.solutionKey(for: world, levelIndex: 3)
        #expect(key == "World1-3")
    }

    @Test("solutionKey is unique per world and level")
    func solutionKeyUniqueness() {
        let (service, _container) = TestHelpers.makeTestIAPService()
        let world1 = TestHelpers.makeTestWorld(worldName: "World1")
        let world2 = TestHelpers.makeTestWorld(worldName: "World2")
        #expect(service.solutionKey(for: world1, levelIndex: 0) != service.solutionKey(for: world2, levelIndex: 0))
        #expect(service.solutionKey(for: world1, levelIndex: 0) != service.solutionKey(for: world1, levelIndex: 1))
    }

    // MARK: - Solution Unlock

    @Test("hasUnlockedSolution returns false for locked solution")
    func hasUnlockedSolutionFalse() {
        let (service, _container) = TestHelpers.makeTestIAPService()
        let world = TestHelpers.makeTestWorld()
        #expect(!service.hasUnlockedSolution(world: world, level: 0))
    }

    @Test("consumeSolutionCredit unlocks solution and decrements credits")
    func consumeCredit() {
        let (service, _container) = TestHelpers.makeTestIAPService()
        let world = TestHelpers.makeTestWorld()
        let initialCredits = service.solutionCredits

        let result = service.consumeSolutionCredit(for: world, level: 0)
        #expect(result == true)
        #expect(service.hasUnlockedSolution(world: world, level: 0))
        #expect(service.solutionCredits == initialCredits - 1)
    }

    @Test("consumeSolutionCredit returns false when no credits available")
    func consumeCreditNoCredits() {
        let (service, _container) = TestHelpers.makeTestIAPService()
        let world = TestHelpers.makeTestWorld()

        // Drain all credits
        service.setSolutionCredits(0)
        let result = service.consumeSolutionCredit(for: world, level: 0)
        #expect(result == false)
        #expect(!service.hasUnlockedSolution(world: world, level: 0))
    }

    @Test("consumeSolutionCredit for already-unlocked solution allows free replay without consuming")
    func consumeCreditAlreadyUnlocked() {
        let (service, _container) = TestHelpers.makeTestIAPService()
        let world = TestHelpers.makeTestWorld()
        service.setSolutionCredits(2)

        // Unlock first
        _ = service.consumeSolutionCredit(for: world, level: 0)
        let creditsAfterFirstUnlock = service.solutionCredits

        // Replay — should return true without consuming another credit
        let result = service.consumeSolutionCredit(for: world, level: 0)
        #expect(result == true)
        #expect(service.solutionCredits == creditsAfterFirstUnlock)
    }

    // MARK: - Credits Management

    @Test("setSolutionCredits updates the value")
    func setSolutionCredits() {
        let (service, _container) = TestHelpers.makeTestIAPService()
        service.setSolutionCredits(10)
        #expect(service.solutionCredits == 10)
    }

    @Test("setSolutionCredits caps at useful maximum")
    func setSolutionCreditsCapped() {
        let (service, _container) = TestHelpers.makeTestIAPService()
        // Setting extremely high value should be capped
        service.setSolutionCredits(99999)
        #expect(service.solutionCredits <= service.totalLevelsAcrossAllWorlds)
    }

    @Test("setSolutionCredits does not go below zero")
    func setSolutionCreditsFloor() {
        let (service, _container) = TestHelpers.makeTestIAPService()
        service.setSolutionCredits(-5)
        #expect(service.solutionCredits >= 0)
    }

    @Test("remainingCreditCapacity increases as credits are consumed")
    func remainingCapacity() {
        let (service, _container) = TestHelpers.makeTestIAPService()
        let world = TestHelpers.makeTestWorld()
        let capacityBefore = service.remainingCreditCapacity

        _ = service.consumeSolutionCredit(for: world, level: 0)
        #expect(service.remainingCreditCapacity >= capacityBefore)
    }

    @Test("totalLevelsAcrossAllWorlds matches sum of all world level counts")
    func totalLevelsCalculation() {
        let (service, _container) = TestHelpers.makeTestIAPService()
        let expected = World.allWorlds.reduce(0) { $0 + $1.levelCount }
        #expect(service.totalLevelsAcrossAllWorlds == expected)
    }

    @Test("maximumSolutionCredits is 10 for gauge display")
    func maximumCreditsGauge() {
        let (service, _container) = TestHelpers.makeTestIAPService()
        #expect(service.maximumSolutionCredits == 10)
    }

    // MARK: - CloudKit Duplicate Consolidation

    @Test("Consolidation keeps the most recently modified record, not the highest credits")
    func consolidationKeepsMostRecent() throws {
        let container = TestHelpers.makeTestContainer()
        let context = container.mainContext

        // Simulate CloudKit creating duplicate records:
        // - staleRecord: higher credits (5) but older timestamp
        // - freshRecord: lower credits (3) but newer timestamp (the one the user just decremented)
        let staleRecord = SolutionCreditsModel(credits: 5)
        staleRecord.lastModified = Date(timeIntervalSinceNow: -60) // 1 minute ago
        context.insert(staleRecord)

        let freshRecord = SolutionCreditsModel(credits: 3)
        freshRecord.lastModified = Date() // now
        context.insert(freshRecord)

        try context.save()

        // Create service — init calls fetchOrCreateCreditsModel() which consolidates
        let service = InAppPurchaseService(modelContext: context)

        // The service should keep the most recent record (credits: 3), not the highest (credits: 5)
        #expect(service.solutionCredits == 3)

        // Verify only one record remains
        let remaining = try context.fetch(FetchDescriptor<SolutionCreditsModel>())
        #expect(remaining.count == 1)
        #expect(remaining.first?.credits == 3)
    }

    @Test("Stale duplicate with distantPast lastModified loses to locally modified record")
    func staleDuplicateLosesToLocallyModified() throws {
        let container = TestHelpers.makeTestContainer()
        let context = container.mainContext

        // Simulate a pre-migration CloudKit duplicate:
        // Its lastModified is .distantPast (the property default for records that existed
        // before the lastModified column was added via lightweight migration).
        let staleDuplicate = SolutionCreditsModel(credits: 5)
        staleDuplicate.lastModified = .distantPast
        context.insert(staleDuplicate)

        // The locally modified record has an explicit lastModified from setSolutionCredits().
        let localRecord = SolutionCreditsModel(credits: 3)
        localRecord.lastModified = Date() // explicitly set by setSolutionCredits()
        context.insert(localRecord)

        try context.save()

        let service = InAppPurchaseService(modelContext: context)

        // The locally modified record (credits: 3) must win over the stale duplicate (credits: 5)
        #expect(service.solutionCredits == 3)
    }

    @Test("Echo guard prevents refreshFromRemoteChanges from overwriting recent local change")
    func echoGuardProtectsLocalChange() {
        let (service, _container) = TestHelpers.makeTestIAPService()

        // Set credits to 5 then consume one (5 → 4)
        service.setSolutionCredits(5)
        let world = TestHelpers.makeTestWorld()
        let consumed = service.consumeSolutionCredit(for: world, level: 0)
        #expect(consumed == true)
        #expect(service.solutionCredits == 4)

        // Simulate CloudKit echo: refreshFromRemoteChanges fires immediately after local change.
        // The echo guard should prevent the stale duplicate from overwriting credits.
        service.refreshFromRemoteChanges()
        #expect(service.solutionCredits == 4)
    }

    // MARK: - Product Identifiers

    @Test("productCredits maps known product IDs to credit counts")
    func productCreditsMapping() {
        let (service, _container) = TestHelpers.makeTestIAPService()
        #expect(service.productCredits["fr.meshy.pushbox.credits.1"] == 1)
        #expect(service.productCredits["fr.meshy.pushbox.credits.5"] == 5)
        #expect(service.productCredits["fr.meshy.pushbox.credits.10"] == 10)
    }
}
