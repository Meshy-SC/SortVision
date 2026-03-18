// ImmersiveGameView.swift
#if os(visionOS)
// Main game view rendered in a mixed immersive space.
// Handles both placement and gameplay phases using RealityView attachments.

import SwiftUI
import RealityKit
import RealityKitContent
import ARKit

// MARK: - Attachment IDs

private enum AttachmentID {
    static let placeButton = "PlaceButton"
    static let dPad = "DPad"
    static let toolbar = "Toolbar"
    static let gauge = "Gauge"
    static let loading = "Loading"
    static let completion = "Completion"
}

/// Main visionOS game view rendered in a mixed immersive space.
///
/// Manages the full game experience including:
/// - **RealityKit content**: Entity templates, level hierarchy, and puzzle grid state
/// - **ARKit tracking**: Spatial tracking for floor placement, world tracking for viewpoint detection
/// - **SwiftUI attachments**: D-Pad, toolbar, gauge, and audio settings positioned relative to the board
/// - **Keyboard input**: Arrow keys mapped to movement directions with viewpoint-aware transformation
struct ImmersiveGameView: View {

    // ───────── Scene templates ─────────
    @State var wallTemplate:  Entity?
    @State var playerTemplate: Entity?
    @State var slotTemplate:   Entity?
    @State var boxTemplate:    Entity?

    // ───────── App & env ─────────
    @Environment(AppModel.self) var appModel
    @Environment(\.scenePhase)     private var scenePhase
    @Environment(\.openWindow)     private var openWindow
    @Environment(\.dismissWindow)  private var dismissWindow
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    // ───────── Drop animation ─────────
    @State var dropAnimationTask: Task<Void, Never>?

    // ───────── Per-level state ─────────
    @State var playerEntity:  Entity?
    @State var levelRoot:     Entity?
    @State var puzzleGrid:    [[CellContent]] = []
    @State var slotPositions: Set<GridPosition>     = []
    @State var slotEntities:  [GridPosition: Entity] = [:]
    @State var totalBoxCount     = 0
    @State var arrivedBoxCount   = 0
    @State var isLevelCompleted = false
    @State var moveHistory:   [MoveRecord] = []
    @State var isAnimating    = false
    @State var isLevelReady   = false
    @State var playerGridPosition: GridPosition?

    // ───────── Completion overlay state ─────────
    @State var showCompletionOverlay = false
    @State var completionStars = 0
    @State var completionScoreGained = 0
    @State var completionTotalScore = 0
    @State var completionPushCount = 0
    @State var completionParPushes: Int? = nil

    // ───────── Attachment position dirty tracking ─────────
    /// Non-reactive cache so the RealityView `update:` closure can read/write
    /// without triggering "Modifying state during view update".
    @MainActor private final class AttachmentCache {
        var viewpoint: SquareAzimuth?
        var levelWidth: Int = -1
        var levelDepth: Int = -1
        var boardScale: Double = -1
    }
    @State private var attachmentCache = AttachmentCache()

    // ───────── Immersive space state ─────────
    /// Root entity positioned at the user's chosen placement location.
    @State var gameAnchorEntity = Entity()

    /// Placeholder entity shown during the placing phase.
    @State var placeholderEntity: Entity?

    // ───────── ARKit ─────────
    @State private var spatialTrackingSession = SpatialTrackingSession()
    @State private var arKitSession = ARKitSession()

    // Convenient accessor for the current raw level lines.
    var currentLevelLines: [String] {
        guard let worldName = (appModel.activeWorld?.worldName ?? appModel.selectedWorld?.worldName) else { return [] }
        guard let idx = appModel.selectedLevelIndex,
              let levels = appModel.levelLoader.cache[worldName],
              levels.indices.contains(idx) else { return [] }
        return levels[idx]
    }

    // MARK: - Body

