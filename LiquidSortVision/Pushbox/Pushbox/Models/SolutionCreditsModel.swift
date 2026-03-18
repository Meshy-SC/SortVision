// SolutionCreditsModel.swift
// SwiftData model for persisting solution credits with CloudKit sync.

import Foundation
import SwiftData

// MARK: - SolutionCreditsModel

/// SwiftData model for storing the user's solution credit balance.
/// Uses a singleton record pattern (single row with a fixed key).
/// Replaces @AppStorage("solutionCredits") to enable iCloud sync via CloudKit.
///
/// Indexed on `id` for efficient singleton record lookups after CloudKit merges.
@Model
final class SolutionCreditsModel {
    
    #Index<SolutionCreditsModel>([\.id])
    
    /// Fixed identifier for the singleton record.
    /// Default value required for CloudKit compatibility.
    var id: String = "default"
    
    /// Current number of solution credits.
    /// Default value required for CloudKit compatibility.
    var credits: Int = 1

    /// Timestamp of the last credit mutation.
    /// Used to resolve CloudKit duplicate consolidation: most-recently-modified wins.
    /// Default value required for CloudKit compatibility.
    ///
    /// Uses `.distantPast` as the property default so that records arriving from CloudKit
    /// (which have NULL for this column after lightweight migration) are always treated as
    /// older than any record explicitly modified by the app. The `init` sets this to `Date()`
    /// for newly created records.
    var lastModified: Date = Date.distantPast

    // MARK: - Initialization

    init(id: String = "default", credits: Int = 1) {
        self.id = id
        self.credits = credits
        self.lastModified = Date()
    }
}
