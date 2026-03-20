import CoreGraphics
import Foundation
import SwiftUI
import Testing

@testable import SortVision

// MARK: - PourAnimator Tests

@Suite("PourAnimator")
struct PourAnimatorTests {

    // MARK: - Ease-In-Out Curve

    @Test("easeInOut(0) returns 0")
    func easeInOutAtZero() {
        #expect(PourAnimator.easeInOut(0) == 0)
    }

    @Test("easeInOut(1) returns 1")
    func easeInOutAtOne() {
        #expect(PourAnimator.easeInOut(1) == 1)
    }

    @Test("easeInOut(0.5) returns 0.5 (symmetric midpoint)")
    func easeInOutAtMidpoint() {
        #expect(PourAnimator.easeInOut(0.5) == 0.5)
    }

    @Test("easeInOut curve is monotonically increasing",
          arguments: stride(from: 0.0, through: 0.9, by: 0.1).map { $0 })
    func easeInOutMonotonic(t: Double) {
        let current = PourAnimator.easeInOut(CGFloat(t))
        let next = PourAnimator.easeInOut(CGFloat(t + 0.1))
        #expect(next >= current, "easeInOut should be monotonically increasing")
    }

    @Test("easeInOut output stays in [0, 1] range",
          arguments: stride(from: 0.0, through: 1.0, by: 0.05).map { $0 })
    func easeInOutInRange(t: Double) {
        let result = PourAnimator.easeInOut(CGFloat(t))
        #expect(result >= 0 && result <= 1, "easeInOut(\(t)) = \(result) should be in [0, 1]")
    }

    // MARK: - Pour Tilt Angle

    @Test("pourTiltAngle is approximately 95 degrees in radians")
    func pourTiltAngleValue() {
        let expected = 95.0 * .pi / 180.0
        #expect(abs(PourAnimator.pourTiltAngle - expected) < 0.001)
    }

    @Test("pourTiltAngle is slightly past horizontal (>90°)")
    func pourTiltPastHorizontal() {
        let ninetyDegrees = CGFloat.pi / 2.0
        #expect(PourAnimator.pourTiltAngle > ninetyDegrees)
    }
}

// MARK: - StreamGeometry Tests

@Suite("StreamGeometry")
struct StreamGeometryTests {

    @Test("thickness ramps from 0 at progress 0")
    func thicknessAtZero() {
        #expect(StreamGeometry.thickness(for: 0) == 0)
    }

    @Test("thickness is full (1.0) during mid-pour")
    func thicknessAtMiddle() {
        #expect(StreamGeometry.thickness(for: 0.5) == 1.0)
    }

    @Test("thickness tapers to 0 at progress 1.0")
    func thicknessAtEnd() {
        #expect(StreamGeometry.thickness(for: 1.0) == 0)
    }

    @Test("thickness ramp-up completes by 0.08")
    func thicknessRampUpComplete() {
        #expect(StreamGeometry.thickness(for: 0.08) == 1.0)
    }

    @Test("thickness taper starts at 0.88")
    func thicknessTaperStart() {
        #expect(StreamGeometry.thickness(for: 0.88) == 1.0)
    }

    @Test("thickness is between 0 and 1 during ramp-up",
          arguments: [0.01, 0.02, 0.04, 0.06])
    func thicknessDuringRampUp(progress: CGFloat) {
        let t = StreamGeometry.thickness(for: progress)
        #expect(t > 0 && t < 1)
    }

    @Test("thickness is between 0 and 1 during taper",
          arguments: [0.90, 0.92, 0.95, 0.98])
    func thicknessDuringTaper(progress: CGFloat) {
        let t = StreamGeometry.thickness(for: progress)
        #expect(t > 0 && t < 1)
    }

    @Test("streamWidth constant is positive")
    func streamWidthPositive() {
        #expect(StreamGeometry.streamWidth > 0)
    }
}

// MARK: - ColorPalette Tests

@Suite("ColorPalette")
struct ColorPaletteTests {

    @Test("Palette has exactly 12 colors")
    func paletteSize() {
        #expect(ColorPalette.colors.count == 12)
    }

    @Test("color(for:) returns valid color for all valid groupIds",
          arguments: 0..<12)
    func colorForValidGroupId(groupId: Int) {
        let color = ColorPalette.color(for: groupId)
        // Just verify it doesn't return gray (which is the fallback)
        #expect(color != .gray)
    }

    @Test("color(for:) returns gray for negative groupId")
    func colorForNegativeGroupId() {
        #expect(ColorPalette.color(for: -1) == .gray)
    }

    @Test("color(for:) returns gray for groupId beyond palette")
    func colorForExcessiveGroupId() {
        #expect(ColorPalette.color(for: 12) == .gray)
        #expect(ColorPalette.color(for: 100) == .gray)
    }
}

// MARK: - GameSound Tests

@Suite("GameSound")
struct GameSoundTests {

    @Test("All sound cases have non-empty raw values",
          arguments: GameSound.allCases)
    func soundRawValues(sound: GameSound) {
        #expect(!sound.rawValue.isEmpty)
    }

    @Test("File extensions are valid audio formats",
          arguments: GameSound.allCases)
    func soundFileExtensions(sound: GameSound) {
        let validExtensions = ["mp3", "wav", "m4a", "aac"]
        #expect(validExtensions.contains(sound.fileExtension),
                "\(sound) has unexpected extension: \(sound.fileExtension)")
    }

    @Test("pop and push use mp3, water and win use wav")
    func specificExtensions() {
        #expect(GameSound.pop.fileExtension == "mp3")
        #expect(GameSound.push.fileExtension == "mp3")
        #expect(GameSound.water.fileExtension == "wav")
        #expect(GameSound.win.fileExtension == "wav")
    }

    @Test("All game sounds are iterable")
    func allCasesCount() {
        #expect(GameSound.allCases.count == 4)
    }
}
