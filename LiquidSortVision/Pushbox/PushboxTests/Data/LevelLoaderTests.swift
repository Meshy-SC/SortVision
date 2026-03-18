// LevelLoaderTests.swift
// Tests for the LevelLoader service.

import Testing
import Foundation
@testable import Pushbox

@Suite("LevelLoader")
@MainActor
struct LevelLoaderTests {

    @Test("Cache starts empty")
    func cacheStartsEmpty() {
        let loader = LevelLoader()
        #expect(loader.cache.isEmpty)
    }

    @Test("Loading levels for non-existent world throws levelFileNotFound")
    func loadNonExistentWorld() async {
        let loader = LevelLoader()
        do {
            _ = try await loader.loadLevels(for: "NonExistentWorld")
            Issue.record("Expected GameError.levelFileNotFound to be thrown")
        } catch let error as GameError {
            if case .levelFileNotFound(let worldName) = error {
                #expect(worldName == "NonExistentWorld")
            } else {
                Issue.record("Wrong GameError case: \(error)")
            }
        } catch {
            Issue.record("Wrong error type: \(error)")
        }
    }

    @Test("Loading World1 returns non-empty level data", .tags(.integration))
    func loadWorld1() async throws {
        let loader = LevelLoader()
        let levels = try await loader.loadLevels(for: "World1")
        #expect(!levels.isEmpty)
    }

    @Test("Loaded levels are cached for subsequent calls", .tags(.integration))
    func cachingWorks() async throws {
        let loader = LevelLoader()
        let first = try await loader.loadLevels(for: "World1")
        #expect(loader.cache["World1"] != nil)

        // Second call should return cached data
        let second = try await loader.loadLevels(for: "World1")
        #expect(first.count == second.count)
    }

    @Test("Each loaded level has at least one row", .tags(.integration))
    func levelsHaveRows() async throws {
        let loader = LevelLoader()
        let levels = try await loader.loadLevels(for: "World1")
        for (index, level) in levels.enumerated() {
            #expect(!level.isEmpty, "Level \(index) has no rows")
        }
    }

    @Test("Level count matches world metadata", .tags(.integration))
    func levelCountMatchesMetadata() async throws {
        let loader = LevelLoader()
        for world in World.allWorlds {
            let levels = try await loader.loadLevels(for: world.worldName)
            #expect(
                levels.count == world.levelCount,
                "World \(world.worldName): loaded \(levels.count) levels, expected \(world.levelCount)"
            )
        }
    }
}
