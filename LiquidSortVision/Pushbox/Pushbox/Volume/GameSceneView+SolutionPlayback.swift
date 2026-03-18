// GameSceneView+SolutionPlayback.swift
// Auto-solver playback functionality.

import SwiftUI

// MARK: - Solution Playback Extension

extension GameSceneView {

    // MARK: - Solution Toggle
    
    /// Toggles solution playback state between playing and paused.
    func toggleSolution() {
        if appModel.isPlayingSolution {
            pauseSolution()
        } else {
            Task { await startSolution() }
        }
    }

    // MARK: - Start Solution
    
    /// Starts solution playback with credit/purchase gate.
    /// Resets the level and begins step-by-step auto-solve.
    func startSolution() async {
        // Prevent concurrent startSolution() calls from rapid button taps
        guard !appModel.isStartingSolution else { return }
        appModel.isStartingSolution = true
        defer { appModel.isStartingSolution = false }

        appModel.isSolutionPaused = false

        guard !appModel.isPlayingSolution,
              let world = appModel.activeWorld ?? appModel.selectedWorld,
              let levelIndex = appModel.selectedLevelIndex,
              let solutions = world.decryptedSolutions,
              levelIndex < solutions.count,
              !solutions[levelIndex].isEmpty else { return }

        // Fail fast when no credits are available and the level hasn't been unlocked yet.
        let alreadyUnlocked = appModel.inAppPurchaseService.hasUnlockedSolution(world: world, level: levelIndex)
        guard alreadyUnlocked || appModel.inAppPurchaseService.solutionCredits > 0 else {
            appModel.inAppPurchaseService.isStoreSheetPresented = true
            return
        }

        // Wait for any in-progress animation to complete before resetting the level.
        // This handles cases like clicking solution right after a move or during
        // level completion celebration.
        for _ in 0..<100 {
            if !isAnimating { break }
            try? await Task.sleep(for: .seconds(0.1))
        }
        guard !isAnimating else { return }

        // Reset level before playback.
        // Use forSolutionPlayback: true so the level swaps instantly without
        // toggling isLevelReady or showing the loading overlay — this avoids
        // a double-flash (overlay fade + solution opacity dim) on macOS / iOS.
        loadCurrentLevel(forSolutionPlayback: true)

        // Verify level is ready and user hasn't navigated away
        guard isLevelReady,
              levelRoot != nil,
              appModel.selectedLevelIndex == levelIndex,
              (appModel.activeWorld ?? appModel.selectedWorld)?.worldName == world.worldName else {
            return
        }

        // Disable smoke particle emitters so the Reality Composer Pro smoke
        // effect does not play during solution playback.
        if let root = levelRoot {
            appModel.animationService.disableSmokeEmitters(in: root)
        }

        // Consume a credit at the point playback is guaranteed to start.
        // If credits changed while loading (for example from sync on another device),
        // re-check and show the store if none remain.
        guard appModel.inAppPurchaseService.consumeSolutionCredit(for: world, level: levelIndex) else {
            appModel.inAppPurchaseService.isStoreSheetPresented = true
            return
        }

        // Begin playback
        // Filter solution to only include valid direction characters (u/d/l/r case-insensitive).
        // This handles terminators, newlines, and any other non-direction characters gracefully.
        appModel.isPlayingSolution = true
        let validDirections: Set<Character> = ["u", "d", "l", "r", "U", "D", "L", "R"]
        appModel.solutionMoves = Array(solutions[levelIndex]).filter { validDirections.contains($0) }
        runSolutionPlayback()
    }

    // MARK: - Pause Solution
    
    /// Pauses solution playback, clearing queued steps.
    /// Note: Any in-flight Task will check isPlayingSolution and exit early.
    func pauseSolution() {
        guard appModel.isPlayingSolution else { return }
        appModel.isPlayingSolution = false
        appModel.isSolutionPaused  = true
        appModel.solutionMoves.removeAll()
    }

    // MARK: - Solution Step Execution
    
    /// Runs the entire solution sequence as an iterative async loop.
    /// Stops one move before the end so the user can finish the level themselves.
    /// For very short solutions (≤2 moves), plays all moves to avoid consuming
    /// a credit with no visible feedback.
    func runSolutionPlayback() {
        Task { @MainActor in
            let moves = appModel.solutionMoves
            // Stop before the last move when there are enough moves;
            // otherwise play all moves so short solutions aren't invisible.
            let stopIndex = moves.count > 2 ? moves.count - 1 : moves.count
            for stepIndex in 0..<stopIndex {
                guard appModel.isPlayingSolution else { break }

                let direction = moves[stepIndex].lowercased()
                let (columnDelta, rowDelta): (Int, Int) = switch direction {
                    case "u": ( 0, -1)
                    case "d": ( 0,  1)
                    case "l": (-1,  0)
                    case "r": ( 1,  0)
                    default : ( 0,  0)  // Invalid characters are no-ops
                }
                movePlayer(columnDelta: columnDelta, rowDelta: rowDelta)

                // Wait for the move animation to actually complete rather than
                // sleeping a fixed duration. On macOS, main-actor scheduling can
                // delay the animation-completion Task, leaving isAnimating == true
                // when the next movePlayer() fires — which silently drops the move
                // and desynchronises the entire solution.
                for _ in 0..<100 {
                    if !isAnimating { break }
                    try? await Task.sleep(for: .seconds(0.05))
                }

                // Pacing delay so moves remain visually distinct.
                try? await Task.sleep(for: .seconds(0.35))
            }

            appModel.isPlayingSolution = false
            appModel.isSolutionPaused  = false
            appModel.solutionMoves.removeAll()
        }
    }
}
