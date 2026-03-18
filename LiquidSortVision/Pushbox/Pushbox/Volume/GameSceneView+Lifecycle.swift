// GameSceneView+Lifecycle.swift
#if os(visionOS)
// Scene lifecycle and bootstrapping logic for ImmersiveGameView.

import SwiftUI
import RealityKit
import RealityKitContent

extension ImmersiveGameView {

    // MARK: - Scene Bootstrap

    /// Loads the RealityKit scene from the Reality Composer Pro project,
    /// extracts entity templates, and builds the initial level.
    func bootstrapScene() async {
        guard let scene = try? await Entity(named: "Scene", in: realityKitContentBundle) else {
            AppLogger.ui.error("Failed to load Scene entity - opening control panel as fallback")
            appModel.isControlPanelOpen = true
            return
        }
        scene.findEntity(named: "ParticleEmitterFireworks")?.isEnabled = false
        await MainActor.run { appModel.gameScene = scene }

        guard let wallEntity = scene.findEntity(named: "Wall"),
              let playerTemplateEntity = scene.findEntity(named: "Player"),
              let slotEntity = scene.findEntity(named: "Slot"),
              let boxEntity = scene.findEntity(named: "Box") else {
            AppLogger.ui.error("Missing template entities - opening control panel as fallback")
            appModel.isControlPanelOpen = true
            return
        }
        wallTemplate = wallEntity;  wallEntity.removeFromParent()
        playerTemplate = playerTemplateEntity; playerTemplateEntity.removeFromParent()
        slotTemplate  = slotEntity; slotEntity.removeFromParent()
        boxTemplate   = boxEntity; boxEntity.removeFromParent()

        // Add the scene entity as a child of the game anchor so audio/particles work
        gameAnchorEntity.addChild(scene)

        if appModel.selectedLevelIndex != nil && appModel.gamePhase == .playing {
            // Build the initial level but keep it hidden until fully ready
            let newRoot = buildLevel(from: currentLevelLines,
                                     wall: wallEntity, player: playerTemplateEntity,
                                     slot: slotEntity, box: boxEntity)
            newRoot.isEnabled = false
            scene.addChild(newRoot)
            levelRoot = newRoot
            appModel.animationService.playIdleAnimation()
            // Animate entities dropping in one by one;
            // audio is started by performDropAnimation after the first entity lands.
            performDropAnimation(on: newRoot, reduceMotion: reduceMotion)
        }
    }

    // MARK: - Scene Phase Handling

    /// Responds to scene phase transitions by pausing/resuming animations,
    /// audio, and resetting spatial anchors as needed.
    func handleScenePhaseChange(from oldPhase: ScenePhase, to phase: ScenePhase) {
        switch phase {
        case .background:
            // Reset spatial anchor — user will need to re-place after relaunch
            appModel.resetSessionAnchor()
            fallthrough
        case .inactive:
            // Cancel any in-progress drop animation
            dropAnimationTask?.cancel()
            dropAnimationTask = nil
            // Pause animations and audio when app goes to background or inactive
            appModel.animationService.playerAnimationController?.pause()
            appModel.audioService.stopPuzzleAudio()
            appModel.animationService.stopFireworks()
            appModel.isControlPanelOpen = false
            appModel.progressService.saveProgress()
        case .active:
            // Resume when returning to foreground
            if oldPhase == .background || oldPhase == .inactive {
                appModel.animationService.playerAnimationController?.resume()
                if appModel.isPuzzleAudioEnabled && levelRoot != nil && !isLevelCompleted {
                    appModel.audioService.playPuzzleAudio()
                }
            }
        @unknown default:
            break
        }
    }
}
#endif
