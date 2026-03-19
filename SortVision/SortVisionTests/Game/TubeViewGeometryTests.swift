import CoreGraphics
import Testing

@testable import SortVision

@Suite("Tube Geometry")
struct TubeViewGeometryTests {

    @Test("Lip point matches the visible top rim center")
    func lipPointMatchesVisibleRim() {
        let frame = CGRect(
            x: 24,
            y: 40,
            width: TubeView.tubeWidth,
            height: TubeView.tubeHeight
        )

        let lipPoint = TubeView.lipPoint(in: frame, scale: 1.0)

        #expect(lipPoint.x == frame.midX)
        #expect(lipPoint.y == frame.minY + TubeView.capHeight / 2)
    }

    @Test("Pour lip offset tracks the opening edge on each side")
    func pourLipOffsetTracksOpeningEdge() {
        let rightLip = TubeView.pourLipOffset(toward: 1.0, scale: 1.0)
        let leftLip = TubeView.pourLipOffset(toward: -1.0, scale: 1.0)
        let lipCenter = TubeView.lipCenterOffset(scale: 1.0)

        #expect(rightLip.x == TubeView.rimHalfWidth)
        #expect(leftLip.x == -TubeView.rimHalfWidth)
        #expect(rightLip.y == lipCenter.y)
        #expect(leftLip.y == lipCenter.y)
    }
}
