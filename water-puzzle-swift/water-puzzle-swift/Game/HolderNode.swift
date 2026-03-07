import SpriteKit

/// A tube/bottle container that holds liquid segments. Mirrors Unity's Holder.cs:
/// - Max capacity of 4 units
/// - Pending (selected) state with vertical lift animation
/// - Full pour animation: move near → tilt 82° → transfer liquid → return
/// - Tube visual rendered as an open-top rounded-bottom outline with cropped liquids
final class HolderNode: SKNode {

    // MARK: - Constants (matching Unity Holder serialized fields)

    static let maxValue: Int = 4
    static let innerWidth: CGFloat = 48.0
    static let wallThickness: CGFloat = 3.0
    static let outerWidth: CGFloat = innerWidth + wallThickness * 2
    static let unitHeight: CGFloat = LiquidNode.unitSize
    static let innerHeight: CGFloat = unitHeight * CGFloat(maxValue)
    static let cornerRadius: CGFloat = innerWidth / 2.0
    static let pendingOffset: CGFloat = 25.0
    static let pourAngleDegrees: CGFloat = 82.0
    static let pourAngleInRadians: CGFloat = pourAngleDegrees * .pi / 180.0

    // MARK: - Child Nodes

    private let contentNode: SKNode
    private let outlineNode: SKShapeNode
    private let cropNode: SKCropNode

    // MARK: - State

    /// The liquid segments currently contained in this tube, ordered bottom to top.
    private(set) var liquids: [LiquidNode] = []

    /// Whether this tube is in the raised "selected" state, awaiting a pour target.
    private(set) var isPending: Bool = false

    /// The tube's resting position in the scene before any lift or pour animation.
    private(set) var restPosition: CGPoint = .zero

    /// The tube's raised position when in the "selected" pending state.
    private var liftedPosition: CGPoint = .zero

    // MARK: - Computed Properties

    /// Whether the tube has reached its maximum capacity of 4 liquid units.
    var isFull: Bool {
        Int(totalLiquidValue.rounded()) >= Self.maxValue
    }

    /// The topmost liquid segment in this tube, or `nil` if the tube is empty.
    var topLiquid: LiquidNode? { liquids.last }

    /// The sum of all liquid segment values currently in this tube.
    var totalLiquidValue: CGFloat {
        liquids.reduce(CGFloat(0)) { $0 + $1.value }
    }

    /// Whether this tube contains no liquid segments.
    var isEmpty: Bool { liquids.isEmpty }

    /// Human-readable description of tube contents for VoiceOver accessibility.
    ///
    /// Describes liquid colors from bottom to top, e.g. "2 green, 1 blue, 1 red".
    var accessibilityContentDescription: String {
        guard !liquids.isEmpty else { return "empty" }
        let colorNames = ["green", "yellow", "orange", "blue", "lime",
                          "bright yellow", "dark green", "teal", "purple", "pink", "gray"]
        let parts = liquids.map { liquid in
            let colorName = liquid.groupId < colorNames.count ? colorNames[liquid.groupId] : "unknown"
            let units = Int(liquid.value.rounded())
            return "\(units) \(colorName)"
        }
        let fillCount = Int(totalLiquidValue.rounded())
        let status = isFull ? "full" : "\(fillCount) of \(Self.maxValue)"
        return parts.joined(separator: ", ") + " (\(status))"
    }

    // MARK: - Init

