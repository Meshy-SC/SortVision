// GameLayout.swift
// Layout constants and platform type alias for the 3D game scene.

import SwiftUI
import RealityKit

// MARK: - Shared Layout Constants

/// Layout constants shared across all game scene implementations.
enum GameLayout {
    static let cellSize:                   Float       = 0.07125
    static let animationDuration:          TimeInterval = 0.20
    static let arrivalAudioDelay:          TimeInterval = 0.05
    static let postLevelLoadAudioDelay:    TimeInterval = 0.10
    static let controlPanelDelay:          TimeInterval = 5.00
    static let celebrationOverlayDelay:     TimeInterval = 1.50
    static let levelYOffset:               Float       = 0.01
    static let levelRevealDelay:           TimeInterval = 0.2

    // Drop animation
    static let dropStaggerDelay:           TimeInterval = 0.04
    static let dropBounceUpDuration:       TimeInterval = 0.08
    static let dropBounceDownDuration:     TimeInterval = 0.08

    /// Freefall duration from `d = ½gt²` → `t = √(2d / g)`.
    /// Uses a stylised gravity (~2.0 m/s²) that reads well at model scale.
    static func freefallDuration(for height: Float) -> TimeInterval {
        let g: Float = 2.0
        return TimeInterval(sqrt(2.0 * height / g))
    }
}

// MARK: - Platform Type Alias

/// A single type alias that maps to the concrete game scene view for each platform.
/// All shared game logic files (LevelBuilder, Movement, Navigation, SolutionPlayback)
/// extend this type, which resolves to the correct struct at compile time.
/// This avoids protocol-extension mutability issues with @State properties.
#if os(visionOS)
typealias GameSceneView = ImmersiveGameView
#elseif os(iOS) || os(macOS) || os(tvOS)
typealias GameSceneView = iOSGameSceneView
#endif
