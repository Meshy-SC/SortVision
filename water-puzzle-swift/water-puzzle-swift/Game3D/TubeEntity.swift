import RealityKit
import Foundation

/// A 3D bottle entity that holds liquid segments.
///
/// The bottle shape closely matches popular water-sort puzzle competitors:
/// - Wide rounded body with a hemispherical bottom
/// - Smooth shoulder taper from body to neck (multi-ring approximation)
/// - Short, narrow neck with a prominent dark cap/rim
/// - Translucent blue-tinted glass
///
/// Supports a "pending" (selected) lift state and a full pour animation
/// with arc motion, tilt, visible liquid stream, and smooth return.
final class TubeEntity: Entity {

    // MARK: - Constants

    /// Maximum liquid units per tube.
    static let maxValue: Int = 4

    // --- Bottle dimensions (meters) ---

    /// Inner radius of the wide bottle body.
    static let bodyRadius: Float = 0.024

    /// Glass wall thickness.
    static let wallThickness: Float = 0.003

    /// Outer radius of the bottle body.
    static let bodyOuterRadius: Float = bodyRadius + wallThickness

    /// Height of the cylindrical body section (holds 4 liquid units).
    static let bodyHeight: Float = LiquidSegmentEntity.unitHeight * Float(maxValue)

    /// Inner radius of the narrow neck opening.
    static let neckInnerRadius: Float = 0.012

    /// Outer radius of the neck.
    static let neckOuterRadius: Float = neckInnerRadius + wallThickness

    /// Height of the neck section.
    static let neckHeight: Float = 0.016

    /// Height of the smooth shoulder taper connecting body to neck.
    static let shoulderHeight: Float = 0.025

    /// Height of the cap/rim at the top of the neck.
    static let capHeight: Float = 0.008

    /// Total outer height of the bottle (body + shoulder + neck + cap).
    static let totalHeight: Float = bodyHeight + shoulderHeight + neckHeight + capHeight

    /// Radius of the hemispherical bottom.
    static let bottomCapRadius: Float = bodyOuterRadius

    /// Y-coordinate of the lip/spout (very top of the bottle).
    static let lipY: Float = totalHeight

    /// How high the tube lifts when selected (meters).
    static let pendingOffset: Float = 0.035

    /// Pour tilt angle (~85°).
    static let pourAngleDegrees: Float = 85.0
    static let pourAngleRadians: Float = pourAngleDegrees * .pi / 180.0

    /// Outer width used for spacing calculations (diameter of body).
    static let outerWidth: Float = bodyOuterRadius * 2

    /// Inner radius used by LiquidSegmentEntity for liquid cylinders.
    static let innerRadius: Float = bodyRadius

    /// Number of rings used to approximate the smooth shoulder taper.
    private static let shoulderSteps: Int = 5

    /// Identity quaternion (no rotation).
    private static let noRotation = simd_quatf(ix: 0, iy: 0, iz: 0, r: 1)

    // MARK: - Child Entities

    private let liquidContainer = Entity()

    // MARK: - State

    /// The liquid segments currently in this tube, ordered bottom to top.
    private(set) var liquids: [LiquidSegmentEntity] = []

    /// Whether this tube is in the raised "selected" state.
    private(set) var isPending: Bool = false

    /// The tube's resting position in the scene.
    private(set) var restPosition: SIMD3<Float> = .zero

    /// Index in the holders array.
    var holderIndex: Int = 0

    // MARK: - Computed Properties

    var isFull: Bool { Int(totalLiquidValue.rounded()) >= Self.maxValue }
    var topLiquid: LiquidSegmentEntity? { liquids.last }
    var totalLiquidValue: Float { liquids.reduce(0) { $0 + $1.value } }
    var isEmpty: Bool { liquids.isEmpty }
    var topStackHeight: Float { liquids.reduce(0) { $0 + $1.visualHeight } }

    // MARK: - Init

    required init() {
        super.init()
        self.name = "Tube"
        buildBottleGeometry()
        setupLiquidContainer()
    }

    // MARK: - Bottle Geometry