    override init() {
        contentNode = SKNode()
        cropNode = SKCropNode()

        // Tube outline — open top, rounded bottom
        let outlinePath = Self.createTubeOutlinePath()
        outlineNode = SKShapeNode(path: outlinePath)
        outlineNode.strokeColor = SKColor(white: 0.82, alpha: 1.0)
        outlineNode.lineWidth = Self.wallThickness
        outlineNode.fillColor = SKColor(white: 1.0, alpha: 0.06)
        outlineNode.lineCap = .round
        outlineNode.lineJoin = .round
        outlineNode.zPosition = 10

        // Mask for cropping liquids inside tube boundaries
        let maskPath = Self.createTubeFillPath()
        let maskNode = SKShapeNode(path: maskPath)
        maskNode.fillColor = .white
        maskNode.strokeColor = .white
        cropNode.maskNode = maskNode

        super.init()

        cropNode.addChild(contentNode)
        addChild(cropNode)
        addChild(outlineNode)
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Tube Shape Paths

    /// Open-top tube outline path: left wall → bottom arc → right wall.
    private static func createTubeOutlinePath() -> CGPath {
        let path = CGMutablePath()
        let halfW = outerWidth / 2
        let h = innerHeight + wallThickness
        let r = cornerRadius

        path.move(to: CGPoint(x: -halfW, y: h))
        path.addLine(to: CGPoint(x: -halfW, y: r))
        path.addArc(
            center: CGPoint(x: -halfW + r, y: r),
            radius: r,
            startAngle: .pi,
            endAngle: .pi * 1.5,
            clockwise: false
        )
        path.addLine(to: CGPoint(x: halfW - r, y: 0))
        path.addArc(
            center: CGPoint(x: halfW - r, y: r),
            radius: r,
            startAngle: .pi * 1.5,
            endAngle: 0,
            clockwise: false
        )
        path.addLine(to: CGPoint(x: halfW, y: h))

        return path
    }

    /// Closed fill path used as crop mask, slightly taller than the tube to avoid clipping at the top.
    private static func createTubeFillPath() -> CGPath {
        let path = CGMutablePath()
        let halfW = innerWidth / 2
        let h = innerHeight + 5
        let r = max(cornerRadius - wallThickness, 4)

        path.move(to: CGPoint(x: -halfW, y: h))
        path.addLine(to: CGPoint(x: -halfW, y: r))
        path.addArc(
            center: CGPoint(x: -halfW + r, y: r),
            radius: r,
            startAngle: .pi,
            endAngle: .pi * 1.5,
            clockwise: false
        )
        path.addLine(to: CGPoint(x: halfW - r, y: wallThickness))
        path.addArc(
            center: CGPoint(x: halfW - r, y: r),
            radius: r,
            startAngle: .pi * 1.5,
            endAngle: 0,
            clockwise: false
        )
        path.addLine(to: CGPoint(x: halfW, y: h))
        path.closeSubpath()

        return path
    }

    // MARK: - Initialization

    /// Populate the tube with liquid segments from the level definition.
    /// Mirrors Unity Holder.Init(IEnumerable<LiquidData>).
    func populate(with segments: [LiquidSegment]) {
        for (index, data) in segments.enumerated() {
            addLiquid(groupId: data.groupId, value: data.value, isFirst: index == 0)
        }
        restPosition = position
        liftedPosition = CGPoint(x: position.x, y: position.y + Self.pendingOffset)
    }

    // MARK: - Liquid Management

    /// Add a liquid segment at the top of the stack.
    /// Mirrors Unity Holder.AddLiquid(int groupId, float value).
    func addLiquid(groupId: Int, value: CGFloat = 0, isFirst: Bool = false) {
        let liquid = LiquidNode(groupId: groupId, value: value)
        liquid.isBottomLiquid = liquids.isEmpty || isFirst

        let yPos = topStackHeight
        liquid.position = CGPoint(x: 0, y: yPos)

        liquids.append(liquid)
        contentNode.addChild(liquid)
    }

    /// The Y coordinate at the top of the liquid stack.
    /// Mirrors Unity Holder.GetTopPoint().
    var topStackHeight: CGFloat {
        liquids.reduce(CGFloat(0)) { $0 + $1.visualHeight }
    }

    /// Recalculate positions of all liquid segments in the stack.
    func repositionLiquids() {
        var y: CGFloat = 0
        for (index, liquid) in liquids.enumerated() {
            liquid.isBottomLiquid = (index == 0)
            liquid.position = CGPoint(x: 0, y: y)
            y += liquid.visualHeight
        }
    }

    // MARK: - Pending State

    /// Lift the tube upward and bring to front. Mirrors Unity Holder.StartPending().
    func startPending() {
        guard !isPending else { return }
        isPending = true
        zPosition = 100

        removeAllActions()
        let moveAction = SKAction.move(to: liftedPosition, duration: 0.15)
        moveAction.timingMode = .easeOut
        run(moveAction)

        SoundManager.shared.play(.pop, on: self)
    }

    /// Return the tube to its original position. Mirrors Unity Holder.ClearPending().
    func clearPending() {
        guard isPending else { return }
        isPending = false

        removeAllActions()
        let moveAction = SKAction.move(to: restPosition, duration: 0.15)
        moveAction.timingMode = .easeOut
        run(moveAction) { [weak self] in
            self?.zPosition = 0
        }

        SoundManager.shared.play(.push, on: self)
    }

    // MARK: - Pour Animation

    /// Faithfully replicates Unity Holder.MoveAndTransferLiquid coroutine:
    /// 1. Move near target tube (~0.25s)
    /// 2. Tilt to 82° pour position (~0.4s)
    /// 3. Animate liquid transfer with stream line (~0.5s)
    /// 4. Return to near-target position (~0.4s)
    /// 5. Return to original position (~0.25s)
    func pourLiquid(to target: HolderNode, in scene: SKScene, completion: @escaping () -> Void) {
        // Validate transfer — mirrors Unity guard conditions
        guard let sourceLiquid = topLiquid,
              !target.isFull,
              target.topLiquid == nil || target.topLiquid?.groupId == sourceLiquid.groupId
        else {
            completion()
            return
        }

        isPending = false
        zPosition = 100
        removeAllActions()

        let isRightSide = target.position.x > self.position.x
        let signedAngle = isRightSide ? -Self.pourAngleInRadians : Self.pourAngleInRadians

        // Use restPosition (not self.position) so the tube returns to its
        // non-elevated position after pouring, not the pending-lifted position.
        let sourceStartPos = restPosition

        // Side delivery point (top-left or top-right of tube in local coords)
        // Mirrors Unity Holder._leftSideDeliverPoint / _rightSideDeliverPoint
        let sideLocalPoint = CGPoint(
            x: isRightSide ? Self.outerWidth / 2 : -Self.outerWidth / 2,
            y: Self.innerHeight + Self.wallThickness
        )

        // Target position: above the target tube (Unity: holder.TransformPoint(5 * Vector3.up))
        let deliverTopPos = CGPoint(
            x: target.position.x,
            y: target.position.y + Self.innerHeight + 60
        )

        // Calculate pour position using pivot rotation math from Unity:
        // relativePoint = center - sidePoint (in local space)
        // rotatedRelative = Quaternion.AngleAxis(angle, forward) * relativePoint
        // pourPosition = rotatedRelative + deliverTopPos
        let relativePoint = CGPoint(x: -sideLocalPoint.x, y: -sideLocalPoint.y)
        let cosA = cos(signedAngle)
        let sinA = sin(signedAngle)
        let rotatedRelative = CGPoint(
            x: relativePoint.x * cosA - relativePoint.y * sinA,
            y: relativePoint.x * sinA + relativePoint.y * cosA
        )
        let pourPosition = CGPoint(
            x: deliverTopPos.x + rotatedRelative.x,
            y: deliverTopPos.y + rotatedRelative.y
        )

        // Near-target intermediate position (for smooth approach)
        let nearTargetPos = CGPoint(
            x: target.position.x + (isRightSide ? -Self.outerWidth * 0.8 : Self.outerWidth * 0.8),
            y: sourceStartPos.y + 30
        )

        // Calculate transfer values
        let sourceStartValue = sourceLiquid.value
        let transferValue = min(sourceLiquid.value, CGFloat(Self.maxValue) - target.totalLiquidValue)
        let sourceColor = sourceLiquid.liquidColor

        // Mutable state shared across animation phases
        var targetLiquid: LiquidNode?
        var targetStartValue: CGFloat = 0
        var liquidLine: SKShapeNode?

        // === Phase 1: Move near target (mirrors MoveNearToHolderForTransfer) ===
        let phase1Duration: TimeInterval = 0.25
        let moveNear = SKAction.customAction(withDuration: phase1Duration) { [weak self] _, elapsed in
            guard let self else { return }
            let t = min(CGFloat(elapsed / phase1Duration), 1.0)
            self.position = CGPoint(
                x: sourceStartPos.x + (nearTargetPos.x - sourceStartPos.x) * t,
                y: sourceStartPos.y + (nearTargetPos.y - sourceStartPos.y) * t
            )
        }

        // === Phase 2: Move to pour position + tilt (speed:2 → ~0.4s) ===
        let phase2Duration: TimeInterval = 0.4
        let moveToPour = SKAction.customAction(withDuration: phase2Duration) { [weak self] _, elapsed in
            guard let self else { return }
            let t = min(CGFloat(elapsed / phase2Duration), 1.0)
            self.position = CGPoint(
                x: nearTargetPos.x + (pourPosition.x - nearTargetPos.x) * t,
                y: nearTargetPos.y + (pourPosition.y - nearTargetPos.y) * t
            )
            self.zRotation = signedAngle * t
        }

        // === Phase 3: Setup transfer (create target liquid, show stream line) ===
        let setupTransfer = SKAction.run { [weak self] in
            guard let self else { return }

            // Get or create target liquid — mirrors Unity logic
            if let existing = target.topLiquid, existing.groupId == sourceLiquid.groupId {
                targetLiquid = existing
            } else {
                target.addLiquid(groupId: sourceLiquid.groupId, value: 0)
                targetLiquid = target.topLiquid
            }
            targetStartValue = targetLiquid?.value ?? 0

            // Create liquid stream line — mirrors Unity _liquidLine setup
            let lineHeight = deliverTopPos.y - target.position.y - target.topStackHeight
            let line = SKShapeNode(rectOf: CGSize(width: 6, height: max(lineHeight, 20)))
            line.fillColor = sourceColor
            line.strokeColor = .clear
            line.position = CGPoint(
                x: deliverTopPos.x,
                y: target.position.y + target.topStackHeight + max(lineHeight, 20) / 2
            )
            line.zPosition = 50
            scene.addChild(line)
            liquidLine = line

            SoundManager.shared.play(.water, on: self)
        }

        // === Phase 4: Animate liquid transfer (speed:2 → 0.5s) ===
        let phase4Duration: TimeInterval = 0.5
        let animateTransfer = SKAction.customAction(withDuration: phase4Duration) { _, elapsed in
            let t = min(CGFloat(elapsed / phase4Duration), 1.0)
            // Source value decreases linearly
            sourceLiquid.value = sourceStartValue - transferValue * t
            // Target value increases linearly
            targetLiquid?.value = targetStartValue + transferValue * t
        }

        // === Phase 5: Cleanup (round values, remove empty liquid, hide stream) ===
        let cleanup = SKAction.run { [weak self] in
            guard let self else { return }

            // Remove liquid stream
            liquidLine?.removeFromParent()
            liquidLine = nil

            // Clean up source liquid — mirrors Unity cleanup logic
            if sourceLiquid.value <= 0.05 {
                self.liquids.removeLast()
                sourceLiquid.removeFromParent()
            } else {
                sourceLiquid.value = sourceLiquid.value.rounded()
            }

            // Round target liquid value
            targetLiquid?.value = (targetLiquid?.value ?? 0).rounded()

            // Reposition liquid stacks in both holders
            target.repositionLiquids()
            self.repositionLiquids()
        }

        // === Phase 6: Move back to near-target + untilt (reverse of phase 2) ===
        let phase6Duration: TimeInterval = 0.4
        let moveBack = SKAction.customAction(withDuration: phase6Duration) { [weak self] _, elapsed in
            guard let self else { return }
            let t = min(CGFloat(elapsed / phase6Duration), 1.0)
            self.position = CGPoint(
                x: pourPosition.x + (nearTargetPos.x - pourPosition.x) * t,
                y: pourPosition.y + (nearTargetPos.y - pourPosition.y) * t
            )
            self.zRotation = signedAngle * (1.0 - t)
        }

        // === Phase 7: Return to original position (reverse of phase 1) ===
        let phase7Duration: TimeInterval = 0.25
        let returnToOriginal = SKAction.customAction(withDuration: phase7Duration) { [weak self] _, elapsed in
            guard let self else { return }
            let t = min(CGFloat(elapsed / phase7Duration), 1.0)
            self.position = CGPoint(
                x: nearTargetPos.x + (sourceStartPos.x - nearTargetPos.x) * t,
                y: nearTargetPos.y + (sourceStartPos.y - nearTargetPos.y) * t
            )
        }

        // === Phase 8: Finalize ===
        let finish = SKAction.run { [weak self] in
            guard let self else { return }
            self.position = sourceStartPos
            self.zRotation = 0
            self.zPosition = 0
            completion()
        }

        removeAllActions()
        run(SKAction.sequence([
            moveNear, moveToPour, setupTransfer, animateTransfer,
            cleanup, moveBack, returnToOriginal, finish,
        ]))
    }
}
