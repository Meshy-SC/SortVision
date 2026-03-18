// World.swift
// Represents a game world with metadata and level data.

import Foundation

/// Represents a game world with a stable identifier, its optimal push counts, and (optional) per‑level solution strings.
/// Thread-safe and suitable for concurrent access.
struct World: Identifiable, Hashable, Codable, Sendable, Equatable {
    /// Unique identifier for the world (e.g., "World1").
    let worldName: String
    
    /// Display title for the world (e.g., "Iron").
    let title: String
    
    /// Subtitle/description for the world (e.g., "Beginning").
    let subtitle: String
    
    /// Optimal push count for each level.
    let optimalPushCounts: [Int]
    
    /// Encrypted solution strings for each level (Base64-encoded AES-GCM ciphertext).
    /// Use `decryptedSolutions` to access the plaintext solution moves.
    let solutions: [String]?
    
    /// Decrypts the encrypted solution strings on demand.
    /// Returns `nil` if no solutions are available for this world.
    /// Solutions that fail to decrypt are replaced with empty strings.
    var decryptedSolutions: [String]? {
        guard let solutions else { return nil }
        return SolutionCrypto.decryptAll(solutions)
    }
    
    // MARK: - Coding Keys
    
    /// Explicit coding keys for encoding stability.
    /// Protects against accidental JSON breakage if properties are renamed.
    private enum CodingKeys: String, CodingKey {
        case worldName
        case title
        case subtitle
        case optimalPushCounts
        case solutions
    }
    
    /// Conformance to Identifiable.
    var id: String { worldName }
    
    /// Memberwise initializer for creating World instances.
    init(worldName: String, title: String, subtitle: String, optimalPushCounts: [Int], solutions: [String]? = nil) {
        self.worldName = worldName
        self.title = title
        self.subtitle = subtitle
        self.optimalPushCounts = optimalPushCounts
        self.solutions = solutions
    }
    
    /// Number of levels in this world.
    var levelCount: Int { optimalPushCounts.count }
}

// MARK: - World Loading

extension World {
    /// All worlds, loaded once at static initialization.
    static let allWorlds: [World] = WorldDataLoader.shared.loadAllWorlds()
    
    /// Level count per world name, precomputed once. Used by AppModel, ProgressService, and UI.
    static let totalLevelsPerWorld: [String: Int] = Dictionary(
        uniqueKeysWithValues: allWorlds.map { ($0.worldName, $0.levelCount) }
    )
}
