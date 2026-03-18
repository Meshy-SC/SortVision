import Foundation
import Observation

/// Represents a single liquid segment in a tube with a color group and volume.
///
/// Used by `TubeState` to track the liquid contents. Segments with the
/// same `groupId` that are adjacent get merged during pour operations.
struct Liquid: Identifiable, Equatable {
    let id = UUID()
    /// Index into `ColorPalette.colors` (0–11).
    let groupId: Int
    /// Number of liquid units this segment occupies.
    var value: CGFloat
}

/// Represents the state of a single tube in the puzzle.
///
/// Observable so SwiftUI can react to changes in liquid contents
/// and selection state.
@Observable
final class TubeState: Identifiable {
    let id = UUID()

    /// Maximum liquid units per tube.
    static let maxValue: Int = 4

    /// Index in the game's holder array.
    let index: Int

    /// The liquid segments in this tube, ordered bottom to top.
    var liquids: [Liquid] = []

    /// Whether this tube is in the raised "selected" state.
    var isPending: Bool = false

    /// Vertical offset applied during pour animation (e.g. lift, arc).
    var animationOffsetY: CGFloat = 0

    /// Horizontal offset applied during pour animation (moving toward target).
    var animationOffsetX: CGFloat = 0

    /// Rotation angle (radians) applied during pour (tilt).
    var tiltAngle: CGFloat = 0

    init(index: Int) {
        self.index = index
    }

    // MARK: - Computed Properties

    var isFull: Bool { Int(totalLiquidValue.rounded()) >= Self.maxValue }
    var isEmpty: Bool { liquids.isEmpty }
    var topLiquid: Liquid? { liquids.last }
    var totalLiquidValue: CGFloat { liquids.reduce(0) { $0 + $1.value } }

    /// Remaining capacity in liquid units.
    var remainingCapacity: CGFloat {
        CGFloat(Self.maxValue) - totalLiquidValue
    }

    // MARK: - Population

    /// Fills the tube with compressed liquid segments from level data.
    func populate(with segments: [LiquidSegment]) {
        liquids = segments.map { Liquid(groupId: $0.groupId, value: $0.value) }
    }

    // MARK: - Liquid Management

    /// Adds a liquid segment to the top of the tube.
    func addLiquid(groupId: Int, value: CGFloat) {
        liquids.append(Liquid(groupId: groupId, value: value))
    }

    /// Removes the top liquid segment.
    @discardableResult
    func removeTopLiquid() -> Liquid? {
        liquids.popLast()
    }

    /// Resets all animation properties to their defaults.
    func resetAnimation() {
        animationOffsetX = 0
        animationOffsetY = 0
        tiltAngle = 0
        isPending = false
    }
}

/// Central game engine for the puzzle.
///
/// Manages tube states, selection, pour logic, and win detection.
/// Communicates results back to SwiftUI via closures.
@MainActor @Observable
final class GameEngine {

    // MARK: - Configuration

    var level: Level?
    var reduceMotion: Bool = false

    // MARK: - Callbacks

    var onLevelComplete: (() -> Void)?
    var onSaveProgress: ((Int, Int) -> Void)?  // (levelNumber, moveCount)

    // MARK: - Game State

    private(set) var tubes: [TubeState] = []
    private(set) var gameState: GameState = .idle
    private(set) var isTransferring: Bool = false
    private(set) var moveCount: Int = 0

    /// Active pour animation info for the stream overlay.
    private(set) var pourAnimation: PourAnimation? = nil

    enum GameState {
        case idle, playing, over
    }

    /// Describes an active pour for the view layer to render the liquid stream.
    struct PourAnimation: Equatable {
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

        let pendingTube = tubes.first(where: { $0.isPending })

        if let pending = pendingTube, pending.id != tube.id {
            // A different tube is pending — check if transfer is valid
            if tube.topLiquid == nil ||
                (pending.topLiquid?.groupId == tube.topLiquid?.groupId && !tube.isFull)
            {
                // Valid transfer — start pour
                performPour(from: pending, to: tube)
            } else {
                // Invalid target — switch pending to tapped tube
                pending.isPending = false
                SoundManager.shared.play(.push)
                if !tube.isEmpty {
                    tube.isPending = true
                    SoundManager.shared.play(.pop)
                }
            }
        } else if !tube.isEmpty {
            // No pending, or tapped same pending — toggle
            if tube.isPending {
                tube.isPending = false
                SoundManager.shared.play(.push)
            } else {
                tube.isPending = true
                SoundManager.shared.play(.pop)
            }
        }
    }

    /// Called when the user taps empty space.
    func handleBackgroundTap() {
        guard gameState == .playing, !isTransferring else { return }
        if let pending = tubes.first(where: { $0.isPending }) {
            pending.isPending = false
            SoundManager.shared.play(.push)
        }
    }

    // MARK: - Pour Animation

    /// Tilt angle — ~90° to make tube roughly horizontal.
    private let pourTiltAngle: CGFloat = 90.0 * .pi / 180.0

    /// Height to lift the tube (negative = up). With .bottom anchor,
    /// we need the bottom of the tube to be well above the other tubes
    /// so when tilted 90° the mouth swings over to the target's opening.
    private let arcLiftHeight: CGFloat = -180

