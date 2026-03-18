// GameSceneView+LevelBuilder.swift
// Constructs RealityKit Entity hierarchies from ASCII level descriptions.

import SwiftUI
import RealityKit

// MARK: - Level Construction

extension GameSceneView {

    /// Builds an Entity hierarchy from the ASCII level description.
    ///
    /// This method parses the level lines and creates the corresponding RealityKit entities:
    /// - `#` = Wall, `@` = Player, `+` = Player on slot
    /// - `.` = Empty slot, `$` = Box, `*` = Box on slot (arrived)
    ///
    /// - Parameters:
    ///   - lines: Array of strings representing the level rows.
    ///   - wall: Template entity to clone for walls.
    ///   - player: Template entity to clone for the player.
    ///   - slot: Template entity to clone for slots.
    ///   - box: Template entity to clone for boxes.
    /// - Returns: The root Entity containing the complete level hierarchy.
    func buildLevel(from lines: [String],
                    wall: Entity,
                    player: Entity,
                    slot: Entity,
                    box: Entity) -> Entity {

        let root = Entity()

        // Reset per-level caches
        puzzleGrid.removeAll()
        slotPositions.removeAll()
        slotEntities.removeAll()
        totalBoxCount = 0
        arrivedBoxCount = 0
        moveHistory = []
        isLevelCompleted = false
        playerGridPosition = nil

        // Guard against empty or invalid level data
        let maxColumns = lines.map(\.count).max() ?? 0
        guard !lines.isEmpty, maxColumns > 0 else {
            AppLogger.levels.error("Cannot build level: empty or invalid level data")
            return root
        }

        // Create backing grid big enough for ragged rows
        puzzleGrid = Array(repeating: Array(repeating: .empty,
                                            count: maxColumns),
                           count: lines.count)

        // Step through every character and create corresponding entities
        for (rowIndex, line) in lines.enumerated() {
            for (columnIndex, character) in line.enumerated() {
                let xPosition = Float(columnIndex) * GameLayout.cellSize
                let zPosition = Float(rowIndex) * GameLayout.cellSize
                let gridPosition = GridPosition(row: rowIndex, column: columnIndex)

                switch character {
                case "#":
                    // Wall
                    let wallEntity = wall.clone(recursive: true)
                    wallEntity.position = [xPosition, 0, zPosition]
                    root.addChild(wallEntity)
                    puzzleGrid[rowIndex][columnIndex] = .wall(wallEntity)

                case "@":
                    // Player
                    let playerClone = player.clone(recursive: true)
                    playerClone.position = [xPosition, 0, zPosition]
                    root.addChild(playerClone)
                    puzzleGrid[rowIndex][columnIndex] = .player(playerClone)
                    playerEntity = playerClone
                    playerGridPosition = gridPosition

                case "+":
                    // Player on slot
                    let slotEntity = slot.clone(recursive: true)
                    slotEntity.position = [xPosition, 0, zPosition]
                    root.addChild(slotEntity)
                    slotPositions.insert(gridPosition)
                    slotEntities[gridPosition] = slotEntity
                    
                    let playerClone = player.clone(recursive: true)
                    playerClone.position = [xPosition, 0, zPosition]
                    root.addChild(playerClone)
                    puzzleGrid[rowIndex][columnIndex] = .player(playerClone)
                    playerEntity = playerClone
                    playerGridPosition = gridPosition

                case ".":
                    // Empty slot (target)
                    let slotEntity = slot.clone(recursive: true)
                    slotEntity.position = [xPosition, 0, zPosition]
                    root.addChild(slotEntity)
                    slotPositions.insert(gridPosition)
                    slotEntities[gridPosition] = slotEntity
                    puzzleGrid[rowIndex][columnIndex] = .slot(slotEntity)

                case "$":
                    // Box
                    let boxEntity = box.clone(recursive: true)
                    boxEntity.position = [xPosition, 0, zPosition]
                    root.addChild(boxEntity)
                    puzzleGrid[rowIndex][columnIndex] = .box(boxEntity)
                    totalBoxCount += 1

                case "*":
                    // Box already on slot (arrived)
                    let slotEntity = slot.clone(recursive: true)
                    slotEntity.position = [xPosition, 0, zPosition]
                    root.addChild(slotEntity)
                    slotPositions.insert(gridPosition)
                    slotEntities[gridPosition] = slotEntity
                    slotEntity.isEnabled = false
                    
                    let boxEntity = box.clone(recursive: true)
                    boxEntity.position = [xPosition, 0, zPosition]
                    root.addChild(boxEntity)
                    appModel.animationService.updateBoxMaterial(on: boxEntity, isOnSlot: true)
                    puzzleGrid[rowIndex][columnIndex] = .boxOnSlot(boxEntity)
                    totalBoxCount += 1
                    arrivedBoxCount += 1

                default:
                    break
                }
            }
        }

        // Center the whole grid
        let levelWidth = (Float(maxColumns) - 1) * GameLayout.cellSize
        let levelDepth = (Float(lines.count) - 1) * GameLayout.cellSize
        root.position = [-levelWidth / 2,
                         GameLayout.levelYOffset,
                         -levelDepth / 2]
        return root
    }

    // MARK: - Helper Methods

    /// Checks whether a grid position is within the puzzle bounds.
    /// - Parameter position: The grid position to check.
    /// - Returns: `true` if the position is valid, `false` otherwise.
    func isWithinBounds(_ position: GridPosition) -> Bool {
        position.row >= 0 && position.row < puzzleGrid.count &&
        position.column >= 0 && position.column < puzzleGrid[position.row].count
    }
}
