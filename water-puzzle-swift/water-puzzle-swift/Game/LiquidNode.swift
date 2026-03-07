import SpriteKit

/// A single liquid segment inside a tube. Mirrors Unity's Liquid.cs:
/// - groupId: color index into ColorPalette.colors (0–10)
/// - value: number of liquid units (controls visual height via unitSize)
/// - isBottomLiquid: when true and value > 0.9, shows a rounded bottom cap
final class LiquidNode: SKNode {
    /// Visual height per unit of liquid value. Matches Unity's _unitSize.
    static let unitSize: CGFloat = 45.0

    /// Height of the rounded bottom cap (Unity's _bottomRendererSize).
    static let bottomCapHeight: CGFloat = 10.0

    // MARK: - Child Nodes

    private let mainSprite: SKSpriteNode
    private let bottomCap: SKShapeNode

    // MARK: - Properties

    private(set) var groupId: Int

    var isBottomLiquid: Bool = false {
        didSet { updateVisual() }
    }

    private var _value: CGFloat = 0
    var value: CGFloat {
        get { _value }
        set {
            _value = max(0, newValue)
            updateVisual()
        }
    }

    var liquidColor: SKColor {
        ColorPalette.color(for: groupId)
    }

    /// Visual height in points = value * unitSize.
    var size: CGFloat {
        _value * Self.unitSize
    }

    // MARK: - Init

    init(groupId: Int, value: CGFloat = 0) {
        self.groupId = groupId

        let color = ColorPalette.color(for: groupId)
        let width = HolderNode.innerWidth

        // Main colored rectangle — anchored at bottom, grows upward
        mainSprite = SKSpriteNode(color: color, size: CGSize(width: width, height: 0))
        mainSprite.anchorPoint = CGPoint(x: 0.5, y: 0)

        // Rounded bottom cap for the bottommost liquid
        let capPath = CGMutablePath()
        capPath.addRoundedRect(
            in: CGRect(x: -width / 2, y: 0, width: width, height: Self.bottomCapHeight),
            cornerWidth: width / 2,
            cornerHeight: Self.bottomCapHeight
        )
        bottomCap = SKShapeNode(path: capPath)
        bottomCap.fillColor = color
        bottomCap.strokeColor = .clear
        bottomCap.isHidden = true

        super.init()

        addChild(bottomCap)
        addChild(mainSprite)

        self._value = value
        updateVisual()
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Visual Update

    /// Mirrors Unity Liquid.Value setter:
    /// If isBottomLiquid and value > 0.9, show bottom cap and offset main sprite.
    /// Otherwise, hide bottom cap and render full height from local origin.
    private func updateVisual() {
        let height = _value * Self.unitSize
        let width = HolderNode.innerWidth

        if isBottomLiquid && _value > 0.9 {
            bottomCap.isHidden = false
            mainSprite.position = CGPoint(x: 0, y: Self.bottomCapHeight)
            mainSprite.size = CGSize(
                width: width,
                height: max(0, height - Self.bottomCapHeight)
            )
        } else {
            bottomCap.isHidden = true
            mainSprite.position = .zero
            mainSprite.size = CGSize(width: width, height: height)
        }
    }
}
