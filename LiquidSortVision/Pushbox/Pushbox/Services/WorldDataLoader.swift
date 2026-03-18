// WorldDataLoader.swift
// Service responsible for loading world data from JSON files.

import Foundation

// MARK: - WorldDataLoader

/// Service responsible for loading world data from JSON files.
/// Caches loaded data to avoid repeated file I/O.
/// Uses `World` directly for JSON decoding since it now conforms to `Codable`.
///
/// Thread-safety: `loadAllWorlds()` is called exactly once from `World.allWorlds`
/// (`static let` uses `dispatch_once` semantics). After initialization, `cache`
/// and `allWorlds` are effectively immutable. Marked `@unchecked Sendable`
/// because mutable state is only written during one-time initialization.
final class WorldDataLoader: @unchecked Sendable {
    
    // MARK: - Singleton
    
    /// Singleton instance. Access is thread-safe due to Swift's `static let` guarantees.
    static let shared = WorldDataLoader()
    
    // MARK: - Properties
    
    /// Cache for loaded world data.
    /// Key: world name, Value: world object
    private(set) var cache: [String: World] = [:]
    
    /// List of all loaded worlds.
    private(set) var allWorlds: [World] = []
    
    // MARK: - Initialization
    
    private init() {}
    
    // MARK: - Public Methods
    
    /// Loads data for a given world from its JSON file.
    /// Uses cached data if available.
    ///
    /// - Parameter worldName: The world's name (matches the JSON filename).
    /// - Returns: The world object containing metadata and level info.
    /// - Throws: `GameError.levelFileNotFound` if the JSON file doesn't exist,
    ///           `GameError.levelFileParsingFailed` if parsing fails.
    func loadWorldData(for worldName: String) throws -> World {
        // Return cached data if available
        if let cached = cache[worldName] {
            return cached
        }
        
        // Find the JSON file in the bundle
        guard let url = Bundle.main.url(forResource: "\(worldName)Data", withExtension: "json") else {
            throw GameError.levelFileNotFound(worldName: "\(worldName)Data.json")
        }
        
        // Load and parse the JSON
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            throw GameError.levelFileParsingFailed(worldName: worldName, underlyingErrorDescription: error.localizedDescription)
        }
        
        let world: World
        do {
            world = try JSONDecoder().decode(World.self, from: data)
        } catch {
            throw GameError.levelFileParsingFailed(worldName: worldName, underlyingErrorDescription: error.localizedDescription)
        }
        
        // Cache and return
        cache[worldName] = world
        return world
    }
    
    /// Loads all worlds from JSON files and returns them.
    /// This should be called once at app startup.
    ///
    /// - Returns: Array of all loaded World objects.
    func loadAllWorlds() -> [World] {
        let worldNames = ["World1", "World2", "World3", "World4", "World5", "World6", "World7", "World8", "World9", "World10"]
        let worlds = worldNames.compactMap { name -> World? in
            do {
                return try loadWorldData(for: name)
            } catch {
                AppLogger.levels.warning("Failed to load \(name): \(error.localizedDescription)")
                return nil
            }
        }
        
        allWorlds = worlds
        return worlds
    }
}
