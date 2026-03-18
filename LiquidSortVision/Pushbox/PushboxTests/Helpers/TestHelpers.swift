// TestHelpers.swift
// Shared test utilities for PushBox tests.

import Testing
import Foundation
import SwiftData
@testable import Pushbox

// MARK: - Test Helpers

/// Shared utilities for creating test fixtures and in-memory persistence stores.
@MainActor
enum TestHelpers {

    // MARK: - SwiftData

    /// Creates an in-memory ModelContainer for testing.
    static func makeTestContainer() -> ModelContainer {
        ModelContainerFactory.makePreviewContainer()
    }

    // MARK: - Services

    /// Creates a ProgressService backed by an in-memory store.
    static func makeTestProgressService() -> (service: ProgressService, container: ModelContainer) {
        let container = makeTestContainer()
        let service = ProgressService(modelContext: container.mainContext)
        return (service, container)
    }

    /// Creates an InAppPurchaseService backed by an in-memory store.
    static func makeTestIAPService() -> (service: InAppPurchaseService, container: ModelContainer) {
        let container = makeTestContainer()
        let service = InAppPurchaseService(modelContext: container.mainContext)
        return (service, container)
    }

    /// Creates an AppModel backed by an in-memory store.
    static func makeTestAppModel() -> AppModel {
        let container = makeTestContainer()
        return AppModel(modelContext: container.mainContext)
    }

    // MARK: - Fixtures

    /// Creates a test World with configurable parameters.
    static func makeTestWorld(
        worldName: String = "TestWorld",
        title: String = "Test",
        subtitle: String = "Testing",
        optimalPushCounts: [Int] = [5, 10, 15],
        solutions: [String]? = nil
    ) -> World {
        World(
            worldName: worldName,
            title: title,
            subtitle: subtitle,
            optimalPushCounts: optimalPushCounts,
            solutions: solutions
        )
    }

    /// Creates a test World with encrypted solutions for solution playback tests.
    static func makeTestWorldWithSolutions(
        worldName: String = "TestWorld",
        plaintextSolutions: [String] = ["udlr", "rrdd", "lluu"]
    ) -> World {
        let encrypted = plaintextSolutions.compactMap { SolutionCrypto.encrypt($0) }
        return World(
            worldName: worldName,
            title: "Test",
            subtitle: "Testing",
            optimalPushCounts: Array(repeating: 5, count: plaintextSolutions.count),
            solutions: encrypted
        )
    }
}
