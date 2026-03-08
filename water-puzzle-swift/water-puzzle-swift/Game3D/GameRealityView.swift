import SwiftUI
import RealityKit

/// SwiftUI host for the RealityKit 3D puzzle scene.
///
/// Uses the system background colour rather than a custom dark colour.
/// The ground plane is subtle enough to work against both light and dark mode.
struct GameRealityView: View {
    @ObservedObject var scene: GameScene3D

    var body: some View {
        RealityView { content in
            content.add(scene.rootEntity)
            addGroundPlane()
        }
        .gesture(tapGesture)
    }

    // MARK: - Scene Helpers

    /// Adds a subtle ground plane beneath the tubes.
    private func addGroundPlane() {
        var groundMaterial = PhysicallyBasedMaterial()
        groundMaterial.baseColor = .init(
            tint: .init(red: 0.14, green: 0.14, blue: 0.16, alpha: 1.0)
        )
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
    var accessibilityDescription: String {
        guard let level = scene.level else { return "Water sort puzzle" }
        return "Water sort puzzle, level \(level.number), 3D view"
    }
}
