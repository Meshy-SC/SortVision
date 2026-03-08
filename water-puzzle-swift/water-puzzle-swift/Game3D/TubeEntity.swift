import RealityKit
import Foundation

/// A 3D bottle/tube that holds liquid segments.
///
/// The bottle shape matches common water-sort puzzle games:
/// - Wide cylindrical body with a rounded bottom
/// - Narrower neck opening at the top
/// - Translucent glass material with a visible rim
///
/// Supports pending (selected) state with a lift animation and a full
/// pour animation that faithfully mirrors the original SpriteKit
/// `HolderNode.pourLiquid(to:in:completion:)` pivot-rotation math.
final class TubeEntity: Entity {

    // MARK: - Constants

    /// Maximum liquid units per tube.
    static let maxValue: Int = 4

    // --- Bottle dimensions (meters) ---

    /// Inner radius of the bottle body.
    static let bodyRadius: Float = 0.022

    /// Glass wall thickness.
    static let wallThickness: Float = 0.0025

    /// Outer radius of the bottle body.
    static let bodyOuterRadius: Float = bodyRadius + wallThickness

    /// Height of the cylindrical body section (holds 4 liquid units).
    static let bodyHeight: Float = LiquidSegmentEntity.unitHeight * Float(maxValue)

    /// Inner radius of the neck opening.
    static let neckInnerRadius: Float = 0.014

    /// Outer radius of the neck.
    static let neckOuterRadius: Float = neckInnerRadius + wallThickness

    /// Height of the neck section.
    static let neckHeight: Float = 0.025

    /// Height of the tapered shoulder connecting body to neck.
    static let shoulderHeight: Float = 0.015

    /// Total outer height of the bottle (body + shoulder + neck).
    static let totalHeight: Float = bodyHeight + shoulderHeight + neckHeight

    /// Radius of the rounded bottom cap.
    static let bottomCapRadius: Float = bodyOuterRadius

    /// The Y-coordinate of the lip/spout (top of neck) in local space.
    static let lipY: Float = totalHeight

    /// How high the tube lifts when selected (meters).
    static let pendingOffset: Float = 0.03

    /// Pour tilt angle (~82°).
    static let pourAngleDegrees: Float = 82.0
    static let pourAngleRadians: Float = pourAngleDegrees * .pi / 180.0

    /// Outer width used for spacing calculations (diameter of body).
    static let outerWidth: Float = bodyOuterRadius * 2

    /// Inner radius used by LiquidSegmentEntity for liquid cylinders.
    static let innerRadius: Float = bodyRadius

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

