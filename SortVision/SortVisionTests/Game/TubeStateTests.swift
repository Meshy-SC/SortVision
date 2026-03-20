import CoreGraphics
import Foundation
import Testing

@testable import SortVision

// MARK: - TubeState Tests

@Suite("TubeState")
@MainActor
struct TubeStateTests {

    // MARK: - Initialization

    @Test("New tube is empty with correct index")
    func newTubeIsEmpty() {
        let tube = TubeState(index: 3)

        #expect(tube.index == 3)
        #expect(tube.isEmpty)
        #expect(!tube.isFull)
        #expect(tube.topLiquid == nil)
        #expect(tube.totalVolume == 0)
        #expect(tube.remainingCapacity == CGFloat(TubeState.maxValue))
        #expect(!tube.isSelected)
        #expect(!tube.isAnimating)
    }

    // MARK: - Populate

    @Test("populate fills tube with liquid segments in order")
    func populateFromSegments() {
        let tube = TubeState(index: 0)
        let segments = [
            LiquidSegment(groupId: 1, volume: 2),
            LiquidSegment(groupId: 2, volume: 2),
        ]

        tube.populate(with: segments)

        #expect(tube.liquids.count == 2)
        #expect(tube.liquids[0].groupId == 1)
        #expect(tube.liquids[0].volume == 2.0)
        #expect(tube.liquids[1].groupId == 2)
        #expect(tube.liquids[1].volume == 2.0)
    }

    @Test("populate with empty segments leaves tube empty")
    func populateEmpty() {
        let tube = TubeState(index: 0)
        tube.populate(with: [])

        #expect(tube.isEmpty)
    }

    // MARK: - Capacity

    @Test("isFull returns true when total volume equals maxValue")
    func isFullAtMaxValue() {
        let tube = TubeState(index: 0)
        tube.addLiquid(groupId: 0, volume: 4.0)

        #expect(tube.isFull)
        #expect(tube.remainingCapacity == 0)
    }

    @Test("isFull returns false when below maxValue")
    func isNotFullBelowMax() {
        let tube = TubeState(index: 0)
        tube.addLiquid(groupId: 0, volume: 3.0)

        #expect(!tube.isFull)
        #expect(tube.remainingCapacity == 1.0)
    }

    @Test("totalVolume sums all liquid segments")
    func totalVolumeSumsSegments() {
        let tube = TubeState(index: 0)
        tube.addLiquid(groupId: 0, volume: 1.5)
        tube.addLiquid(groupId: 1, volume: 2.0)

        #expect(tube.totalVolume == 3.5)
    }

    // MARK: - Top Liquid

    @Test("topLiquid returns the last added liquid")
    func topLiquidReturnsLast() {
        let tube = TubeState(index: 0)
        tube.addLiquid(groupId: 0, volume: 1)
        tube.addLiquid(groupId: 1, volume: 1)

        #expect(tube.topLiquid?.groupId == 1)
    }

    @Test("topLiquid is nil for empty tube")
    func topLiquidNilForEmpty() {
        let tube = TubeState(index: 0)
        #expect(tube.topLiquid == nil)
    }

    // MARK: - Add / Remove Liquid

    @Test("addLiquid appends to the top")
    func addLiquidAppends() {
        let tube = TubeState(index: 0)
        tube.addLiquid(groupId: 5, volume: 2.0)

        #expect(tube.liquids.count == 1)
        #expect(tube.liquids[0].groupId == 5)
        #expect(tube.liquids[0].volume == 2.0)
    }

    @Test("removeTopLiquid removes and returns the top segment")
    func removeTopLiquid() {
        let tube = TubeState(index: 0)
        tube.addLiquid(groupId: 0, volume: 1)
        tube.addLiquid(groupId: 1, volume: 2)

        let removed = tube.removeTopLiquid()

        #expect(removed?.groupId == 1)
        #expect(removed?.volume == 2)
        #expect(tube.liquids.count == 1)
        #expect(tube.topLiquid?.groupId == 0)
    }

    @Test("removeTopLiquid on empty tube returns nil")
    func removeTopLiquidEmpty() {
        let tube = TubeState(index: 0)
        let removed = tube.removeTopLiquid()

        #expect(removed == nil)
        #expect(tube.isEmpty)
    }

    // MARK: - Animation State

    @Test("isAnimating detects any non-zero transform")
    func isAnimatingDetectsTransforms() {
        let tube = TubeState(index: 0)
        #expect(!tube.isAnimating)

        tube.tiltAngle = 0.5
        #expect(tube.isAnimating)

        tube.tiltAngle = 0
        tube.animationOffsetX = 10
        #expect(tube.isAnimating)

        tube.animationOffsetX = 0
        tube.animationOffsetY = -5
        #expect(tube.isAnimating)
    }

    @Test("resetAnimation clears all transform properties")
    func resetAnimationClears() {
        let tube = TubeState(index: 0)
        tube.tiltAngle = 1.5
        tube.animationOffsetX = 100
        tube.animationOffsetY = -50
        tube.isSelected = true

        tube.resetAnimation()

        #expect(tube.tiltAngle == 0)
        #expect(tube.animationOffsetX == 0)
        #expect(tube.animationOffsetY == 0)
        #expect(!tube.isSelected)
        #expect(!tube.isAnimating)
    }

    // MARK: - Liquid Struct

    @Test("Liquid Equatable compares by id, groupId, and volume")
    func liquidEquatable() {
        let a = Liquid(groupId: 1, volume: 2)
        let b = Liquid(groupId: 1, volume: 2)

        // Different UUIDs, so not equal by default Equatable
        // But the struct uses auto-synthesized Equatable which includes id
        #expect(a != b, "Different UUIDs should make them unequal")
        #expect(a.groupId == b.groupId)
        #expect(a.volume == b.volume)
    }

    @Test("Liquid Hashable conformance")
    func liquidHashable() {
        let a = Liquid(groupId: 1, volume: 2)
        let set: Set<Liquid> = [a]
        #expect(set.contains(a))
    }

    // MARK: - maxValue Constant

    @Test("maxValue is 4 (game design constant)")
    func maxValueIs4() {
        #expect(TubeState.maxValue == 4)
    }
}