    private func performPour(from source: TubeState, to target: TubeState) {
        guard let sourceLiquid = source.topLiquid,
              !target.isFull,
              target.topLiquid == nil || target.topLiquid?.groupId == sourceLiquid.groupId
        else { return }

        source.isPending = false
        isTransferring = true
        moveCount += 1

        let transferValue = min(
            sourceLiquid.value,
            target.remainingCapacity
        )

        let colorGroupId = sourceLiquid.groupId

        // Direction: tilt toward target.
        let isTargetRight = target.index > source.index
        let tiltSign: CGFloat = isTargetRight ? 1.0 : -1.0
        let signedTilt = tiltSign * pourTiltAngle

        pourAnimation = PourAnimation(
            sourceIndex: source.index,
            targetIndex: target.index,
            colorGroupId: colorGroupId
        )

        Task { @MainActor in
            let frameDuration: UInt64 = 16_000_000 // ~60 fps (16ms)

            // === Phase 1: Lift tube up high ===
            await animateValue(duration: 0.22, frameDuration: frameDuration) { t in
                let eased = Self.easeInOut(t)
                source.animationOffsetY = self.arcLiftHeight * eased
            }

            // === Phase 2: Tilt 90° — mouth swings over toward target ===
            await animateValue(duration: 0.28, frameDuration: frameDuration) { t in
                let eased = Self.easeInOut(t)
                source.tiltAngle = signedTilt * eased
            }

            // === Phase 3: Pour with stream ===
            SoundManager.shared.play(.water)
            pourAnimation?.isStreaming = true

            let sourceStartValue = sourceLiquid.value
            var targetStartValue: CGFloat = 0
            if let existing = target.topLiquid, existing.groupId == colorGroupId {
                targetStartValue = existing.value
            } else {
                target.addLiquid(groupId: colorGroupId, value: 0)
            }

            await animateValue(duration: 0.45, frameDuration: frameDuration) { t in
                let eased = Self.easeInOut(t)

                // Update liquid values
                if let srcIdx = source.liquids.indices.last {
                    source.liquids[srcIdx].value = sourceStartValue - transferValue * eased
                }
                if let tgtIdx = target.liquids.indices.last {
                    target.liquids[tgtIdx].value = targetStartValue + transferValue * eased
                }

                self.pourAnimation?.pourProgress = eased
            }

            pourAnimation?.isStreaming = false

            // === Phase 4: Untilt + return horizontal ===
            let currentTilt = source.tiltAngle
            let currentX = source.animationOffsetX
            await animateValue(duration: 0.22, frameDuration: frameDuration) { t in
                let eased = Self.easeInOut(t)
                source.tiltAngle = currentTilt * (1.0 - eased)
                source.animationOffsetX = currentX * (1.0 - eased)
            }

            // === Phase 5: Return down ===
            let currentLift = source.animationOffsetY
            await animateValue(duration: 0.18, frameDuration: frameDuration) { t in
                source.animationOffsetY = currentLift * (1.0 - t)
            }

            // === Clean up ===
            source.resetAnimation()
            pourAnimation = nil

            // Snap liquid values
            if let last = source.liquids.last, last.value <= 0.05 {
                source.removeTopLiquid()
            } else if let srcIdx = source.liquids.indices.last {
                source.liquids[srcIdx].value = source.liquids[srcIdx].value.rounded()
            }
            if let tgtIdx = target.liquids.indices.last {
                target.liquids[tgtIdx].value = target.liquids[tgtIdx].value.rounded()
            }

            isTransferring = false
            checkWinCondition()
        }
    }

    // MARK: - Animation Helpers

    /// Drives a closure with `t` from 0→1 over `duration` seconds at ~60fps.
    private func animateValue(
        duration: Double,
        frameDuration: UInt64,
        update: (CGFloat) -> Void
    ) async {
        let totalFrames = Int(duration / (Double(frameDuration) / 1_000_000_000.0))
        for frame in 1...max(totalFrames, 1) {
            let t = CGFloat(frame) / CGFloat(totalFrames)
            update(min(t, 1.0))
            try? await Task.sleep(nanoseconds: frameDuration)
        }
    }

    /// Smooth ease-in-out curve.
    private static func easeInOut(_ t: CGFloat) -> CGFloat {
        t * t * (3.0 - 2.0 * t)
    }

    // MARK: - Win Condition

    private func checkWinCondition() {
        let allSimple = tubes.allSatisfy { $0.liquids.count <= 1 }
        guard allSimple else { return }

        let groupIds = tubes.compactMap(\.liquids.first?.groupId)
        guard groupIds.count == Set(groupIds).count else { return }

        gameOver()
    }

    private func gameOver() {
        guard gameState == .playing else { return }
        gameState = .over

        SoundManager.shared.play(.win)

        if let level {
            onSaveProgress?(level.number, moveCount)
        }

        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.2))
            onLevelComplete?()
        }
    }

    // MARK: - Restart

    func restart() {
        for tube in tubes {
            tube.resetAnimation()
        }
        tubes.removeAll()
        isTransferring = false
        pourAnimation = nil
        moveCount = 0
        gameState = .playing
        loadLevel()
    }
}
