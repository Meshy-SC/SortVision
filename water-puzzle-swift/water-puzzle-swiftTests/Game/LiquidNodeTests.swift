import SpriteKit
import Testing

@testable import water_puzzle_swift

@Suite("LiquidNode")
@MainActor
struct LiquidNodeTests {

    // MARK: - Initialization

    @Test("Initializes with correct groupId and value")
    func initProperties() {
        let node = LiquidNode(groupId: 3, value: 2.5)
        #expect(node.groupId == 3)
        #expect(node.value == 2.5)
    }

    @Test("Default value is 0")
    func defaultValue() {
        let node = LiquidNode(groupId: 0)
        #expect(node.value == 0)
    }

    // MARK: - Value Clamping

    @Test("Negative value is clamped to 0")
    func negativeValueClamped() {
        let node = LiquidNode(groupId: 1, value: 2.0)
        node.value = -5.0
        #expect(node.value == 0)
    }

    @Test("Zero value is accepted")
    func zeroValue() {
        let node = LiquidNode(groupId: 1, value: 2.0)
        node.value = 0
        #expect(node.value == 0)
    }

    @Test("Large value is accepted without clamping")
    func largeValue() {
        let node = LiquidNode(groupId: 1)
        node.value = 100
        #expect(node.value == 100)
    }

    // MARK: - Visual Height

    @Test("visualHeight equals value × unitSize",
          arguments: [0.0, 1.0, 2.5, 4.0] as [CGFloat])
    func visualHeightCalculation(value: CGFloat) {
        let node = LiquidNode(groupId: 0, value: value)
        #expect(node.visualHeight == value * LiquidNode.unitSize)
    }

    // MARK: - Liquid Color

    @Test("liquidColor returns matching palette color for valid groupId",
          arguments: 0..<11)
    func liquidColorMatchesPalette(groupId: Int) {
        let node = LiquidNode(groupId: groupId)
        #expect(node.liquidColor == ColorPalette.color(for: groupId))
    }

    // MARK: - Bottom Liquid State

    @Test("isBottomLiquid defaults to false")
    func bottomLiquidDefault() {
        let node = LiquidNode(groupId: 1, value: 2.0)
        #expect(!node.isBottomLiquid)
    }

    @Test("isBottomLiquid can be toggled")
    func toggleBottomLiquid() {
        let node = LiquidNode(groupId: 1, value: 2.0)
        node.isBottomLiquid = true
        #expect(node.isBottomLiquid)
        node.isBottomLiquid = false
        #expect(!node.isBottomLiquid)
    }

    // MARK: - Constants

    @Test("unitSize is a positive value")
    func unitSizePositive() {
        #expect(LiquidNode.unitSize > 0)
    }

    @Test("bottomCapHeight is a positive value less than unitSize")
    func bottomCapHeightValid() {
        #expect(LiquidNode.bottomCapHeight > 0)
        #expect(LiquidNode.bottomCapHeight < LiquidNode.unitSize)
    }
}
