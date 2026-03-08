import SwiftUI
import RealityKit

/// A SwiftUI view that hosts the 3D water puzzle scene using RealityKit.
///
/// Replaces the `SpriteView(scene:)` usage in `GameplayView`.
/// Sets up camera, lighting, background, and tap gesture handling.
struct GameRealityView: View {

    /// The 3D game scene coordinator.
    @ObservedObject var scene: GameScene3D

    var body: some View {
        ZStack {
            // Dark background matching the original game
            Color(red: 0.12, green: 0.15, blue: 0.22)
                .ignoresSafeArea()

            realityContent
        }
    }

    @ViewBuilder
    private var realityContent: some View {
        RealityView { content in
            // Add the game's root entity
            content.add(scene.rootEntity)

            // Add a subtle ground plane for visual grounding
            addGroundPlane()
        }
        .gesture(tapGesture)
    }

    // MARK: - Scene Helpers

    /// Adds a dark, subtle ground plane beneath the tubes.
    private func addGroundPlane() {
        var groundMaterial = PhysicallyBasedMaterial()
        groundMaterial.baseColor = .init(tint: .init(red: 0.10, green: 0.12, blue: 0.18, alpha: 1.0))
        groundMaterial.roughness = .init(floatLiteral: 0.8)
        groundMaterial.metallic = .init(floatLiteral: 0.0)

        let ground = ModelEntity(
            mesh: .generatePlane(width: 1.0, depth: 0.6, cornerRadius: 0.05),
            materials: [groundMaterial]
        )
        ground.position = SIMD3<Float>(0, -0.005, 0)
        ground.name = "GroundPlane"
        scene.rootEntity.addChild(ground)
    }

    // MARK: - Tap Gesture

    /// Spatial tap gesture that resolves which entity was tapped.
    private var tapGesture: some Gesture {
        SpatialTapGesture()
            .targetedToAnyEntity()
            .onEnded { value in
                scene.handleTap(on: value.entity)
            }
    }
}

// MARK: - Accessibility

extension GameRealityView {
    /// Provides an accessibility label for VoiceOver users.
    var accessibilityDescription: String {
        guard let level = scene.level else { return "Water sort puzzle" }
        return "Water sort puzzle, level \(level.number), 3D view"
    }
}
