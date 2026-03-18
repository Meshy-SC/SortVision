// LevelLoader.swift
// Responsible for loading and parsing level files asynchronously, with caching.

import Foundation

// MARK: - LevelLoader

/// Service responsible for loading and caching game levels from bundle resources.
/// Parses world JSON files containing ASCII level representations.
///
/// Level JSON files contain a `levels` array, where each element is an array
/// of row strings representing a single level.
///
/// Characters represent game elements:
///   - `#` = Wall
///   - `@` = Player
///   - `+` = Player on slot
///   - `.` = Slot (target)
///   - `$` = Box
///   - `*` = Box on slot
///   - ` ` (space) = Empty floor
@MainActor
final class LevelLoader {
    

    // MARK: - Types
    
    /// Decodable wrapper for the JSON level file format.
    private struct WorldFile: Decodable {
        let levels: [[String]]
    }
    
    // MARK: - Properties
    
    /// Cache to avoid reloading levels from disk.
    /// Key: world name, Value: array of levels (each level is an array of row strings)
    private(set) var cache: [String: [[String]]] = [:]
    
    // MARK: - Initialization
    
    init() {}
    
    // MARK: - Public Methods
    
    /// Loads levels for a given world from a JSON file.
    /// Uses cached data if available.
    ///
    /// - Parameter worldName: The world's name (matches the filename without extension).
    /// - Returns: An array of levels, where each level is an array of row strings.
    /// - Throws: `GameError.levelFileNotFound` if the file doesn't exist,
    ///           `GameError.levelFileParsingFailed` if reading/decoding fails,
    ///           `GameError.emptyWorldFile` if no valid levels are found.
    func loadLevels(for worldName: String) async throws -> [[String]] {
        // Return cached data if available
        if let cached = cache[worldName] {
            return cached
        }
        
        // Find the level file in the bundle
        guard let url = Bundle.main.url(forResource: worldName, withExtension: "json") else {
            throw GameError.levelFileNotFound(worldName: worldName)
        }
        
        // Read and decode the JSON file off the main actor
        let levels: [[String]]
        do {
            levels = try await Task.detached {
                let data = try Data(contentsOf: url)
                let worldFile = try JSONDecoder().decode(WorldFile.self, from: data)
                return worldFile.levels.filter { Self.isValidLevel($0) }
            }.value
        } catch {
            throw GameError.levelFileParsingFailed(worldName: worldName, underlyingErrorDescription: error.localizedDescription)
        }
        
        // Validate we got at least one level
        guard !levels.isEmpty else {
            throw GameError.emptyWorldFile(worldName: worldName)
        }
        
        // Cache and return
        cache[worldName] = levels
        return levels
    }
    
    // MARK: - Private Methods

    /// Validates that a level contains required game elements.
    /// A valid level must have:
    /// - Exactly one player (@ or +)
    /// - At least one box ($ or *)
    /// - Equal number of boxes and slots
    /// - Parameter lines: The level lines to validate.
    /// - Returns: true if the level is valid.
    private nonisolated static func isValidLevel(_ lines: [String]) -> Bool {
        // Single-pass counting — replaces three separate filter().count traversals.
        var playerCount = 0, boxCount = 0, slotCount = 0
        for char in lines.joined() {
            switch char {
            case "@":  playerCount += 1
            case "+":  playerCount += 1; slotCount += 1
            case "$":  boxCount += 1
            case "*":  boxCount += 1; slotCount += 1
            case ".": slotCount += 1
            default:   break
            }
        }

        guard playerCount == 1 else {
            AppLogger.levels.warning("Invalid level: expected 1 player, found \(playerCount)")
            return false
        }

        guard boxCount > 0 else {
            AppLogger.levels.warning("Invalid level: no boxes found")
            return false
        }

        guard slotCount == boxCount else {
            AppLogger.levels.warning("Invalid level: \(boxCount) boxes but \(slotCount) slots")
            return false
        }

        return true
    }
}