    /// Builds the bottle from primitives to match the competitor's rounded bottle design:
    /// hemispherical bottom → wide body → tapered shoulder → narrow neck → cap/rim.
    private func buildBottleGeometry() {
        let glassMat = ColorPalette3D.glassMaterial()
        let rimMat = ColorPalette3D.glassRimMaterial()
        let capMat = ColorPalette3D.capMaterial()

        // === Hemispherical bottom cap ===
        let bottomCap = ModelEntity(
            mesh: .generateSphere(radius: Self.bodyOuterRadius),
            materials: [glassMat]
        )
        // Squash vertically to create a half-sphere shape
        bottomCap.scale = SIMD3<Float>(1.0, 0.5, 1.0)
        bottomCap.position.y = 0
        bottomCap.name = "BottomCap"
        addChild(bottomCap)

        // === Main body cylinder ===
        let body = ModelEntity(
            mesh: .generateCylinder(height: Self.bodyHeight, radius: Self.bodyOuterRadius),
            materials: [glassMat]
        )
        body.position.y = Self.bodyHeight / 2.0
        body.name = "Body"
        addChild(body)

        // === Smooth shoulder taper (multiple thin rings) ===
        // Uses a smoothstep curve so the taper is concave (organic look).
        let stepHeight = Self.shoulderHeight / Float(Self.shoulderSteps)
        for step in 0..<Self.shoulderSteps {
            let t = Float(step + 1) / Float(Self.shoulderSteps + 1)
            let smoothT = t * t * (3.0 - 2.0 * t) // smoothstep
            let radius = Self.bodyOuterRadius
                + (Self.neckOuterRadius - Self.bodyOuterRadius) * smoothT
            let ring = ModelEntity(
                mesh: .generateCylinder(height: stepHeight + 0.0005, radius: radius),
                materials: [glassMat]
            )
            ring.position.y = Self.bodyHeight + Float(step) * stepHeight + stepHeight / 2.0
            ring.name = "Shoulder_\(step)"
            addChild(ring)
        }

        // === Neck cylinder ===
        let neck = ModelEntity(
            mesh: .generateCylinder(height: Self.neckHeight, radius: Self.neckOuterRadius),
            materials: [glassMat]
        )
        neck.position.y = Self.bodyHeight + Self.shoulderHeight + Self.neckHeight / 2.0
        neck.name = "Neck"
        addChild(neck)

        // === Dark cap/rim at the top of the neck ===
        let cap = ModelEntity(
            mesh: .generateCylinder(
                height: Self.capHeight,
                radius: Self.neckOuterRadius + 0.003
            ),
            materials: [capMat]
        )
        cap.position.y = Self.bodyHeight + Self.shoulderHeight + Self.neckHeight
            + Self.capHeight / 2.0
        cap.name = "Cap"
        addChild(cap)

        // === Inner rim detail at the lip ===
        let innerRim = ModelEntity(
            mesh: .generateCylinder(height: 0.002, radius: Self.neckInnerRadius + 0.001),
            materials: [rimMat]
        )
        innerRim.position.y = Self.lipY
        innerRim.name = "InnerRim"
        addChild(innerRim)

        // === Collision shape for tap detection ===
        let collisionHeight = Self.totalHeight + Self.pendingOffset
        let collisionEntity = ModelEntity()
        collisionEntity.collision = CollisionComponent(shapes: [
            .generateCapsule(height: collisionHeight, radius: Self.bodyOuterRadius)
        ])
        collisionEntity.components.set(InputTargetComponent())
        collisionEntity.position.y = collisionHeight / 2.0
        collisionEntity.name = "TubeCollision"
        addChild(collisionEntity)
    }

    private func setupLiquidContainer() {
        liquidContainer.position.y = Self.wallThickness * 0.5
        liquidContainer.name = "LiquidContainer"
        addChild(liquidContainer)
    }

    // MARK: - Population

    func populate(with segments: [LiquidSegment]) {
        for (index, data) in segments.enumerated() {
            addLiquid(groupId: data.groupId, value: Float(data.value), isFirst: index == 0)
        }
        restPosition = position
    }

    // MARK: - Liquid Management

    func addLiquid(groupId: Int, value: Float = 0, isFirst: Bool = false) {
        let liquid = LiquidSegmentEntity(groupId: groupId, value: value)
        liquid.isBottomLiquid = liquids.isEmpty || isFirst
        liquid.position.y = topStackHeight
        liquids.append(liquid)
        liquidContainer.addChild(liquid)
    }

