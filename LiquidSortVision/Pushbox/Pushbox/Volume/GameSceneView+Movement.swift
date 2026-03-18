// GameSceneView+Movement.swift
// Player movement logic and undo functionality.

import SwiftUI
import RealityKit

// MARK: - Movement Extension

extension GameSceneView {
    
    // MARK: - Player Movement
    
    /// Attempts to move the player in the specified direction.
    ///
    /// Movement Rules:
    /// 1. Player cannot move while animating or after level completion
    /// 2. Out of bounds movement triggers stuck feedback
    /// 3. Moving into a wall triggers stuck feedback
    /// 4. Moving into a box attempts to push it (if space available)
    /// 5. Valid moves update grid state and record history for undo
    ///
    /// - Parameters:
    ///   - columnDelta: Horizontal movement delta (-1 = left, +1 = right, 0 = none).
    ///   - rowDelta: Vertical movement delta (-1 = up, +1 = down, 0 = none).
    func movePlayer(columnDelta: Int, rowDelta: Int) {
        // Guard: No movement during animation or after completion
        guard !isAnimating, !isLevelCompleted,
              let player = playerEntity,
              let playerPosition = playerGridPosition else { return }
        
        let fromPosition = playerPosition
        let toPosition   = GridPosition(row: playerPosition.row + rowDelta, column: playerPosition.column + columnDelta)
        
        // Guard: Must be within grid bounds
        guard isWithinBounds(toPosition) else {
            appModel.animationService.playStuckAnimation()
            appModel.audioService.playStuckAudio()
            return
        }
        
        // Evaluate target cell and determine if move is valid
        var validMove            = false
        var didPushBox            = false
        var wasBoxOnSlot        = false
        var boxEntity: Entity?   = nil
        var boxFrom:   GridPosition?  = nil
        var boxTo:     GridPosition?  = nil
        
        switch puzzleGrid[toPosition.row][toPosition.column] {
        case .wall:
            // Walls always block movement
            break
            
        case .box(let box), .boxOnSlot(let box):
            // Attempt to push the box
            let boxDestination = GridPosition(row: toPosition.row + rowDelta, column: toPosition.column + columnDelta)
            guard isWithinBounds(boxDestination) else { break }
            
            // Box can only be pushed into walkable cells (empty floor or slot)
            guard puzzleGrid[boxDestination.row][boxDestination.column].isWalkable else { break }
            
                // Box can be pushed - space is available
                validMove  = true
                didPushBox  = true
                boxEntity  = box
                boxFrom    = toPosition
                boxTo      = boxDestination
                
                // Track if box was already on a slot
                wasBoxOnSlot = puzzleGrid[toPosition.row][toPosition.column].isBoxOnSlot
                
                appModel.audioService.playPushBoxAudio()
                
                // Move the box entity
                moveEntity(box, to: boxDestination)
                
                // Update grid state for box destination
                if slotPositions.contains(boxDestination) {
                    // Box arrived on a slot
                    slotEntities[boxDestination]?.isEnabled = false
                    puzzleGrid[boxDestination.row][boxDestination.column] = .boxOnSlot(box)
                    arrivedBoxCount += 1
                    Task {
                        try? await Task.sleep(for: .seconds(GameLayout.arrivalAudioDelay))
                        guard !Task.isCancelled else { return }
                        appModel.audioService.playArrivalAudio()
                    }
                    appModel.animationService.updateBoxMaterial(on: box, isOnSlot: true)
                } else {
                    // Box moved to empty space
                    puzzleGrid[boxDestination.row][boxDestination.column] = .box(box)
                    appModel.animationService.updateBoxMaterial(on: box, isOnSlot: false)
                }
                
                // Update grid state for box origin
                if slotPositions.contains(toPosition) {
                    // Reveal the slot that was under the box
                    slotEntities[toPosition]?.isEnabled = true
                    if let slotEntity = slotEntities[toPosition] {
                        puzzleGrid[toPosition.row][toPosition.column] = .slot(slotEntity)
                    }
                    // Box left a slot
                    if wasBoxOnSlot { arrivedBoxCount -= 1 }
                } else {
                    puzzleGrid[toPosition.row][toPosition.column] = .empty
                    // Box left a slot
                    if wasBoxOnSlot { arrivedBoxCount -= 1 }
                }
            
        case .empty, .slot:
            // Player can walk directly here
            validMove = true
            
        case .player:
            // Shouldn't happen, but ignore
            break
        }
        
        // If no valid move found, play stuck feedback
        guard validMove else {
            appModel.animationService.playStuckAnimation()
            appModel.audioService.playStuckAudio()
            return
        }
        
        // Rotate player to face movement direction
        let previousRotation = player.transform.rotation
        let angle = atan2(Float(columnDelta), Float(rowDelta))
        withAnimation(.linear(duration: GameLayout.animationDuration)) {
            player.transform.rotation = simd_quatf(angle: angle, axis: [0, 1, 0])
        }
        
        // Record move for undo functionality
        let record = MoveRecord(
            playerFrom: fromPosition,
            playerTo: toPosition,
            didPushBox: didPushBox,
            boxEntity: boxEntity,
            boxFrom: boxFrom,
            boxTo: boxTo,
            wasBoxOnSlot: wasBoxOnSlot,
            playerRotation: previousRotation
        )
        moveHistory.append(record)
        
        // Update push count if box was pushed
        if didPushBox { appModel.progressService.incrementPushCount() }
        
        // Play appropriate animation
        didPushBox ? appModel.animationService.playPushingAnimation() : appModel.animationService.playWalkingAnimation()
        
        // Move player entity
        moveEntity(player, to: toPosition)
        if !didPushBox { appModel.audioService.playWalkAudio() }
        
        // Update grid state for player movement
        if slotPositions.contains(fromPosition) {
            slotEntities[fromPosition]?.isEnabled = true
            if let slotEntity = slotEntities[fromPosition] {
                puzzleGrid[fromPosition.row][fromPosition.column] = .slot(slotEntity)
            }
        } else {
            puzzleGrid[fromPosition.row][fromPosition.column] = .empty
        }
        puzzleGrid[toPosition.row][toPosition.column] = .player(player)
        
        // Update tracked player position
        playerGridPosition = toPosition
        
        // Mark as animating and schedule completion check
        isAnimating = true
        Task {
            try? await Task.sleep(for: .seconds(GameLayout.animationDuration))
            guard !Task.isCancelled else { return }
            appModel.animationService.playIdleAnimation()
            isAnimating = false
            checkLevelCompleted()
        }
    }
    
