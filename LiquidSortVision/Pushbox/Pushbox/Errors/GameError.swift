// GameError.swift
// Centralized error types for the PushBox game.

import Foundation

// MARK: - GameError

/// Centralized error types for game operations.
/// Provides descriptive error messages for debugging and user feedback.
///
/// All associated values are `Sendable` (`String` only), so the enum
/// conforms to `Sendable` without escape hatches.
@frozen
public enum GameError: LocalizedError, Sendable {
    
    // MARK: - Level Loading Errors
    
    /// The level file for the specified world was not found in the bundle.
    case levelFileNotFound(worldName: String)
    
    /// The level file could not be read or parsed.
    case levelFileParsingFailed(worldName: String, underlyingErrorDescription: String)
    
    /// No levels were found in the specified world file.
    case emptyWorldFile(worldName: String)
    
    // MARK: - LocalizedError Conformance
    
    public var errorDescription: String? {
        switch self {
        case .levelFileNotFound(let worldName):
            return "Level file not found for world: \(worldName)"
            
        case .levelFileParsingFailed(let worldName, let description):
            return "Failed to parse level file for \(worldName): \(description)"
            
        case .emptyWorldFile(let worldName):
            return "No levels found in world file: \(worldName)"
        }
    }
    
    public var recoverySuggestion: String? {
        switch self {
        case .levelFileNotFound:
            return "Ensure the level file is included in the app bundle."
            
        case .levelFileParsingFailed:
            return "The level file may be corrupted. Try reinstalling the app."
            
        case .emptyWorldFile:
            return "The world file appears to be empty. Try reinstalling the app."
        }
    }
}