    /// Builds a bottle shape from primitives:
    /// - Cylindrical body
    /// - Shoulder taper (truncated cone approximation)
    /// - Neck cylinder
    /// - Rounded bottom cap
    /// - Rim ring at the lip
    private func buildBottleGeometry() {
        let glassMat = ColorPalette3D.glassMaterial()
        let rimMat = ColorPalette3D.glassRimMaterial()

        // === Body cylinder ===
        let body = ModelEntity(
            mesh: .generateCylinder(height: Self.bodyHeight, radius: Self.bodyOuterRadius),
            materials: [glassMat]
        )
        body.position.y = Self.bodyHeight / 2.0
        body.name = "Body"
        addChild(body)

        // === Shoulder (tapered section) — averaged radius between body and neck ===
        let shoulderMidRadius = (Self.bodyOuterRadius + Self.neckOuterRadius) / 2.0
        let shoulder = ModelEntity(
            mesh: .generateCylinder(height: Self.shoulderHeight, radius: shoulderMidRadius),
            materials: [glassMat]
        )
        shoulder.position.y = Self.bodyHeight + Self.shoulderHeight / 2.0
        shoulder.name = "Shoulder"
        addChild(shoulder)

        // === Neck cylinder ===
        let neck = ModelEntity(
            mesh: .generateCylinder(height: Self.neckHeight, radius: Self.neckOuterRadius),
            materials: [glassMat]
        )
        neck.position.y = Self.bodyHeight + Self.shoulderHeight + Self.neckHeight / 2.0
        neck.name = "Neck"
        addChild(neck)

        // === Rounded bottom cap ===
        let bottomCap = ModelEntity(
            mesh: .generateSphere(radius: Self.bodyOuterRadius),
            materials: [glassMat]
        )
        bottomCap.scale = SIMD3<Float>(1.0, 0.35, 1.0)
        bottomCap.position.y = 0
        bottomCap.name = "BottomCap"
        addChild(bottomCap)

        // === Lip/rim ring at the top of the neck ===
        let rim = ModelEntity(
            mesh: .generateCylinder(height: Self.wallThickness * 1.5, radius: Self.neckOuterRadius + 0.002),
            materials: [rimMat]
        )
        rim.position.y = Self.lipY
        rim.name = "Rim"
        addChild(rim)

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
        // Liquids start at the inner bottom of the body
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

        let liftedPos = SIMD3<Float>(restPosition.x, restPosition.y + Self.pendingOffset, restPosition.z)
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

    /// Faithfully mirrors the original SpriteKit `HolderNode.pourLiquid(to:in:completion:)`
    /// using the same pivot-rotation math from Unity's Holder.MoveAndTransferLiquid.
    ///
    /// The key idea: when tilted, the bottle's spout (side delivery point) must end up
    /// directly above the target tube's opening. The position is calculated by rotating
    /// the vector from spout-to-center around the tilt angle, then offsetting from
    /// the delivery target point.
    @MainActor
    func pourLiquid(to target: TubeEntity) async {
        guard let sourceLiquid = topLiquid,
              !target.isFull,
              target.topLiquid == nil || target.topLiquid?.groupId == sourceLiquid.groupId
        else { return }

        isPending = false
        let sourceStartPos = restPosition

        // --- Direction ---
        let isRightSide = target.restPosition.x > self.restPosition.x ||
            (target.restPosition.x == self.restPosition.x && target.restPosition.z < self.restPosition.z)
        let tiltSign: Float = isRightSide ? -1.0 : 1.0
        let signedAngle = tiltSign * Self.pourAngleRadians

        // --- Side delivery point (spout) in local coordinates ---
        // When tilted, this point should align above the target tube opening.
        // Mirrors Unity: _rightSideDeliverPoint = (outerWidth/2, innerHeight + wallThickness)
        //                 _leftSideDeliverPoint  = (-outerWidth/2, innerHeight + wallThickness)
        let sideLocalX: Float = isRightSide ? Self.bodyOuterRadius : -Self.bodyOuterRadius
        let sideLocalY: Float = Self.lipY

        // --- Target delivery position (above target tube opening) ---
        // Mirrors Unity: holder.TransformPoint(5 * Vector3.up) → above target by ~totalHeight + offset
        let deliverTopPos = SIMD3<Float>(
            target.restPosition.x,
            target.restPosition.y + Self.totalHeight + 0.04,
            target.restPosition.z
        )

        // --- Calculate pour position using pivot rotation (mirrors Unity exactly) ---
        // relativePoint = center - sidePoint  (vector from spout back to tube center)
        // rotatedRelative = rotate(relativePoint, signedAngle)
        // pourPosition = deliverTopPos + rotatedRelative
        //
        // This ensures the spout lands exactly at deliverTopPos when the tube is tilted.
        let relX: Float = -sideLocalX
        let relY: Float = -sideLocalY
        let cosA = cos(signedAngle)
        let sinA = sin(signedAngle)
        let rotatedRelX = relX * cosA - relY * sinA
        let rotatedRelY = relX * sinA + relY * cosA
        let pourPos = SIMD3<Float>(
            deliverTopPos.x + rotatedRelX,
            deliverTopPos.y + rotatedRelY,
            sourceStartPos.z
        )

        // --- Near-target intermediate position (smooth approach) ---
        // Mirrors Unity: nearTarget offset by ~0.8× outerWidth to the side
        let nearTargetPos = SIMD3<Float>(
            target.restPosition.x + (isRightSide ? -Self.outerWidth * 0.8 : Self.outerWidth * 0.8),
            sourceStartPos.y + 0.02,
            sourceStartPos.z
        )

        // --- Transfer values ---
        let sourceStartValue = sourceLiquid.value
        let transferValue = min(sourceLiquid.value, Float(Self.maxValue) - target.totalLiquidValue)

        let tiltRotation = simd_quatf(angle: signedAngle, axis: SIMD3<Float>(0, 0, 1))

        // === Phase 1: Move near target (0.25s) ===
        animateTo(position: nearTargetPos, rotation: Self.noRotation, duration: 0.25)
        await sleepSeconds(0.28)

        // === Phase 2: Move to pour position + tilt (0.4s) ===
        animateTo(position: pourPos, rotation: tiltRotation, duration: 0.4)
        await sleepSeconds(0.44)

        // === Phase 3: Setup target liquid ===
        var targetLiquid: LiquidSegmentEntity
        var targetStartValue: Float = 0
        if let existing = target.topLiquid, existing.groupId == sourceLiquid.groupId {
            targetLiquid = existing
        } else {
            target.addLiquid(groupId: sourceLiquid.groupId, value: 0)
            targetLiquid = target.topLiquid!
        }
        targetStartValue = targetLiquid.value
        SoundManager3D.shared.play(.water)

        // === Phase 4: Animate liquid transfer (0.5s, 20 steps) ===
        let steps = 20
        for i in 1...steps {
            let t = Float(i) / Float(steps)
            sourceLiquid.value = sourceStartValue - transferValue * t
            targetLiquid.value = targetStartValue + transferValue * t
            target.repositionLiquids()
            await sleepSeconds(0.025)
        }

        // === Phase 5: Cleanup ===
        if sourceLiquid.value <= 0.05 {
            removeTopLiquid()
        } else {
            sourceLiquid.value = sourceLiquid.value.rounded()
        }
        targetLiquid.value = targetLiquid.value.rounded()
        target.repositionLiquids()
        repositionLiquids()

        // === Phase 6: Return to near target + untilt (0.4s) ===
        animateTo(position: nearTargetPos, rotation: Self.noRotation, duration: 0.4)
        await sleepSeconds(0.44)

        // === Phase 7: Return to original position (0.25s) ===
        animateTo(position: sourceStartPos, rotation: Self.noRotation, duration: 0.25)
        await sleepSeconds(0.28)

        // === Phase 8: Snap to rest (guarantees final state) ===
        self.setTransformMatrix(
            Transform(scale: self.scale, rotation: Self.noRotation, translation: sourceStartPos).matrix,
            relativeTo: self.parent
        )
    }

    // MARK: - Animation Helpers

    private func animateTo(position: SIMD3<Float>, rotation: simd_quatf, duration: TimeInterval) {
        self.move(
            to: Transform(scale: self.scale, rotation: rotation, translation: position),
            relativeTo: self.parent,
            duration: duration,
            timingFunction: .easeInOut
        )
    }

    private func sleepSeconds(_ seconds: Double) async {
        try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
    }
}
