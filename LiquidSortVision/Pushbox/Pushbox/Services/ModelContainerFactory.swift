// ModelContainerFactory.swift
// Centralized SwiftData + CloudKit container configuration.
// Eliminates triplication across PushboxApp, iOSApp, and macOSApp entry points.

import Foundation
import SwiftData

// MARK: - ModelContainerFactory

/// Creates and configures the shared SwiftData `ModelContainer` with CloudKit sync.
///
/// The factory encapsulates all schema registration and CloudKit configuration
/// in one place. Each platform's `@main` App struct calls `makeContainer()`
/// instead of duplicating the setup.
///
/// - **Primary store**: CloudKit-backed private database (`iCloud.meshy.pushbox`)
/// - **Fallback store**: In-memory (if CloudKit setup fails at launch)
enum ModelContainerFactory {
    
    /// The complete SwiftData schema used by the app.
    private static let schema = Schema([
        LevelProgressModel.self,
        UnlockedSolutionModel.self,
        SolutionCreditsModel.self,
        ProcessedTransactionModel.self
    ])
    
    /// CloudKit container identifier shared across all platforms.
    private static let cloudKitDatabaseName = "iCloud.meshy.pushbox"
    
    /// Creates a configured `ModelContainer` with CloudKit sync.
    ///
    /// On failure, falls back to an in-memory store so the app
    /// can still launch (progress just won't persist or sync).
    ///
    /// - Returns: A fully configured `ModelContainer`.
    static func makeContainer() -> ModelContainer {
        let configuration = ModelConfiguration(
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .private(cloudKitDatabaseName)
        )
        
        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            AppLogger.general.error(
                "CloudKit container failed, using in-memory fallback: \(error.localizedDescription)"
            )
            let fallback = ModelConfiguration(isStoredInMemoryOnly: true)
            do {
                return try ModelContainer(for: schema, configurations: [fallback])
            } catch {
                // In-memory container creation should never fail, but if it does
                // there is no meaningful recovery — the app cannot function without data storage.
                fatalError("Failed to create even an in-memory ModelContainer: \(error.localizedDescription)")
            }
        }
    }
    
    /// Creates an in-memory `ModelContainer` for SwiftUI previews and unit tests.
    ///
    /// - Returns: A `ModelContainer` that stores data only in memory.
    static func makePreviewContainer() -> ModelContainer {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        return try! ModelContainer(for: schema, configurations: [configuration])
    }
}
