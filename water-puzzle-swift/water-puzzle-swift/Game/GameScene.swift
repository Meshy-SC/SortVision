import SpriteKit

/// Main gameplay scene. Faithfully mirrors Unity's LevelManager:
/// - Loads level data and creates tube layout (1 or 2 rows)
/// - Handles tap input to select tubes and initiate pours
/// - Manages game state (Playing, Over)
/// - Checks win condition after each pour
/// - Plays win sound and confetti effect on completion
final class GameScene: SKScene {

    // MARK: - Level Configuration

    /// The level data defining the initial tube configuration for this scene.
    var level: Level?

    /// The difficulty mode for the current level, used for progress tracking on completion.
    var gameMode: GameMode = .easy

    // MARK: - Callbacks (bridge to SwiftUI)

    /// Called when the level is completed (triggers UI overlay).
    var onLevelComplete: (@MainActor () -> Void)?

    /// Called to persist level completion progress.
    /// Decouples the SpriteKit layer from `GameManager` — the SwiftUI host
    /// provides this closure to bridge back to the data layer.
    var onSaveProgress: (@MainActor (GameMode, Int) -> Void)?

    /// Whether to reduce motion effects (respects system accessibility setting).
    var reduceMotion: Bool = false

    // MARK: - Game State

    private var holders: [HolderNode] = []
    private var isTransferring = false
    private var gameState: GameState = .idle

    /// Horizontal distance between tube centers.
    /// Mirrors Unity LevelManager._minXDistanceBetweenHolders.
    private let holderSpacing: CGFloat = 80

    enum GameState {
        case idle, playing, over
    }

    // MARK: - Scene Lifecycle

    override func didMove(to view: SKView) {
        backgroundColor = SKColor(red: 0.12, green: 0.15, blue: 0.22, alpha: 1.0)
        isAccessibilityElement = false
        loadLevel()
        updateAccessibility()
        gameState = .playing
    }

    // MARK: - Level Loading

    /// Creates holder nodes from level data and positions them.
    /// Mirrors Unity LevelManager.LoadLevel().
    private func loadLevel() {
        guard let level else { return }

        let holderCount = level.columns.count
        let positions = positionsForHolders(count: holderCount)
        let liquidSegments = level.compressedLiquidSegments

        for i in 0..<holderCount {
            let holder = HolderNode()
            holder.position = positions[i]
            addChild(holder)
            holder.populate(with: liquidSegments[i])
            holders.append(holder)
        }
    }

    // MARK: - Layout

    /// Calculates tube positions: single row for ≤6 tubes, two rows otherwise.
    /// Faithfully mirrors Unity LevelManager.PositionsForHolders().
    private func positionsForHolders(count: Int) -> [CGPoint] {
        let centerX = size.width / 2
        let centerY = size.height / 2 - 20

        if count <= 6 {
            // Single row — centered horizontally
            let totalWidth = CGFloat(count - 1) * holderSpacing
            let startX = centerX - totalWidth / 2
            return (0..<count).map { i in
                CGPoint(x: startX + CGFloat(i) * holderSpacing, y: centerY)
            }
        }

        // Two rows — top row gets ceil(n/2), bottom row gets floor(n/2)
        let topRowCount = Int(ceil(Double(count) / 2.0))
        let bottomRowCount = count - topRowCount
        let rowSpacing: CGFloat = HolderNode.innerHeight + 80

        let topY = centerY + rowSpacing / 2
        let bottomY = centerY - rowSpacing / 2

        // Top row
        let topTotalWidth = CGFloat(topRowCount - 1) * holderSpacing
        let topStartX = centerX - topTotalWidth / 2
        let topPositions = (0..<topRowCount).map { i in
            CGPoint(x: topStartX + CGFloat(i) * holderSpacing, y: topY)
        }

        // Bottom row
        let bottomTotalWidth = CGFloat(bottomRowCount - 1) * holderSpacing
        let bottomStartX = centerX - bottomTotalWidth / 2
        let bottomPositions = (0..<bottomRowCount).map { i in
            CGPoint(x: bottomStartX + CGFloat(i) * holderSpacing, y: bottomY)
        }

        return topPositions + bottomPositions
    }