    func removeTopLiquid() {
        guard let top = liquids.popLast() else { return }
        top.removeFromParent()
    }

    func repositionLiquids() {
        var y: Float = 0
        for (index, liquid) in liquids.enumerated() {
            liquid.isBottomLiquid = (index == 0)
            liquid.position.y = y
            y += liquid.visualHeight
        }
    }

    // MARK: - Pending (Selection) Animation

    func startPending() {
        guard !isPending else { return }
        isPending = true

        let liftedPos = SIMD3<Float>(
            restPosition.x,
            restPosition.y + Self.pendingOffset,
            restPosition.z
        )
        animateTo(position: liftedPos, rotation: Self.noRotation, duration: 0.15)
        SoundManager3D.shared.play(.pop)
    }

    func clearPending() {
        guard isPending else { return }
        isPending = false

        animateTo(position: restPosition, rotation: Self.noRotation, duration: 0.15)
        SoundManager3D.shared.play(.push)
    }

    // MARK: - Pour Animation

    /// Pours liquid from this tube into the target tube.
    ///
    /// The animation follows a realistic arc path — like someone picking up
    /// a bottle, moving it over another, tilting to pour, then returning:
    ///
    /// 1. **Arc up** to a peak above both bottles (upright)
    /// 2. **Swoop down** to the pour position while tilting
    /// 3. **Pour** with a visible liquid stream connecting the bottles
    /// 4. **Rise + untilt** back to the peak
    /// 5. **Arc down** to the rest position
    @MainActor
    func pourLiquid(to target: TubeEntity) async {
        guard let sourceLiquid = topLiquid,
              !target.isFull,
              target.topLiquid == nil || target.topLiquid?.groupId == sourceLiquid.groupId
        else { return }

        isPending = false
        let sourcePos = restPosition

        // --- Direction ---
        let isRightSide = target.restPosition.x > self.restPosition.x ||
            (target.restPosition.x == self.restPosition.x &&
             target.restPosition.z < self.restPosition.z)
        let tiltSign: Float = isRightSide ? -1.0 : 1.0
        let signedAngle = tiltSign * Self.pourAngleRadians

        // --- Spout offset in local space ---
        let sideLocalX: Float = isRightSide ? Self.bodyOuterRadius : -Self.bodyOuterRadius
        let sideLocalY: Float = Self.lipY

        // --- Target delivery position (above target opening) ---
        let deliverTopPos = SIMD3<Float>(
            target.restPosition.x,
            target.restPosition.y + Self.totalHeight + 0.04,
            target.restPosition.z
        )

        // --- Pivot-rotation math (mirrors Unity Holder.MoveAndTransferLiquid) ---
        let relX: Float = -sideLocalX
        let relY: Float = -sideLocalY
        let cosA = cos(signedAngle)
        let sinA = sin(signedAngle)
        let rotatedRelX = relX * cosA - relY * sinA
        let rotatedRelY = relX * sinA + relY * cosA
        let pourPos = SIMD3<Float>(
            deliverTopPos.x + rotatedRelX,
            deliverTopPos.y + rotatedRelY,
            sourcePos.z
        )

        // --- Transfer values ---
        let sourceStartValue = sourceLiquid.value
        let transferValue = min(
            sourceLiquid.value,
            Float(Self.maxValue) - target.totalLiquidValue
        )

        let tiltRotation = simd_quatf(
            angle: signedAngle,
            axis: SIMD3<Float>(0, 0, 1)
        )

        // --- Arc peak (above both bottles for a natural carry-over arc) ---
        let peakY = max(sourcePos.y, target.restPosition.y)
            + Self.totalHeight + 0.06
        let peakX = (sourcePos.x + pourPos.x) / 2.0
        let peakZ = (sourcePos.z + pourPos.z) / 2.0
        let peakPos = SIMD3<Float>(peakX, peakY, peakZ)

        // ===== Phase 1: Arc up to peak (upright) =====
        animateTo(position: peakPos, rotation: Self.noRotation, duration: 0.20)
        await sleepSeconds(0.22)

        // ===== Phase 2: Swoop down to pour position + tilt =====
        animateTo(position: pourPos, rotation: tiltRotation, duration: 0.30)
        await sleepSeconds(0.33)

        // ===== Phase 3: Prepare target liquid =====
        var targetLiquid: LiquidSegmentEntity
        var targetStartValue: Float = 0
        if let existing = target.topLiquid,
           existing.groupId == sourceLiquid.groupId {
            targetLiquid = existing
        } else {
            target.addLiquid(groupId: sourceLiquid.groupId, value: 0)
            targetLiquid = target.topLiquid!
        }
        targetStartValue = targetLiquid.value
        SoundManager3D.shared.play(.water)

        // ===== Phase 4: Create visible liquid stream =====
        let stream = makeLiquidStream(colorGroupId: sourceLiquid.groupId)
        self.parent?.addChild(stream)

        // ===== Phase 5: Animate liquid transfer with stream =====
        let steps = 20
        for i in 1...steps {
            let t = Float(i) / Float(steps)
            sourceLiquid.value = sourceStartValue - transferValue * t
            targetLiquid.value = targetStartValue + transferValue * t
            target.repositionLiquids()
            repositionLiquids()

            // Update stream geometry every frame
            updateLiquidStream(stream, target: target)

            await sleepSeconds(0.025)
        }

        // ===== Phase 6: Remove stream =====
        stream.removeFromParent()

        // ===== Phase 7: Clean up liquid values =====
        if sourceLiquid.value <= 0.05 {
            removeTopLiquid()
        } else {
            sourceLiquid.value = sourceLiquid.value.rounded()
        }
        targetLiquid.value = targetLiquid.value.rounded()
        target.repositionLiquids()
        repositionLiquids()

        // ===== Phase 8: Untilt + rise back to arc peak =====
        animateTo(position: peakPos, rotation: Self.noRotation, duration: 0.28)
        await sleepSeconds(0.30)

        // ===== Phase 9: Descend to rest position =====
        animateTo(position: sourcePos, rotation: Self.noRotation, duration: 0.20)
        await sleepSeconds(0.22)

        // ===== Phase 10: Snap to rest (guarantees final state) =====
        self.setTransformMatrix(
            Transform(
                scale: self.scale,
                rotation: Self.noRotation,
                translation: sourcePos
            ).matrix,
            relativeTo: self.parent
        )
    }