    var body: some View {
        RealityView { content, attachments in
            // Add anchor entity for game content
            gameAnchorEntity.name = "GameAnchor"
            content.add(gameAnchorEntity)

            // Configure spatial tracking for floor detection
            let configuration = SpatialTrackingSession.Configuration(
                tracking: [.plane],
                sceneUnderstanding: [.physics]
            )
            if let _ = await spatialTrackingSession.run(configuration) {
                AppLogger.ui.warning("Some spatial tracking capabilities are unavailable")
            }

            // Start world tracking for head position
            let worldTracking = WorldTrackingProvider()
            appModel.worldTrackingProvider = worldTracking
            do {
                try await arKitSession.run([worldTracking])
            } catch {
                AppLogger.ui.error("Failed to start world tracking: \(error.localizedDescription)")
            }

            // Create placeholder for placement phase (skip animation when Reduce Motion is on)
            let placeholder = PlaceholderEntityFactory.createPlaceholderMarker(reduceMotion: reduceMotion)
            placeholderEntity = placeholder
            content.add(placeholder)

            // Attach the place button to the placeholder immediately
            if let buttonAttachment = attachments.entity(for: AttachmentID.placeButton) {
                buttonAttachment.position = [0, 0.25, 0]
                buttonAttachment.components.set(BillboardComponent())
                placeholder.addChild(buttonAttachment)
            }

        } update: { content, attachments in
            let isPlacing = appModel.gamePhase == .placing
            let isPlaying = appModel.gamePhase == .playing

            // Apply board scale
            gameAnchorEntity.scale = SIMD3<Float>(repeating: Float(appModel.boardScale))

            // ── Placeholder ──
            placeholderEntity?.isEnabled = isPlacing

            // ── Place button: parent to placeholder, visible during placing ──
            if let placeButton = attachments.entity(for: AttachmentID.placeButton) {
                if placeButton.parent !== placeholderEntity {
                    placeButton.position = [0, 0.25, 0]
                    placeButton.components.set(BillboardComponent())
                    placeholderEntity?.addChild(placeButton)
                }
                placeButton.isEnabled = isPlacing
            }

            // ── D-Pad: parent to game anchor, stays fixed (no BillboardComponent) ──
            if let dPad = attachments.entity(for: AttachmentID.dPad) {
                if dPad.parent !== gameAnchorEntity {
                    gameAnchorEntity.addChild(dPad)
                }
                dPad.isEnabled = isPlaying && levelRoot != nil && !appModel.isPlayingSolution && !isLevelCompleted && dropAnimationTask == nil
            }

            // ── Toolbar: parent to game anchor, stays fixed ──
            if let toolbar = attachments.entity(for: AttachmentID.toolbar) {
                if toolbar.parent !== gameAnchorEntity {
                    gameAnchorEntity.addChild(toolbar)
                }
                toolbar.isEnabled = isPlaying
            }

            // ── Gauge: parent to game anchor, stays fixed ──
            if let gauge = attachments.entity(for: AttachmentID.gauge) {
                if gauge.parent !== gameAnchorEntity {
                    gameAnchorEntity.addChild(gauge)
                }
                gauge.isEnabled = isPlaying && levelRoot != nil
            }

            // ── Loading indicator: visible while level is loading ──
            if let loading = attachments.entity(for: AttachmentID.loading) {
                if loading.parent !== gameAnchorEntity {
                    gameAnchorEntity.addChild(loading)
                }
                loading.position = SIMD3<Float>(0, 0.15, 0)
                loading.components.set(BillboardComponent())
                loading.isEnabled = isPlaying && !isLevelReady && dropAnimationTask == nil
            }

            // ── Completion overlay: visible when level is completed ──
            if let completion = attachments.entity(for: AttachmentID.completion) {
                if completion.parent !== gameAnchorEntity {
                    gameAnchorEntity.addChild(completion)
                }
                completion.position = SIMD3<Float>(0, 0.30, 0)
                completion.components.set(BillboardComponent())
                completion.isEnabled = showCompletionOverlay
            }

            // ── Recompute attachment positions only when viewpoint or level size changes ──
            // Uses a reference-type cache to avoid @State writes inside the update closure.
            let currentViewpoint = appModel.currentViewpoint
            let currentWidth = appModel.levelWidth
            let currentDepth = appModel.levelDepth
            let currentBoardScale = appModel.boardScale
            let cache = attachmentCache
            if cache.viewpoint != currentViewpoint || cache.levelWidth != currentWidth || cache.levelDepth != currentDepth || cache.boardScale != currentBoardScale {
                cache.viewpoint = currentViewpoint
                cache.levelWidth = currentWidth
                cache.levelDepth = currentDepth
                cache.boardScale = currentBoardScale
                updateAttachmentPositions(
                    dPad: attachments.entity(for: AttachmentID.dPad),
                    toolbar: attachments.entity(for: AttachmentID.toolbar),
                    gauge: attachments.entity(for: AttachmentID.gauge)
                )
            }

        } attachments: {
            // Place button — visibility controlled by update: closure
            Attachment(id: AttachmentID.placeButton) {
                Button(action: { confirmPlacement() }) {
                    Text("Tap to place your level")
                        .font(.extraLargeTitle.bold())
                        .padding(.horizontal, 80)
                        .padding(.vertical, 40)
                }
                .buttonStyle(.plain)
                .buttonBorderShape(.roundedRectangle)
                .glassBackgroundEffect()
                .hoverEffect(.highlight)
                .accessibilityLabel("Place your level on the floor")
                .accessibilityHint("Tap to confirm the placement location")
            }

            // D-Pad — no background, just the directional buttons
            Attachment(id: AttachmentID.dPad) {
                DirectionalPadOrnament(
                    currentViewpoint: appModel.currentViewpoint,
                    onMove: { columnDelta, rowDelta in
                        movePlayer(columnDelta: columnDelta, rowDelta: rowDelta)
                    }
                )
            }

            // Toolbar — compact layout without spacers
            Attachment(id: AttachmentID.toolbar) {
                HStack(spacing: 12) {
                    GameToolbarOrnament(
                        undoAction:          undoMove,
                        previousLevelAction: previousLevel,
                        nextLevelAction:     nextLevel,
                        solutionAction:      { toggleSolution() },
                        isLevelReady:        isLevelReady,
                        isUndoDisabled:      moveHistory.isEmpty || isLevelCompleted,
                        isStandalone:        false
                    )
                    .environment(appModel)
                }
                .padding()
                .glassBackgroundEffect()
            }

            // Push count gauge
            Attachment(id: AttachmentID.gauge) {
                PushCountGaugeOrnament()
                    .environment(appModel)
            }

            // Loading indicator — shown while level geometry is being built
            Attachment(id: AttachmentID.loading) {
                VStack(spacing: 16) {
                    ProgressView()
                        .controlSize(.large)
                        .tint(.white)
                    Text("Loading level…")
                        .font(.title2.bold())
                        .foregroundStyle(.white.secondary)
                }
                .padding(40)
                .glassBackgroundEffect()
            }

            // Level completion celebration overlay
            Attachment(id: AttachmentID.completion) {
                LevelCompletionView(
                    stars: completionStars,
                    scoreGained: completionScoreGained,
                    totalScore: completionTotalScore,
                    pushCount: completionPushCount,
                    parPushes: completionParPushes,
                    onDismiss: { dismissCompletionOverlay() }
                )
                .frame(width: 500, height: 500)
                .glassBackgroundEffect()
            }
        }
        // ───────── Placement loop ─────────
        .task {
            await runPlacementLoop()
        }
        // ───────── Viewpoint tracking loop ─────────
        .task {
            await runViewpointLoop()
        }
        // ───────── Level loading triggers ─────────
        .onChange(of: appModel.gamePhase) { oldPhase, newPhase in
            if newPhase == .playing {
                loadCurrentLevel()
            }
        }
        .onChange(of: appModel.selectedLevelIndex) { _, _ in loadCurrentLevel() }
        .onChange(of: appModel.activeWorld)        { _, _ in loadCurrentLevel() }
        .onChange(of: scenePhase) { oldPhase, phase in
            handleScenePhaseChange(from: oldPhase, to: phase)
        }
        // ───────── Control panel window management ─────────
        .onChange(of: appModel.isControlPanelOpen) { _, isOpen in
            if isOpen {
                openWindow(id: "ControlPanel")
            } else {
                dismissWindow(id: "ControlPanel")
            }
        }
        // ───────── Credits store window (triggered when tapping cart or bulb with 0 credits) ─────────
        .onChange(of: appModel.inAppPurchaseService.isStoreSheetPresented) { _, isPresented in
            if isPresented {
                openWindow(id: "SolutionCreditsStore")
            } else {
                dismissWindow(id: "SolutionCreditsStore")
            }
        }
        // ───────── Keyboard input ─────────
        .focusable()
        .onKeyPress(.upArrow) {
            handleKeyboardDirection(columnDelta: 0, rowDelta: -1)
            return .handled
        }
        .onKeyPress(.downArrow) {
            handleKeyboardDirection(columnDelta: 0, rowDelta: 1)
            return .handled
        }
        .onKeyPress(.leftArrow) {
            handleKeyboardDirection(columnDelta: -1, rowDelta: 0)
            return .handled
        }
        .onKeyPress(.rightArrow) {
            handleKeyboardDirection(columnDelta: 1, rowDelta: 0)
            return .handled
        }
        // ───────── Scene bootstrap ─────────
        .task {
            await bootstrapScene()
        }
    }

