import CoreGraphics
import Foundation
import Observation

/// Central game engine for the puzzle.
///
/// Manages tube states, selection, pour logic, and win detection.
/// Communicates results back to SwiftUI via closures.
@MainActor @Observable
final class GameEngine {

    // MARK: - Configuration

    var level: Level?

    /// Sound player for game audio effects. Injectable for testing.
    var soundPlayer: SoundPlayable = SoundManager.shared

    // MARK: - Callbacks

    var onLevelComplete: (() -> Void)?

    /// Called when a level is completed with the level number and move count.
    ///
    /// - Parameter levelNumber: The global level number that was completed.
    /// - Parameter moveCount: The number of moves the player used.
    var onRecordLevelResult: ((_ levelNumber: Int, _ moveCount: Int) -> Void)?

    // MARK: - Game State

    private(set) var tubes: [TubeState] = []
    private(set) var gameState: GameState = .idle
    private(set) var isTransferring: Bool = false
    private(set) var moveCount: Int = 0

    /// Undo history: snapshots of tube liquid contents before each pour.
    private var undoHistory: [[[Liquid]]] = []

    /// Active pour animation task, cancelled on restart to prevent stale state mutations.
    private var pourTask: Task<Void, Never>?

    /// Whether the player can undo a move.
    var canUndo: Bool { !undoHistory.isEmpty && gameState == .playing && !isTransferring }

    /// Active pour animation info for the stream overlay.
    private(set) var pourAnimation: PourAnimation? = nil

    /// Base tube frames in scene coordinates, used for pour mouth alignment.
    /// Updated by the scene view. Ignored by observation to prevent extra renders.
    @ObservationIgnored var tubeFrames: [Int: CGRect] = [:]

    /// Current view scale factor applied to each tube (1.0 = no scale).
    /// Updated by the scene view. Ignored by observation to prevent extra renders.
    @ObservationIgnored var viewScale: CGFloat = 1.0

    enum GameState: Sendable {
        case idle, playing, over
    }

    /// Describes an active pour for the view layer to render the liquid stream.
    struct PourAnimation: Equatable, Sendable {
        let sourceIndex: Int
        let targetIndex: Int
        let colorGroupId: Int
        /// 0…1 progress of liquid transfer.
        var pourProgress: CGFloat = 0
        /// Whether the stream should be visible (true during the pour phase).
        var isStreaming: Bool = false
    }

    // MARK: - Setup

    /// Call once after setting `level` to initialise the game.
    func setup() {
        loadLevel()
        moveCount = 0
        gameState = .playing
    }

    // MARK: - Level Loading

    private func loadLevel() {
        guard let level else { return }

        let segments = level.compressedLiquidSegments
        tubes = (0..<level.columns.count).map { i in
            let tube = TubeState(index: i)
            tube.populate(with: segments[i])
            return tube
        }
    }

    // MARK: - Tap Handling

    /// Called when a tube is tapped.
    func handleTubeTap(_ tube: TubeState) {
        guard gameState == .playing, !isTransferring else { return }

        let selected = tubes.first { $0.isSelected }

        switch (selected, tube.isEmpty) {
        case let (selected?, _) where selected.id != tube.id:
            // A different tube is selected — check if transfer is valid
            let canPour = tube.topLiquid == nil
                || (selected.topLiquid?.groupId == tube.topLiquid?.groupId && !tube.isFull)
            if canPour {
                performPour(from: selected, to: tube)
            } else {
                // Invalid target — switch selection to tapped tube
                selected.isSelected = false
                soundPlayer.play(.push)
                guard !tube.isEmpty else { break }
                tube.isSelected = true
                soundPlayer.play(.pop)
            }

        case (_, false):
            // No selection (or tapped same selected tube) — toggle
            tube.isSelected.toggle()
            soundPlayer.play(tube.isSelected ? .pop : .push)

        default:
            break
        }
    }

    /// Called when the user taps empty space.
    func handleBackgroundTap() {
        guard gameState == .playing, !isTransferring else { return }
        if let selected = tubes.first(where: { $0.isSelected }) {
            selected.isSelected = false
            soundPlayer.play(.push)
        }
    }

    // MARK: - Pour Animation

    /// Tilt angle delegated to PourAnimator.
    private var pourTiltAngle: CGFloat { PourAnimator.pourTiltAngle }

