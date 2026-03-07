import SpriteKit
import Testing

@testable import water_puzzle_swift

@Suite("HolderNode")
@MainActor
struct HolderNodeTests {

    // MARK: - Empty State

    @Test("Newly created holder is empty")
    func newHolderIsEmpty() {
        let holder = HolderNode()
        #expect(holder.isEmpty)
        #expect(!holder.isFull)
        #expect(holder.liquids.isEmpty)
        #expect(holder.topLiquid == nil)
        #expect(holder.totalLiquidValue == 0)
    }

    // MARK: - Populate

    @Test("populate fills holder with correct number of liquid segments")
    func populateCreatesSegments() {
        let holder = HolderNode()
        let segments = [
            LiquidSegment(groupId: 1, value: 2.0),
            LiquidSegment(groupId: 2, value: 2.0),
        ]
        holder.populate(with: segments)

        #expect(holder.liquids.count == 2)
        #expect(holder.totalLiquidValue == 4.0)
        #expect(holder.isFull)
    }

    @Test("populate with empty segments leaves holder empty")
    func populateWithEmptySegments() {
        let holder = HolderNode()
        holder.populate(with: [])

        #expect(holder.isEmpty)
        #expect(holder.liquids.isEmpty)
    }

    @Test("populate sets first liquid as bottom liquid")
    func populateSetsBottomLiquid() {
        let holder = HolderNode()
        let segments = [
            LiquidSegment(groupId: 0, value: 1.0),
            LiquidSegment(groupId: 1, value: 1.0),
        ]
        holder.populate(with: segments)

        #expect(holder.liquids[0].isBottomLiquid)
    }

    // MARK: - Full State

    @Test("isFull is true when total value reaches maxValue")
    func isFullAtCapacity() {
        let holder = HolderNode()
        holder.addLiquid(groupId: 1, value: 4.0, isFirst: true)

        #expect(holder.isFull)
    }

    @Test("isFull is false when below capacity")
    func isNotFullBelowCapacity() {
        let holder = HolderNode()
        holder.addLiquid(groupId: 1, value: 3.0, isFirst: true)

        #expect(!holder.isFull)
    }

    // MARK: - Top Liquid

    @Test("topLiquid returns the last added liquid")
    func topLiquidIsLast() {
        let holder = HolderNode()
        holder.addLiquid(groupId: 1, value: 2.0, isFirst: true)
        holder.addLiquid(groupId: 2, value: 1.0)

        #expect(holder.topLiquid?.groupId == 2)
    }

    // MARK: - Total Liquid Value

    @Test("totalLiquidValue sums all segment values")
    func totalValueSumsCorrectly() {
        let holder = HolderNode()
        holder.addLiquid(groupId: 1, value: 1.5, isFirst: true)
        holder.addLiquid(groupId: 2, value: 2.5)

        #expect(holder.totalLiquidValue == 4.0)
    }

    // MARK: - Add Liquid

    @Test("addLiquid increases liquid count")
    func addLiquidIncreasesCount() {
        let holder = HolderNode()
        #expect(holder.liquids.count == 0)

        holder.addLiquid(groupId: 1, value: 1.0, isFirst: true)
        #expect(holder.liquids.count == 1)

        holder.addLiquid(groupId: 2, value: 1.0)
        #expect(holder.liquids.count == 2)
    }

    @Test("addLiquid with isFirst marks segment as bottom")
    func addLiquidFirst() {
        let holder = HolderNode()
        holder.addLiquid(groupId: 0, value: 2.0, isFirst: true)

        #expect(holder.liquids[0].isBottomLiquid)
    }

    // MARK: - Pending State

    @Test("isPending is false by default")
    func notPendingByDefault() {
        let holder = HolderNode()
        #expect(!holder.isPending)
    }

    @Test("startPending sets isPending to true")
    func startPendingSetsFlag() {
        let holder = HolderNode()
        holder.addLiquid(groupId: 1, value: 1.0, isFirst: true)
        holder.startPending()

        #expect(holder.isPending)
    }

    @Test("clearPending resets isPending to false")
    func clearPendingResetsFlag() {
        let holder = HolderNode()
        holder.addLiquid(groupId: 1, value: 1.0, isFirst: true)
        holder.startPending()
        holder.clearPending()

        #expect(!holder.isPending)
    }

    @Test("startPending on already pending holder is idempotent")
    func doubleStartPending() {
        let holder = HolderNode()
        holder.addLiquid(groupId: 1, value: 1.0, isFirst: true)
        holder.startPending()
        holder.startPending() // Should not crash or change state

        #expect(holder.isPending)
    }

    @Test("clearPending on non-pending holder is idempotent")
    func clearNonPending() {
        let holder = HolderNode()
        holder.clearPending() // Should not crash

        #expect(!holder.isPending)
    }

    // MARK: - Reposition Liquids

    @Test("repositionLiquids sets first liquid as bottom")
    func repositionSetsBottom() {
        let holder = HolderNode()
        holder.addLiquid(groupId: 1, value: 1.0, isFirst: true)
        holder.addLiquid(groupId: 2, value: 1.0)
        holder.repositionLiquids()

        #expect(holder.liquids[0].isBottomLiquid)
        #expect(!holder.liquids[1].isBottomLiquid)
    }

    // MARK: - Top Stack Height

    @Test("topStackHeight is sum of all visual heights")
    func topStackHeightCalculation() {
        let holder = HolderNode()
        holder.addLiquid(groupId: 1, value: 2.0, isFirst: true)
        holder.addLiquid(groupId: 2, value: 1.0)

        let expectedHeight = 2.0 * LiquidNode.unitSize + 1.0 * LiquidNode.unitSize
        #expect(holder.topStackHeight == expectedHeight)
    }

    // MARK: - Constants

    @Test("maxValue is 4 (standard tube capacity)")
    func maxValueIs4() {
        #expect(HolderNode.maxValue == 4)
    }

    @Test("pourAngle is 82 degrees")
    func pourAngleCorrect() {
        #expect(HolderNode.pourAngleDegrees == 82.0)
        let expectedRadians = 82.0 * .pi / 180.0
        #expect(abs(HolderNode.pourAngleInRadians - expectedRadians) < 0.001)
    }
}