    // MARK: - Entity Movement
    
    /// Moves an entity to a new grid position with animation.
    ///
    /// - Parameters:
    ///   - entity: The entity to move.
    ///   - position: The target grid position.
    ///   - rotation: Optional rotation to apply during movement.
    func moveEntity(_ entity: Entity,
                    to position: GridPosition,
                    withRotation rotation: simd_quatf? = nil) {
        let target = SIMD3<Float>(
            Float(position.column) * GameLayout.cellSize,
            0,
            Float(position.row) * GameLayout.cellSize
        )
        withAnimation(.linear(duration: GameLayout.animationDuration)) {
            entity.transform.translation = target
            if let rotation { entity.transform.rotation = rotation }
        }
    }
    
    // MARK: - Level Completion
    
    /// Checks if all boxes are on slots and triggers level completion if so.
    ///
    /// Completion triggers:
    /// 1. Stops puzzle audio
    /// 2. Shows fireworks particle effect
    /// 3. Plays celebration audio and animation
    /// 4. Records progress
    /// 5. Opens control panel after delay
    func checkLevelCompleted() {
        // Count boxes that are on slots using tracked counter
        guard arrivedBoxCount == totalBoxCount, totalBoxCount > 0 else { return }
        
        // Mark level as completed
        isLevelCompleted = true
        appModel.audioService.stopPuzzleAudio()
        appModel.animationService.startFireworks()
        appModel.audioService.playFireworksAudio()

        // Announce completion to VoiceOver users
        AccessibilityNotification.Announcement("Level completed! \\(appModel.progressService.currentLevelPushes) pushes. Swipe to access Next Level button.")
            .post()

        // Record completion in progress and report to Game Center
        if let world = appModel.activeWorld ?? appModel.selectedWorld,
           let levelIndex = appModel.selectedLevelIndex {
            // Capture push count before completeLevel() potentially modifies state
            let pushCount = appModel.progressService.currentLevelPushes

            appModel.progressService.completeLevel(for: world, levelIndex: levelIndex)

            // Calculate stars earned for the completion overlay
            var earnedStars = 1
            if world.optimalPushCounts.indices.contains(levelIndex) {
                let optimal = world.optimalPushCounts[levelIndex]
                let twoStarThreshold = Int(ceil(Double(optimal) * 1.2))
                if pushCount <= optimal {
                    earnedStars = 3
                } else if pushCount <= twoStarThreshold {
                    earnedStars = 2
                }
            }

            // Calculate score gained for this level
            let levelScore: Int
            switch earnedStars {
            case 3: levelScore = 10
            case 2: levelScore = 7
            default: levelScore = 5
            }

            // Store completion data for the overlay
            completionStars = earnedStars
            completionScoreGained = levelScore
            completionTotalScore = appModel.progressService.globalScore
            completionPushCount = pushCount
            completionParPushes = world.optimalPushCounts.indices.contains(levelIndex)
                ? world.optimalPushCounts[levelIndex]
                : nil

            // Submit global score
            appModel.gameCenterService.submitScore(appModel.progressService.globalScore)

            // Submit per-world score (for challenge leaderboards)
            let worldScore = GameCenterService.worldScore(
                for: world.worldName,
                from: appModel.progressService.progress
            )
            appModel.gameCenterService.submitWorldScore(worldScore, worldName: world.worldName)

            // Check and report achievement progress
            appModel.gameCenterService.checkAndReportAchievements(
                progress: appModel.progressService.progress
            )
        }
        
        // Play celebration
        appModel.animationService.playPuzzleSolvedAnimation()
        appModel.audioService.playPuzzleSolvedAudio()
        isAnimating = true
        
        // Show completion overlay after a short celebration delay
        Task {
            try? await Task.sleep(for: .seconds(GameLayout.celebrationOverlayDelay))
            guard !Task.isCancelled else { return }

            // Show the 2D completion overlay with stars and score
            showCompletionOverlay = true
        }
    }
    