    // MARK: - Input Handling

    /// Unified tap handler for all platforms. Mirrors Unity LevelManager.Update() input detection.
    private func handleTap(at point: CGPoint) {
        guard gameState == .playing, !isTransferring else { return }

        guard let holder = holder(at: point) else {
            // Tapped empty space — clear any pending holder
            if let pending = holders.first(where: { $0.isPending }) {
                pending.clearPending()
            }
            return
        }

        handleHolderSelection(holder)
    }

    /// Find the holder at the given scene coordinate using bounding rect hit test.
    /// Replaces Unity's Physics2D.OverlapPoint approach.
    private func holder(at point: CGPoint) -> HolderNode? {
        let hitPadding: CGFloat = 12
        return holders.first { holder in
            CGRect(
                x: holder.position.x - HolderNode.outerWidth / 2 - hitPadding,
                y: holder.position.y - hitPadding,
                width: HolderNode.outerWidth + hitPadding * 2,
                height: HolderNode.innerHeight + HolderNode.pendingOffset + hitPadding * 2
            ).contains(point)
        }
    }

    /// Core interaction logic. Faithfully mirrors Unity LevelManager.OnClickHolder(Holder).
    private func handleHolderSelection(_ holder: HolderNode) {
        let pendingHolder = holders.first(where: { $0.isPending })

        if let pending = pendingHolder, pending !== holder {
            // A different holder is pending — check if transfer is valid
            if holder.topLiquid == nil ||
                (pending.topLiquid?.groupId == holder.topLiquid?.groupId && !holder.isFull)
            {
                // Valid transfer — start pour animation
                isTransferring = true
                pending.pourLiquid(to: holder, in: self) { [weak self] in
                    guard let self else { return }
                    self.isTransferring = false
                    self.updateAccessibility()
                    self.checkWinCondition()
                }
            } else {
                // Invalid transfer — switch pending to tapped holder
                pending.clearPending()
                if !holder.isEmpty {
                    holder.startPending()
                }
                updateAccessibility()
            }
        } else if !holder.isEmpty {
            // No pending holder, or tapped the same pending holder — toggle
            if holder.isPending {
                holder.clearPending()
            } else {
                holder.startPending()
            }
            updateAccessibility()
        }
    }

    // MARK: - Win Condition

    /// Checks if the puzzle is solved. Faithfully mirrors Unity LevelManager.CheckAndGameOver():
    /// - Every holder has 0 or 1 liquid segments
    /// - Each color (groupId) appears in exactly one holder
    private func checkWinCondition() {
        // All holders must have at most 1 liquid segment
        let allSimple = holders.allSatisfy { $0.liquids.count <= 1 }
        guard allSimple else { return }

        // Each color must appear in exactly one holder
        let groupIds = holders.compactMap(\.liquids.first?.groupId)
        guard groupIds.count == Set(groupIds).count else { return }

        // Puzzle solved!
        gameOver()
    }

    /// Handle level completion. Mirrors Unity LevelManager.OverTheGame().
    private func gameOver() {
        guard gameState == .playing else { return }
        gameState = .over

        SoundManager.shared.play(.win, on: self)

        // Save progress via callback (decoupled from GameManager)
        if let level {
            onSaveProgress?(gameMode, level.number)
        }

        // Show confetti effect (skip if reduce motion is on)
        if !reduceMotion {
            createConfettiEffect()
        }

        // Notify SwiftUI after a short delay
        let wait = SKAction.wait(forDuration: 1.2)
        run(wait) { [weak self] in
            self?.onLevelComplete?()
        }
    }

    // MARK: - Win Effects

