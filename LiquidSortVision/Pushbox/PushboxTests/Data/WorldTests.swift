// WorldTests.swift
// Tests for the World model.

import Testing
import Foundation
@testable import Pushbox

@Suite("World")
struct WorldTests {

    @Test("Initialization stores all properties")
    func initialization() {
        let world = World(
            worldName: "World1",
            title: "Iron",
            subtitle: "Forged in determination",
            optimalPushCounts: [5, 10, 15]
        )
        #expect(world.worldName == "World1")
        #expect(world.title == "Iron")
        #expect(world.subtitle == "Forged in determination")
        #expect(world.optimalPushCounts == [5, 10, 15])
        #expect(world.solutions == nil)
    }

    @Test("id equals worldName for Identifiable conformance")
    func idEqualsWorldName() {
        let world = World(worldName: "TestWorld", title: "T", subtitle: "S", optimalPushCounts: [])
        #expect(world.id == "TestWorld")
    }

    @Test("levelCount equals the number of optimal push counts")
    func levelCount() {
        let world = World(worldName: "W", title: "T", subtitle: "S", optimalPushCounts: [1, 2, 3, 4])
        #expect(world.levelCount == 4)
    }

    @Test("Empty world has zero levels")
    func emptyWorldLevelCount() {
        let world = World(worldName: "W", title: "T", subtitle: "S", optimalPushCounts: [])
        #expect(world.levelCount == 0)
    }

    @Test("Codable round-trip preserves all properties")
    func codableRoundTrip() throws {
        let original = World(
            worldName: "World2",
            title: "Bronze",
            subtitle: "A sharper edge",
            optimalPushCounts: [8, 12, 20],
            solutions: nil
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(World.self, from: data)
        #expect(decoded == original)
    }

    @Test("Codable round-trip with solutions")
    func codableWithSolutions() throws {
        let original = World(
            worldName: "W",
            title: "T",
            subtitle: "S",
            optimalPushCounts: [5],
            solutions: ["encrypted_data"]
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(World.self, from: data)
        #expect(decoded.solutions == ["encrypted_data"])
    }

    @Test("decryptedSolutions returns nil when no solutions exist")
    func noSolutionsReturnsNil() {
        let world = World(worldName: "W", title: "T", subtitle: "S", optimalPushCounts: [5])
        #expect(world.decryptedSolutions == nil)
    }

    @Test("decryptedSolutions decrypts encrypted solutions")
    func decryptsSolutions() {
        let plaintext = "udlr"
        guard let encrypted = SolutionCrypto.encrypt(plaintext) else {
            Issue.record("Failed to encrypt test solution")
            return
        }
        let world = World(
            worldName: "W", title: "T", subtitle: "S",
            optimalPushCounts: [5],
            solutions: [encrypted]
        )
        let decrypted = world.decryptedSolutions
        #expect(decrypted?.first == plaintext)
    }

    @Test("allWorlds loads real world data from bundle", .tags(.integration))
    func allWorldsLoaded() {
        #expect(!World.allWorlds.isEmpty)
        #expect(World.allWorlds.count >= 10)
    }

    @Test("totalLevelsPerWorld has entries for all worlds", .tags(.integration))
    func totalLevelsPerWorldPopulated() {
        for world in World.allWorlds {
            #expect(World.totalLevelsPerWorld[world.worldName] != nil)
            #expect(World.totalLevelsPerWorld[world.worldName] == world.levelCount)
        }
    }

    @Test("Equality: worlds with same properties are equal")
    func equality() {
        let a = World(worldName: "W1", title: "T", subtitle: "S", optimalPushCounts: [5])
        let b = World(worldName: "W1", title: "T", subtitle: "S", optimalPushCounts: [5])
        #expect(a == b)
    }

    @Test("Equality: worlds with different names are not equal")
    func inequalityByName() {
        let a = World(worldName: "W1", title: "T", subtitle: "S", optimalPushCounts: [5])
        let b = World(worldName: "W2", title: "T", subtitle: "S", optimalPushCounts: [5])
        #expect(a != b)
    }
}

// MARK: - Custom Tags

extension Tag {
    @Tag static var integration: Self
}