    private func performPour(from source: TubeState, to target: TubeState) {
        guard let sourceLiquid = source.topLiquid,
              !target.isFull,
              target.topLiquid == nil || target.topLiquid?.groupId == sourceLiquid.groupId
        else { return }

        source.isSelected = false
        isTransferring = true
        moveCount += 1

        // Snapshot tube liquids for undo
        undoHistory.append(tubes.map { $0.liquids })

        let transferVolume = min(
            sourceLiquid.volume,
            target.remainingCapacity
        )

        let colorGroupId = sourceLiquid.groupId

        // Get base frames for mouth-alignment positioning
        let sourceFrame = tubeFrames[source.index] ?? .zero
        let targetFrame = tubeFrames[target.index] ?? .zero

        // Direction: tilt toward target (use frame positions for two-row support).
        let isTargetRight = targetFrame.midX >= sourceFrame.midX
        let tiltSign: CGFloat = isTargetRight ? 1.0 : -1.0
        let signedTilt = tiltSign * pourTiltAngle

        let targetLip = TubeView.lipPoint(in: targetFrame, scale: viewScale)
        let sourcePourLip = TubeView.rotate(
            offset: TubeView.pourLipOffset(toward: tiltSign, scale: viewScale),
            by: signedTilt
        )
        let pourTarget = CGPoint(
            x: targetLip.x,
            y: targetLip.y - TubeView.pourClearance * viewScale
        )

        // Final offsets keep the pouring lip above the target mouth with a small gap,
        // matching the reference behavior instead of intersecting the target tube.
        let finalOffsetX = pourTarget.x - sourceFrame.midX - sourcePourLip.x
        let finalOffsetY = pourTarget.y - sourceFrame.midY - sourcePourLip.y

        // Prevent isSelected spring by marking as animating immediately
        source.animationOffsetY = -0.01

        pourAnimation = PourAnimation(
            sourceIndex: source.index,
            targetIndex: target.index,
            colorGroupId: colorGroupId
        )

        pourTask = Task { @MainActor in
            let frameDuration: UInt64 = 16_000_000 // ~60 fps (16ms)

            // === Phase 1: Lift tube center well above other tubes ===
            let liftHeight: CGFloat = -(TubeView.tubeHeight * self.viewScale + 10)
            await animateValue(duration: 0.22, frameDuration: frameDuration) { t in
                let eased = Self.easeInOut(t)
                source.animationOffsetY = liftHeight * eased
            }
            guard !Task.isCancelled else { return }

            // === Phase 2: Tilt and align above target ===
            // From the lifted position, tilt to pour angle while moving
            // horizontally so the pouring lip ends up just above the target opening.
            await animateValue(duration: 0.28, frameDuration: frameDuration) { t in
                let eased = Self.easeInOut(t)
                source.tiltAngle = signedTilt * eased
                source.animationOffsetX = finalOffsetX * eased
                source.animationOffsetY = liftHeight + (finalOffsetY - liftHeight) * eased
            }
            guard !Task.isCancelled else { return }

            // === Phase 3: Pour with stream ===
            soundPlayer.play(.water)
            pourAnimation?.isStreaming = true

            let sourceStartVolume = sourceLiquid.volume
            var targetStartVolume: CGFloat = 0
            if let existing = target.topLiquid, existing.groupId == colorGroupId {
                targetStartVolume = existing.volume
            } else {
                target.addLiquid(groupId: colorGroupId, volume: 0)
            }

            await animateValue(duration: 0.45, frameDuration: frameDuration) { t in
                let eased = Self.easeInOut(t)

                // Update liquid volumes
                if let srcIdx = source.liquids.indices.last {
                    source.liquids[srcIdx].volume = sourceStartVolume - transferVolume * eased
                }
                if let tgtIdx = target.liquids.indices.last {
                    target.liquids[tgtIdx].volume = targetStartVolume + transferVolume * eased
                }

                self.pourAnimation?.pourProgress = eased
            }
            guard !Task.isCancelled else { return }

            pourAnimation?.isStreaming = false

            // === Phase 4: Return to original position ===
            let currentTilt = source.tiltAngle
            let currentOffsetX = source.animationOffsetX
            let currentOffsetY = source.animationOffsetY

            await animateValue(duration: 0.32, frameDuration: frameDuration) { t in
                let eased = Self.easeInOut(t)
                source.tiltAngle = currentTilt * (1.0 - eased)
                source.animationOffsetX = currentOffsetX * (1.0 - eased)
                source.animationOffsetY = currentOffsetY * (1.0 - eased)
            }

            // === Clean up ===
            source.resetAnimation()
            pourAnimation = nil

            // Snap liquid volumes
            if let last = source.liquids.last {
                if last.volume <= 0.05 {
                    source.removeTopLiquid()
                } else {
                    source.liquids[source.liquids.count - 1].volume = last.volume.rounded()
                }
            }
            if let tgtIdx = target.liquids.indices.last {
                target.liquids[tgtIdx].volume = target.liquids[tgtIdx].volume.rounded()
            }

            isTransferring = false
            checkWinCondition()
        }
    }

    // MARK: - Animation Helpers

    /// Drives a closure with `t` from 0→1 over `duration` seconds at ~60fps.
    /// Delegates to `PourAnimator` for the actual timing loop.
    private func animateValue(
        duration: Double,
        frameDuration: UInt64,
        update: (CGFloat) -> Void
    ) async {
        await PourAnimator.animateValue(
            duration: duration,
            frameDuration: frameDuration,
            update: update
        )
    }

    /// Smooth ease-in-out curve.
    private static func easeInOut(_ t: CGFloat) -> CGFloat {
        PourAnimator.easeInOut(t)
    }

    // MARK: - Win Condition

    private func checkWinCondition() {
        guard tubes.allSatisfy({ $0.liquids.count <= 1 }) else { return }

        let groupIds = tubes.compactMap(\.liquids.first?.groupId)
        guard groupIds.count == Set(groupIds).count else { return }

        gameOver()
    }

    private func gameOver() {
        guard gameState == .playing else { return }
        gameState = .over

        soundPlayer.play(.win)

        if let level {
            onRecordLevelResult?(level.number, moveCount)
        }

        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.2))
            onLevelComplete?()
        }
    }

    // MARK: - Undo

    /// Reverts the last pour operation by restoring tube liquid snapshots.
    func undo() {
        guard canUndo, let snapshot = undoHistory.popLast() else { return }
        moveCount = max(0, moveCount - 1)

        for (tube, liquids) in zip(tubes, snapshot) {
            tube.liquids = liquids
            tube.resetAnimation()
        }
    }

    // MARK: - Restart

    func restart() {
        pourTask?.cancel()
        pourTask = nil
        tubes.forEach { $0.resetAnimation() }
        tubes.removeAll()
        isTransferring = false
        pourAnimation = nil
        moveCount = 0
        undoHistory.removeAll()
        gameState = .playing
        loadLevel()
    }
}
