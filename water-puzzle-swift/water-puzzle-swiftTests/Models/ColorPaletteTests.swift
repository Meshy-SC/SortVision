import SpriteKit
import Testing

@testable import water_puzzle_swift

@Suite("ColorPalette")
struct ColorPaletteTests {

    @Test("Palette contains exactly 11 colors (groupIds 0–10)")
    func colorCount() {
        #expect(ColorPalette.colors.count == 11)
    }

    @Test("Valid groupIds return non-white colors",
          arguments: 0..<11)
    func validGroupIdReturnsColor(groupId: Int) {
        let color = ColorPalette.color(for: groupId)
        #expect(color != .white, "GroupId \(groupId) should return a palette color, not white")
    }

    @Test("Out-of-bounds groupId returns white fallback",
          arguments: [-1, 11, 100, -50])
    func outOfBoundsReturnsWhite(groupId: Int) {
        let color = ColorPalette.color(for: groupId)
        #expect(color == .white)
    }

    @Test("All palette colors have full opacity")
    func allColorsFullOpacity() {
        for (index, color) in ColorPalette.colors.enumerated() {
            var alpha: CGFloat = 0
            #if os(macOS)
            alpha = color.alphaComponent
            #else
            color.getRed(nil, green: nil, blue: nil, alpha: &alpha)
            #endif
            #expect(alpha == 1.0, "Color at index \(index) should have alpha 1.0")
        }
    }

    @Test("Each palette color is distinct from its neighbors")
    func adjacentColorsAreDistinct() {
        for i in 0..<(ColorPalette.colors.count - 1) {
            let a = ColorPalette.colors[i]
            let b = ColorPalette.colors[i + 1]
            #expect(a != b, "Colors at indices \(i) and \(i + 1) should be visually distinct")
        }
    }
}