    /// Confetti effect using SKEmitterNode — Apple's built-in GPU-accelerated particle system.
    /// Replaces 60 manually-animated SKShapeNodes with efficient particle emitters.
    private func createConfettiEffect() {
        let colors = ColorPalette.colors
        let particlesPerColor = max(60 / colors.count, 1)

        for color in colors {
            let emitter = SKEmitterNode()
            emitter.numParticlesToEmit = particlesPerColor
            emitter.particleBirthRate = CGFloat(particlesPerColor) * 4
            emitter.particleLifetime = 2.5
            emitter.particleLifetimeRange = 1.0
            emitter.position = CGPoint(x: size.width / 2, y: size.height + 20)
            emitter.particlePositionRange = CGVector(dx: size.width * 0.8, dy: 0)
            emitter.yAcceleration = -200
            emitter.particleSpeed = 80
            emitter.particleSpeedRange = 40
            emitter.emissionAngle = .pi * 1.5
            emitter.emissionAngleRange = .pi * 0.5
            emitter.particleAlphaSpeed = -0.4
            emitter.particleRotationSpeed = .pi * 2
            emitter.particleRotationRange = .pi * 2
            emitter.particleSize = CGSize(width: 8, height: 8)
            emitter.particleColor = color
            emitter.particleColorBlendFactor = 1.0
            emitter.zPosition = 200
            addChild(emitter)

            emitter.run(.sequence([.wait(forDuration: 5.0), .removeFromParent()]))
        }
    }

    // MARK: - Restart

    /// Remove all holders and reload the level from scratch.
    func restart() {
        // Cancel any pending actions on the scene (e.g. onLevelComplete delay from gameOver)
        removeAllActions()

        holders.forEach { $0.removeFromParent() }
        holders.removeAll()
        isTransferring = false
        gameState = .playing

        // Remove any lingering effects (confetti, liquid lines)
        children.filter { $0.zPosition >= 50 }.forEach { $0.removeFromParent() }

        loadLevel()
        updateAccessibility()
    }

    // MARK: - Platform Input

    #if os(macOS)
    override func mouseDown(with event: NSEvent) {
        let point = event.location(in: self)
        handleTap(at: point)
    }
    #else
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let point = touch.location(in: self)
        handleTap(at: point)
    }
    #endif

    // MARK: - Accessibility

    #if os(iOS) || os(visionOS)
    /// Provides VoiceOver accessibility elements for each tube in the game.
    ///
    /// Each holder is represented as an accessibility element with a label
    /// describing its contents (colors from bottom to top) and its state.
    override var accessibilityElements: [Any]? {
        get {
            holders.enumerated().map { index, holder in
                let element = UIAccessibilityElement(accessibilityContainer: self)
                let tubeNumber = index + 1

                // Build description of tube contents
                let description: String
                if holder.isEmpty {
                    description = "Tube \(tubeNumber), empty"
                } else if holder.isPending {
                    description = "Tube \(tubeNumber), selected, \(holder.accessibilityContentDescription)"
                } else {
                    description = "Tube \(tubeNumber), \(holder.accessibilityContentDescription)"
                }

                element.accessibilityLabel = description
                element.accessibilityHint = holder.isEmpty && !holders.contains(where: { $0.isPending })
                    ? "Empty tube, select a tube with liquid first"
                    : "Double tap to select or pour"
                element.accessibilityTraits = .button

                // Convert holder position to screen coordinates for the accessibility frame
                if let view = self.view {
                    let scenePoint = holder.position
                    let viewPoint = convertPoint(toView: scenePoint)
                    let screenPoint = view.convert(viewPoint, to: nil)
                    let frameSize = CGSize(width: 60, height: 200)
                    element.accessibilityFrame = CGRect(
                        x: screenPoint.x - frameSize.width / 2,
                        y: screenPoint.y - frameSize.height / 2,
                        width: frameSize.width,
                        height: frameSize.height
                    )
                }

                // Custom action to tap the holder
                element.accessibilityActivationPoint = self.view.map {
                    let viewPoint = convertPoint(toView: holder.position)
                    return $0.convert(viewPoint, to: nil)
                } ?? .zero

                return element
            }
        }
        set { /* Required by protocol */ }
    }
    #endif

    /// Updates VoiceOver after game state changes (pour, restart, etc.).
    private func updateAccessibility() {
        #if os(iOS) || os(visionOS)
        UIAccessibility.post(notification: .layoutChanged, argument: nil)
        #endif
    }
}
