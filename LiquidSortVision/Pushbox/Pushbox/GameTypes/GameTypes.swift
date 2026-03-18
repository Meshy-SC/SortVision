// GameTypes.swift
// Core game types and data structures.

import RealityKit
import Foundation

// MARK: - GridPosition

/// Represents a discrete position on the puzzle grid.
///
/// The coordinate system matches standard matrix indexing:
/// - ``row`` increases **downward** (maps to positive Z in RealityKit).
/// - ``column`` increases **rightward** (maps to positive X in RealityKit).
///
/// Conforms to `Hashable` and `Sendable` for use as dictionary keys and in concurrent contexts.
struct GridPosition: Hashable, Equatable, Codable, Sendable {
    /// The row index (vertical position). `0` is the top row.
    let row: Int
    
    /// The column index (horizontal position). `0` is the leftmost column.
    let column: Int
    
    /// Creates a new grid position.
    /// - Parameters:
    ///   - row: The row index.
    ///   - column: The column index.
    init(row: Int, column: Int) {
        self.row = row
        self.column = column
    }
}

// MARK: - CellContent

/// Represents what occupies a single grid cell in the puzzle.
/// Each cell can contain exactly one of these elements.
///
/// `@MainActor`-isolated because associated `Entity` values
/// are RealityKit objects that must be accessed on the main actor.
@MainActor
enum CellContent {
    /// An empty floor tile that can be walked on.
    case empty
    
    /// A wall that blocks movement.
    /// - Parameter entity: The RealityKit wall entity.
    case wall(Entity)
    
    /// A movable box that has not yet reached a slot.
    /// - Parameter entity: The RealityKit box entity.
    case box(Entity)
    
    /// A box that is currently positioned on a target slot.
    /// - Parameter entity: The RealityKit box entity.
    case boxOnSlot(Entity)
    
    /// The player character.
    /// - Parameter entity: The RealityKit player entity.
    case player(Entity)
    
    /// An empty slot (target position for boxes).
    /// - Parameter entity: The RealityKit slot entity.
    case slot(Entity)
    
    // MARK: - Computed Properties
    
    /// The RealityKit entity associated with this cell content, if any.
    /// Returns `nil` for `.empty` cells.
    var entity: Entity? {
        switch self {
        case .empty:               nil
        case .wall(let e):         e
        case .box(let e):          e
        case .boxOnSlot(let e):    e
        case .player(let e):       e
        case .slot(let e):         e
        }
    }
    
    /// Whether the cell can be walked onto by the player (empty floor or slot).
    var isWalkable: Bool {
        switch self {
        case .empty, .slot: true
        default:            false
        }
    }
    
    /// Whether the cell contains a box (regular or on-slot).
    var isBox: Bool {
        switch self {
        case .box, .boxOnSlot: true
        default:               false
        }
    }
    
    /// Extracts the box entity if this cell contains one, otherwise `nil`.
    var boxEntity: Entity? {
        switch self {
        case .box(let e), .boxOnSlot(let e): e
        default:                              nil
        }
    }
    
    /// Whether this cell is a box that is currently on a slot.
    var isBoxOnSlot: Bool {
        if case .boxOnSlot = self { return true }
        return false
    }
    
    /// Whether this cell is a wall.
    var isWall: Bool {
        if case .wall = self { return true }
        return false
    }
}

// MARK: - MoveRecord

/// Records a single player move for undo functionality.
/// Stores all state necessary to fully reverse the move.
///
/// `@MainActor`-isolated because `boxEntity` is a RealityKit `Entity`
/// that must be accessed on the main actor.
@MainActor
struct MoveRecord {
    
    // MARK: Player Movement
    
    /// The grid position the player moved from.
    let playerFrom: GridPosition
    
    /// The grid position the player moved to.
    let playerTo: GridPosition
    
    /// The player's rotation before this move (used to restore facing direction on undo).
    let playerRotation: simd_quatf
    
    // MARK: Box Movement
    
    /// Whether a box was pushed during this move.
    let didPushBox: Bool
    
    /// The box entity that was pushed (if any).
    let boxEntity: Entity?
    
    /// The position the box moved from (if pushed).
    let boxFrom: GridPosition?
    
    /// The position the box moved to (if pushed).
    let boxTo: GridPosition?
    
    /// Whether the box was on a slot before being pushed.
    /// Used to restore the correct cell state on undo.
    let wasBoxOnSlot: Bool
    
    // MARK: Initialization
    
    /// Creates a new move record.
    /// - Parameters:
    ///   - playerFrom: The player's starting position.
    ///   - playerTo: The player's ending position.
    ///   - didPushBox: Whether a box was pushed.
    ///   - boxEntity: The pushed box entity (if any).
    ///   - boxFrom: The box's starting position (if pushed).
    ///   - boxTo: The box's ending position (if pushed).
    ///   - wasBoxOnSlot: Whether the box was on a slot before being pushed.
    ///   - playerRotation: The player's rotation before the move.
    init(playerFrom: GridPosition,
         playerTo: GridPosition,
         didPushBox: Bool,
         boxEntity: Entity? = nil,
         boxFrom: GridPosition? = nil,
         boxTo: GridPosition? = nil,
         wasBoxOnSlot: Bool = false,
         playerRotation: simd_quatf) {
        self.playerFrom = playerFrom
        self.playerTo = playerTo
        self.didPushBox = didPushBox
        self.boxEntity = boxEntity
        self.boxFrom = boxFrom
        self.boxTo = boxTo
        self.wasBoxOnSlot = wasBoxOnSlot
        self.playerRotation = playerRotation
    }
}
