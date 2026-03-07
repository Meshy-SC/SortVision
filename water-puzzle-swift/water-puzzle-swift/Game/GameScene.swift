import SpriteKit

/// Main gameplay scene. Faithfully mirrors Unity's LevelManager:
/// - Loads level data and creates tube layout (1 or 2 rows)
/// - Handles tap input to select tubes and initiate pours
/// - Manages game state (Playing, Over)
/// - Checks win condition after each pour
/// - Plays win sound and confetti effect on completion
final class GameScene: SKScene {

    // MARK: - Level Configuration

    var level: Level?
    var gameMode: GameMode = .easy

    // MARK: - Callbacks (bridge to SwiftUI)

    /// Called when the level is completed (triggers UI overlay).
    var onLevelComplete: (() -> Void)?

    /// Called to persist level completion progress.
    /// Decouples the SpriteKit layer from `GameManager` — the SwiftUI host
    /// provides this closure to bridge back to the data layer.
    var onSaveProgress: ((GameMode, Int) -> Void)?

    // MARK: - Game State

    private var holders: [HolderNode] = []
    private var isTransferring = false
    private var gameState: GameState = .none

    /// Horizontal distance between tube centers.
    /// Mirrors Unity LevelManager._minXDistanceBetweenHolders.
    private let holderSpacing: CGFloat = 80

    enum GameState {
        case none, playing, over
    }

    // MARK: - Scene Lifecycle

    override func didMove(to view: SKView) {
        backgroundColor = SKColor(red: 0.12, green: 0.15, blue: 0.22, alpha: 1.0)
        loadLevel()
        gameState = .playing
    }

    // MARK: - Level Loading

    /// Creates holder nodes from level data and positions them.
    /// Mirrors Unity LevelManager.LoadLevel().
    private func loadLevel() {
        guard let level else { return }

        let holderCount = level.map.count
        let positions = positionsForHolders(count: holderCount)
        let liquidDataMap = level.liquidDataMap

        for i in 0..<holderCount {
            let holder = HolderNode()
            holder.position = positions[i]
            addChild(holder)
            holder.initialize(with: liquidDataMap[i])
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

        guard let holder = holderAt(point: point) else {
            // Tapped empty space — clear any pending holder
            if let pending = holders.first(where: { $0.isPending }) {
                pending.clearPending()
            }
            return
        }

        onClickHolder(holder)
    }

    /// Find the holder at the given scene coordinate using bounding rect hit test.
    /// Replaces Unity's Physics2D.OverlapPoint approach.
    private func holderAt(point: CGPoint) -> HolderNode? {
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
    private func onClickHolder(_ holder: HolderNode) {
        let pendingHolder = holders.first(where: { $0.isPending })

        if let pending = pendingHolder, pending !== holder {
            // A different holder is pending — check if transfer is valid
            if holder.topLiquid == nil ||
                (pending.topLiquid?.groupId == holder.topLiquid?.groupId && !holder.isFull)
            {
                // Valid transfer — start pour animation
                isTransferring = true
                pending.pourLiquid(to: holder, in: self) { [weak self] in
                    MainActor.assumeIsolated {
                        guard let self else { return }
                        self.isTransferring = false
                        self.checkWinCondition()
                    }
                }
            } else {
                // Invalid transfer — switch pending to tapped holder
                pending.clearPending()
                if !holder.isEmpty {
                    holder.startPending()
                }
            }
        } else if !holder.isEmpty {
            // No pending holder, or tapped the same pending holder — toggle
            if holder.isPending {
                holder.clearPending()
            } else {
                holder.startPending()
            }
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
            onSaveProgress?(gameMode, level.no)
        }

        // Show confetti effect
        createConfettiEffect()

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
}
