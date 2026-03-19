import CoreGraphics
import Foundation
import Observation

/// Represents a single liquid segment in a tube with a color group and volume.
///
/// Used by `TubeState` to track the liquid contents. Segments with the
/// same `groupId` that are adjacent get merged during pour operations.
struct Liquid: Identifiable, Equatable, Hashable, Sendable {
    let id: UUID
    /// Index into `ColorPalette.colors` (0–11).
    let groupId: Int
    /// Number of liquid units this segment occupies.
    var value: CGFloat

    init(groupId: Int, value: CGFloat) {
        self.id = UUID()
        self.groupId = groupId
        self.value = value
    }
}

/// Represents the state of a single tube in the puzzle.
///
/// Observable so SwiftUI can react to changes in liquid contents
/// and selection state. Each tube tracks its own animation transforms
/// independently to support concurrent pour animations.
///
/// ## Capacity
/// Every tube holds a maximum of `maxValue` (4) liquid units.
///
/// ## Animation State
/// Animation properties (`animationOffsetX/Y`, `tiltAngle`) are driven
/// by `GameEngine` during pour sequences and should not be modified
/// directly by views.
@MainActor @Observable
final class TubeState: Identifiable {
    let id = UUID()

    /// Maximum liquid units per tube.
    nonisolated static let maxValue: Int = 4

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

    /// Whether this tube is currently in a pour animation.
    var isAnimating: Bool {
        tiltAngle != 0 || animationOffsetX != 0 || animationOffsetY != 0
    }

    init(index: Int) {
        self.index = index
    }

    // MARK: - Computed Properties

    /// Whether the tube is completely full (total liquid ≥ maxValue).
    var isFull: Bool { Int(totalLiquidValue.rounded()) >= Self.maxValue }

    /// Whether the tube contains no liquid.
    var isEmpty: Bool { liquids.isEmpty }

    /// The topmost liquid segment, or `nil` if the tube is empty.
    var topLiquid: Liquid? { liquids.last }

    /// Total liquid volume across all segments.
    var totalLiquidValue: CGFloat { liquids.reduce(0) { $0 + $1.value } }

    /// Remaining capacity in liquid units.
    var remainingCapacity: CGFloat {
        CGFloat(Self.maxValue) - totalLiquidValue
    }

    // MARK: - Population

    /// Fills the tube with compressed liquid segments from level data.
    ///
    /// - Parameter segments: Array of `LiquidSegment` values defining
    ///   the initial contents, ordered bottom to top.
    func populate(with segments: [LiquidSegment]) {
        liquids = segments.map { Liquid(groupId: $0.groupId, value: $0.value) }
    }

    // MARK: - Liquid Management

    /// Adds a liquid segment to the top of the tube.
    ///
    /// - Parameters:
    ///   - groupId: Color group index for the liquid.
    ///   - value: Volume in liquid units.
    func addLiquid(groupId: Int, value: CGFloat) {
        liquids.append(Liquid(groupId: groupId, value: value))
    }

    /// Removes and returns the top liquid segment.
    ///
    /// - Returns: The removed segment, or `nil` if the tube was empty.
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
