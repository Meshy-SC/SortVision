// GameSceneView+Navigation.swift
// Level navigation functionality.

import SwiftUI
import RealityKit

// MARK: - Navigation Extension

extension GameSceneView {

    // MARK: - Level Navigation

    /// Advances to the next level in the current world, if the next level is unlocked.
    /// Note: Setting selectedLevelIndex triggers onChange in VolumeView which calls loadCurrentLevel().
    func nextLevel() {
        cancelCelebrationIfNeeded()
        guard let world = appModel.activeWorld ?? appModel.selectedWorld,
              let currentIndex = appModel.selectedLevelIndex,
              let totalLevels = appModel.levelLoader.cache[world.worldName]?.count,
              currentIndex < totalLevels - 1 else { return }
        
        let nextIndex = currentIndex + 1
        // Only advance if the next level is unlocked
        guard appModel.progressService.isLevelUnlocked(nextIndex, in: world) else { return }
        appModel.selectedLevelIndex = nextIndex
        // loadCurrentLevel() is called automatically via onChange(of: selectedLevelIndex)
    }

    /// Returns to the previous level in the current world.
    /// Note: Setting selectedLevelIndex triggers onChange in VolumeView which calls loadCurrentLevel().
    func previousLevel() {
        cancelCelebrationIfNeeded()
        guard let currentIndex = appModel.selectedLevelIndex, currentIndex > 0 else { return }
        appModel.selectedLevelIndex = currentIndex - 1
        // loadCurrentLevel() is called automatically via onChange(of: selectedLevelIndex)
    }

    /// Stops the celebration early so the player can navigate immediately.
    ///
    /// Apple's HIG and WWDC17 "Design Tips for Great Games" recommend respecting
    /// player agency — celebrations should reward, not block. When the player taps
    /// next or previous, they clearly want to move on.
    private func cancelCelebrationIfNeeded() {
        guard isLevelCompleted else { return }
        showCompletionOverlay = false
        appModel.animationService.stopFireworks()
        appModel.animationService.playIdleAnimation()
        isLevelCompleted = false
        isAnimating = false
    }

    /// Dismisses the completion overlay and transitions to the next step.
    /// Called when the user taps "Continue" on the `LevelCompletionView`.
    func dismissCompletionOverlay() {
        showCompletionOverlay = false
        appModel.animationService.stopFireworks()
        appModel.animationService.playIdleAnimation()
        isAnimating = false

        // Auto-advance to next level if available, otherwise open level selector
        if appModel.canGoToNextLevel {
            isLevelCompleted = false
            nextLevel()
        } else {
            #if os(visionOS)
            appModel.isControlPanelOpen = true
            #else
            isLevelCompleted = false
            #endif
        }
    }




    /// Convenience overload used by `onChange` handlers and other callers.
    func loadCurrentLevel() {
        loadCurrentLevel(forSolutionPlayback: false)
    }

    /// Loads and displays the currently selected level, replacing any existing level.
    ///
    /// - Parameter forSolutionPlayback: When `true` the loading overlay and reveal
    ///   delay are skipped so the level swaps instantly, avoiding a visible flash
    ///   before solution playback dims the scene.
    func loadCurrentLevel(forSolutionPlayback: Bool) {
        // During a drop animation, cancel it and proceed — the user wants to navigate.
        // For gameplay movement animations, keep blocking to avoid orphaned entities.
        if isAnimating {
            if dropAnimationTask != nil {
                dropAnimationTask?.cancel()
                dropAnimationTask = nil
                isAnimating = false
            } else {
                return
            }
        }

        // Bail out if level data isn't cached yet (e.g. rapid world switching)
        guard !currentLevelLines.isEmpty else {
            AppLogger.levels.warning("No level data available — levels may still be loading")
            return
        }

        // Mark level as not ready while loading (after the isAnimating guard
        // to avoid permanently setting false when bailing early).
        // Skip during solution playback to avoid the loading overlay flash.
        if !forSolutionPlayback {
            isLevelReady = false
        }

        guard let _ = appModel.selectedLevelIndex,
              let scene = appModel.gameScene,
              let wall = wallTemplate,
              let player = playerTemplate,
              let slot = slotTemplate,
              let box = boxTemplate else {
            levelRoot?.removeFromParent()
            levelRoot = nil
            return
        }

        // Reset auto-solver state (skip when the caller is about to start a solution)
        if !forSolutionPlayback {
            appModel.isPlayingSolution  = false
            appModel.isSolutionPaused   = false
        }

        appModel.levelDepth  = currentLevelLines.count
        appModel.levelWidth  = currentLevelLines.map(\.count).max() ?? 0
        appModel.progressService.currentLevelPushes = 0

        // Stop any animations on the old player before destroying the level
        // to avoid the animation controller referencing a deleted entity
        appModel.animationService.playerAnimationController?.stop()
        appModel.animationService.playerAnimationController = nil

        // Build the new level but delay its visibility for a smoother transition
        let previousRoot = levelRoot
        let newRoot = buildLevel(from: currentLevelLines,
                                 wall: wall, player: player, slot: slot, box: box)
        newRoot.isEnabled = false                 // hide during construction
        scene.addChild(newRoot)
        previousRoot?.removeFromParent()          // remove old level after adding new one
        levelRoot = newRoot
        appModel.animationService.playIdleAnimation()

        if forSolutionPlayback {
            // During solution playback enable immediately — no loading overlay,
            // no reveal delay — so the only visible transition is the solution
            // opacity dim that follows.
            newRoot.isEnabled = true
            isLevelReady = true
            Task {
                try? await Task.sleep(for: .seconds(GameLayout.postLevelLoadAudioDelay))
                guard !Task.isCancelled else { return }
                if appModel.isPuzzleAudioEnabled {
                    appModel.audioService.stopPuzzleAudio()
                    appModel.audioService.playPuzzleAudio()
                }
            }
        } else {
            // Animate entities dropping in one by one;
            // audio is started by performDropAnimation after the first entity lands.
            performDropAnimation(on: newRoot, reduceMotion: reduceMotion)
        }
    }
}