    // MARK: - Attachment Positioning

    /// Recomputes attachment positions relative to the board.
    ///
    /// The level root is centered at the game anchor origin
    /// (LevelBuilder offsets by -halfWidth, -halfDepth), so board center = (0, 0, 0).
    ///
    /// Layout contract (always from the user's perspective):
    /// - **D-Pad** → center of the board (elevated above it)
    /// - **Toolbar** → in front of the board (toward the user)
    /// - **Gauge** → behind the board (away from the user), elevated
    /// - **Audio settings** → above the toolbar (in front, slightly higher)
    ///
    /// For non-square levels the "front" edge distance depends on which
    /// face the user is looking at:
    /// - `.front` / `.back` → the board's Z half-extent (halfDepth)
    /// - `.left`  / `.right` → the board's X half-extent (halfWidth)
    ///
    /// This keeps the gap between the attachment and the nearest wall
    /// identical no matter which viewpoint is active or which level is loaded.
    private func updateAttachmentPositions(dPad: Entity?, toolbar: Entity?, gauge: Entity?) {
        let viewpoint = appModel.currentViewpoint
        let angle = viewpointYRotation(for: viewpoint)
        let orientation = simd_quatf(angle: angle, axis: SIMD3<Float>(0, 1, 0))

        // Board half-extents in world units (matching LevelBuilder centering).
        let cellSize = GameLayout.cellSize
        let halfWidth = Float(max(appModel.levelWidth  - 1, 0)) * cellSize / 2
        let halfDepth = Float(max(appModel.levelDepth  - 1, 0)) * cellSize / 2

        // Pick the half-extent that corresponds to the face the user is
        // looking at so the toolbar/gauge distance is always measured from
        // the nearest wall edge.
        let halfFront: Float = {
            switch viewpoint {
            case .front, .back: return halfDepth
            case .left, .right: return halfWidth
            @unknown default:   return halfDepth
            }
        }()

        // Margin between the board edge and the attachment
        let margin: Float = 0.05

        // D-Pad: dead center of the board, elevated above it
        dPad?.position = SIMD3<Float>(0, 0.35, 0)
        dPad?.orientation = orientation

        // Toolbar: in front of the board (positive-Z side from user's view)
        let frontZ = halfFront + margin
        toolbar?.position = rotateAroundY(SIMD3<Float>(0, 0, frontZ), angle: angle)
        toolbar?.orientation = orientation

        // Gauge: behind the board (negative-Z side from user's view), elevated
        let backZ = -(halfFront + margin)
        gauge?.position = rotateAroundY(SIMD3<Float>(0, 0.25, backZ), angle: angle)
        gauge?.orientation = orientation
    }

    // MARK: - Viewpoint Rotation Helpers

    /// Returns the Y-axis rotation angle for the given viewpoint.
    /// Aligns attachment positions and orientations with the board face
    /// closest to the user — matching Apple's `SquareAzimuth` convention.
    private func viewpointYRotation(for viewpoint: SquareAzimuth) -> Float {
        switch viewpoint {
        case .front: return 0
        case .right: return .pi / 2
        case .back:  return .pi
        case .left:  return -.pi / 2
        @unknown default: return 0
        }
    }

    /// Rotates a position around the Y axis by the given angle.
    private func rotateAroundY(_ position: SIMD3<Float>, angle: Float) -> SIMD3<Float> {
        SIMD3<Float>(
            position.x * cos(angle) + position.z * sin(angle),
            position.y,
            -position.x * sin(angle) + position.z * cos(angle)
        )
    }
}
#endif