    // MARK: - Undo
    
    /// Undoes the last player move, restoring all state.
    ///
    /// Undo restores:
    /// 1. Player position and rotation
    /// 2. Box position (if pushed)
    /// 3. Grid cell states
    /// 4. Push count
    ///
    /// - Note: Undo is disabled during animations and after level completion
    ///   to prevent corrupting the completed state during celebration.
    func undoMove() {
        guard !isAnimating, !isLevelCompleted, let last = moveHistory.popLast() else { return }
        
        appModel.audioService.playUndoAudio()
        if last.didPushBox { appModel.progressService.decrementPushCount() }
        isAnimating = true
        
        // Restore player position
        if let player = playerEntity {
            last.didPushBox ? appModel.animationService.playPushingAnimation() : appModel.animationService.playWalkingAnimation()
            moveEntity(player, to: last.playerFrom, withRotation: last.playerRotation)
            
            // Restore player's previous cell
            if slotPositions.contains(last.playerTo) {
                slotEntities[last.playerTo]?.isEnabled = true
                if let slotEntity = slotEntities[last.playerTo] {
                    puzzleGrid[last.playerTo.row][last.playerTo.column] = .slot(slotEntity)
                }
            } else {
                puzzleGrid[last.playerTo.row][last.playerTo.column] = .empty
            }
            puzzleGrid[last.playerFrom.row][last.playerFrom.column] = .player(player)
            playerGridPosition = last.playerFrom
        }
        
        // Restore box position if one was pushed
        if last.didPushBox,
           let box = last.boxEntity,
           let from = last.boxFrom,
           let to = last.boxTo {
            
            moveEntity(box, to: from)
            
            if slotPositions.contains(to) {
                slotEntities[to]?.isEnabled = true
                if let slotEntity = slotEntities[to] {
                    puzzleGrid[to.row][to.column] = .slot(slotEntity)
                }
                // Box was undone off a slot it had arrived on
                arrivedBoxCount -= 1
            } else {
                puzzleGrid[to.row][to.column] = .empty
            }
            
            // Restore box to its original cell
            if last.wasBoxOnSlot {
                slotEntities[from]?.isEnabled = false
                puzzleGrid[from.row][from.column] = .boxOnSlot(box)
                arrivedBoxCount += 1
                appModel.animationService.updateBoxMaterial(on: box, isOnSlot: true)
                Task {
                    try? await Task.sleep(for: .seconds(GameLayout.arrivalAudioDelay))
                    guard !Task.isCancelled else { return }
                    appModel.audioService.playArrivalAudio()
                }
            } else {
                puzzleGrid[from.row][from.column] = .box(box)
                appModel.animationService.updateBoxMaterial(on: box, isOnSlot: false)
            }
        }
        
        // Complete animation
        Task {
            try? await Task.sleep(for: .seconds(GameLayout.animationDuration))
            guard !Task.isCancelled else { return }
            appModel.animationService.playIdleAnimation()
            isAnimating = false
        }
    }
}

// MARK: - Keyboard Input (visionOS only)
#if os(visionOS)
extension ImmersiveGameView {
    /// Handles keyboard arrow key input by transforming direction based on current viewpoint.
    func handleKeyboardDirection(columnDelta: Int, rowDelta: Int) {
        let (transformedColumn, transformedRow): (Int, Int) = {
            switch appModel.currentViewpoint {
            case .front: return (columnDelta, rowDelta)
            case .right: return (rowDelta, -columnDelta)
            case .back:  return (-columnDelta, -rowDelta)
            case .left:  return (-rowDelta, columnDelta)
            }
        }()
        movePlayer(columnDelta: transformedColumn, rowDelta: transformedRow)
    }
}
#endif
