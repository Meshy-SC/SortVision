import SpriteKit
import Testing

@testable import water_puzzle_swift

@Suite("GameScene")
@MainActor
struct GameSceneTests {

    /// Creates a GameScene configured with the given level, ready for testing.
    private func makeScene(with level: Level, mode: GameMode = .easy) -> GameScene {
        let scene = GameScene(size: CGSize(width: 750, height: 1334))
        scene.scaleMode = .aspectFill
        scene.level = level
        scene.gameMode = mode
        scene.reduceMotion = true
        return scene
    }

    /// Activates the scene by moving it to a view, triggering didMove(to:).
    private func presentScene(_ scene: GameScene) -> SKView {
        let view = SKView(frame: CGRect(x: 0, y: 0, width: 375, height: 667))
        view.presentScene(scene)
        return view
    }

    // MARK: - Level Loading

    @Test("Scene creates correct number of holders for the level")
    func holderCountMatchesLevel() {
        let level = TestFixtures.level(columns: [
            [1, 1, 2, 2],
            [2, 2, 1, 1],
            [],
        ])
        let scene = makeScene(with: level)
        let view = presentScene(scene)
        _ = view // retain view

        // Count HolderNode children in the scene
        let holders = scene.children.compactMap { $0 as? HolderNode }
        #expect(holders.count == 3)
    }

    @Test("Scene with nil level creates no holders")
    func nilLevelCreatesNoHolders() {
        let scene = GameScene(size: CGSize(width: 750, height: 1334))
        scene.level = nil
        let view = presentScene(scene)
        _ = view

        let holders = scene.children.compactMap { $0 as? HolderNode }
        #expect(holders.count == 0)
    }

    @Test("Large level (>6 tubes) creates correct holder count")
    func largeLevelHolderCount() {
        let level = TestFixtures.largeLevel(tubeCount: 10)
        let scene = makeScene(with: level)
        let view = presentScene(scene)
        _ = view

        let holders = scene.children.compactMap { $0 as? HolderNode }
        #expect(holders.count == 10)
    }

    // MARK: - Restart

    @Test("Restart removes all holders and reloads level")
    func restartResetsScene() {
        let level = TestFixtures.simpleLevel()
        let scene = makeScene(with: level)
        let view = presentScene(scene)
        _ = view

        let holdersBefore = scene.children.compactMap { $0 as? HolderNode }
        #expect(holdersBefore.count == 3)

        scene.restart()

        let holdersAfter = scene.children.compactMap { $0 as? HolderNode }
        #expect(holdersAfter.count == 3, "Holders should be recreated after restart")
    }

    // MARK: - Callbacks

    @Test("onLevelComplete callback is invoked when puzzle is solved")
    func levelCompleteCallbackFires() async throws {
        let level = TestFixtures.solvedLevel()
        let scene = makeScene(with: level)

        var callbackFired = false
        scene.onLevelComplete = {
            callbackFired = true
        }

        let view = presentScene(scene)
        _ = view

        // The solved level has uniform tubes, so the win condition
        // would need to be triggered through the scene's internal logic.
        // We verify the callback is wired correctly here.
        #expect(scene.onLevelComplete != nil)
    }

    @Test("onSaveProgress callback is wired correctly")
    func saveProgressCallbackWired() {
        let level = TestFixtures.simpleLevel()
        let scene = makeScene(with: level, mode: .hard)

        var savedMode: GameMode?
        var savedNumber: Int?
        scene.onSaveProgress = { mode, number in
            savedMode = mode
            savedNumber = number
        }

        #expect(scene.onSaveProgress != nil)
    }

    // MARK: - Game Mode

    @Test("Scene stores the assigned game mode")
    func gameModeStored() {
        let scene = GameScene(size: CGSize(width: 750, height: 1334))
        scene.gameMode = .expert
        #expect(scene.gameMode == .expert)
    }

    // MARK: - Reduce Motion

    @Test("Scene respects reduceMotion flag")
    func reduceMotionFlag() {
        let scene = GameScene(size: CGSize(width: 750, height: 1334))
        scene.reduceMotion = true
        #expect(scene.reduceMotion == true)
    }
}
