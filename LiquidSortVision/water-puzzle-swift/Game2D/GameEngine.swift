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
}

/// Central game engine for the 2D puzzle.
///
/// Manages tube states, selection, pour logic, and win detection.
/// Communicates results back to SwiftUI via closures.
@MainActor @Observable
final class GameEngine {

    // MARK: - Configuration

    var level: Level?
    var gameMode: GameMode = .easy
    var reduceMotion: Bool = false

    // MARK: - Callbacks

    var onLevelComplete: (() -> Void)?
    var onSaveProgress: ((GameMode, Int) -> Void)?

    // MARK: - Game State

    private(set) var tubes: [TubeState] = []
    private(set) var gameState: GameState = .idle
    private(set) var isTransferring: Bool = false

    /// Active pour animation info (source index, target index, progress 0…1).
    private(set) var pourAnimation: PourAnimation? = nil

    enum GameState {
        case idle, playing, over
    }

    /// Describes an active pour animation for the view layer.
    struct PourAnimation: Equatable {
        let sourceIndex: Int
        let targetIndex: Int
        var progress: CGFloat
    }

    // MARK: - Setup

    /// Call once after setting `level` to initialise the game.
    func setup() {
        loadLevel()
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

    // MARK: - Pour Logic

    private func performPour(from source: TubeState, to target: TubeState) {
        guard let sourceLiquid = source.topLiquid,
              !target.isFull,
              target.topLiquid == nil || target.topLiquid?.groupId == sourceLiquid.groupId
        else { return }

        source.isPending = false
        isTransferring = true

        let transferValue = min(
            sourceLiquid.value,
            target.remainingCapacity
        )

        // Set up pour animation
        pourAnimation = PourAnimation(
            sourceIndex: source.index,
            targetIndex: target.index,
            progress: 0
        )

        SoundManager.shared.play(.water)

        // Animate the pour over time
        Task { @MainActor in
            let steps = 20
            let stepDuration: Double = 0.025

            let sourceStartValue = sourceLiquid.value

            // Prepare target liquid
            var targetStartValue: CGFloat = 0
            if let existing = target.topLiquid, existing.groupId == sourceLiquid.groupId {
                targetStartValue = existing.value
            } else {
                target.addLiquid(groupId: sourceLiquid.groupId, value: 0)
            }

            for i in 1...steps {
                let t = CGFloat(i) / CGFloat(steps)

                // Update source
                if let srcIdx = source.liquids.indices.last {
                    source.liquids[srcIdx].value = sourceStartValue - transferValue * t
                }

                // Update target
                if let tgtIdx = target.liquids.indices.last {
                    target.liquids[tgtIdx].value = targetStartValue + transferValue * t
                }

                pourAnimation?.progress = t

                try? await Task.sleep(for: .milliseconds(Int(stepDuration * 1000)))
            }

            // Clean up
            pourAnimation = nil

            // Remove empty source liquid
            if let last = source.liquids.last, last.value <= 0.05 {
                source.removeTopLiquid()
            } else if let srcIdx = source.liquids.indices.last {
                source.liquids[srcIdx].value = source.liquids[srcIdx].value.rounded()
            }

            // Round target value
            if let tgtIdx = target.liquids.indices.last {
                target.liquids[tgtIdx].value = target.liquids[tgtIdx].value.rounded()
            }

            isTransferring = false
            checkWinCondition()
        }
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
            onSaveProgress?(gameMode, level.number)
        }

        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.2))
            onLevelComplete?()
        }
    }

    // MARK: - Restart

    func restart() {
        tubes.removeAll()
        isTransferring = false
        pourAnimation = nil
        gameState = .playing
        loadLevel()
    }
}
