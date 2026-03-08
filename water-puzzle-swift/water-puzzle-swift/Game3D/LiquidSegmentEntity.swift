import RealityKit
import Foundation

/// A single liquid segment inside a 3D tube.
///
/// Replaces `LiquidNode` (SpriteKit). Each segment is a capped cylinder whose
/// height is proportional to its `value` (number of liquid units).
///
/// The entity's local origin is at the **bottom** of the segment so that
/// stacking segments is a simple matter of accumulating heights.
final class LiquidSegmentEntity: Entity {

    // MARK: - Constants

    /// Visual height per unit of liquid value (meters in RealityKit world space).
    /// Scaled down from SpriteKit's 45 points to a manageable 3D size.
    static let unitHeight: Float = 0.045

    // MARK: - Properties

    /// Color group index into `ColorPalette3D.colors` (0–10).
    let groupId: Int

    /// The number of liquid units this segment occupies.
    /// Changing this value regenerates the mesh to match the new height.
    var value: Float {
        didSet {
            value = max(0, value)
            updateMesh()
        }
    }

    /// The visual height of this segment in meters.
    var visualHeight: Float { value * Self.unitHeight }

    /// Whether this is the bottom-most segment (used for future rounded-cap rendering).
    var isBottomLiquid: Bool = false

    // MARK: - Child Entities

    private var meshEntity: ModelEntity?

    // MARK: - Init

    /// Creates a new liquid segment with the given color group and initial value.
    init(groupId: Int, value: Float = 0) {
        self.groupId = groupId
        self.value = max(0, value)
        super.init()
        self.name = "LiquidSegment_\(groupId)"
        updateMesh()
    }

    @MainActor required init() {
        self.groupId = 0
        self.value = 0
        super.init()
    }

    // MARK: - Mesh Generation

    /// Rebuilds the cylinder mesh to reflect the current `value`.
    private func updateMesh() {
        meshEntity?.removeFromParent()

        let height = visualHeight
        guard height > 0.0005 else {
            meshEntity = nil
            return
        }

        let radius = TubeEntity.innerRadius
        let mesh = MeshResource.generateCylinder(height: height, radius: radius)
        let material = ColorPalette3D.liquidMaterial(for: groupId)
        let entity = ModelEntity(mesh: mesh, materials: [material])

        // Cylinder origin is at its center; offset so our entity origin = bottom
        entity.position.y = height / 2.0
        entity.name = "LiquidMesh"

        // Enable tap input — the collision shape is used by GameScene3D hit-testing
        let shape = ShapeResource.generateCapsule(height: height, radius: radius)
        entity.collision = CollisionComponent(shapes: [shape])
        entity.components.set(InputTargetComponent())

        meshEntity = entity
        addChild(entity)
    }
}