    // MARK: - Liquid Stream

    /// Creates a thin cylinder entity to represent the flowing liquid stream.
    private func makeLiquidStream(colorGroupId: Int) -> Entity {
        let container = Entity()
        container.name = "LiquidStream"

        let material = ColorPalette3D.liquidMaterial(for: colorGroupId)
        let mesh = ModelEntity(
            mesh: .generateCylinder(height: 0.01, radius: 0.0035),
            materials: [material]
        )
        mesh.name = "StreamMesh"
        container.addChild(mesh)
        return container
    }

    /// Updates the stream to stretch from this bottle's lip to the target opening.
    private func updateLiquidStream(_ stream: Entity, target: TubeEntity) {
        guard let mesh = stream.children.first as? ModelEntity,
              let parentEntity = self.parent else { return }

        // Source: this bottle's lip in parent (root) coordinate space
        let localLip = SIMD3<Float>(0, Self.lipY, 0)
        let worldLip = self.convert(position: localLip, to: parentEntity)

        // Target: top of the target bottle opening
        let targetOpening = SIMD3<Float>(0, Self.lipY, 0)
        let worldTarget = target.convert(position: targetOpening, to: parentEntity)

        let direction = worldTarget - worldLip
        let distance = simd_length(direction)
        guard distance > 0.001 else { return }

        // Position stream at the midpoint between lip and target
        stream.position = (worldLip + worldTarget) / 2.0

        // Resize cylinder to span the full distance
        mesh.model?.mesh = .generateCylinder(height: distance, radius: 0.0035)

        // Orient the cylinder along the direction vector
        let normalized = simd_normalize(direction)
        stream.orientation = simd_quatf(from: SIMD3<Float>(0, 1, 0), to: normalized)
    }

    // MARK: - Animation Helpers

    private func animateTo(
        position: SIMD3<Float>,
        rotation: simd_quatf,
        duration: TimeInterval
    ) {
        self.move(
            to: Transform(
                scale: self.scale,
                rotation: rotation,
                translation: position
            ),
            relativeTo: self.parent,
            duration: duration,
            timingFunction: .easeInOut
        )
    }

    private func sleepSeconds(_ seconds: Double) async {
        try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
    }
}
