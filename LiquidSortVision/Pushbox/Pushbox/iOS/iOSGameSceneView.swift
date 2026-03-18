// iOSGameSceneView.swift
// iOS 3D game scene using RealityKit — renders the puzzle in a standard (non-AR) RealityView
// with swipe gesture controls and an overlaid toolbar.

#if os(iOS) || os(macOS) || os(tvOS)
import SwiftUI
import RealityKit
import RealityKitContent
import GameController

// MARK: - Skybox Image

/// Cached skybox panorama `CGImage` — decoded once, reused for every `EnvironmentResource` creation.
private let skyImage: CGImage = {
    let name = "autumn_field_puresky_1k"
    #if os(macOS)
    if let image = NSImage(named: name),
       let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) {
        return cgImage
    }
    #else
    if let image = UIImage(named: name),
       let cgImage = image.cgImage {
        return cgImage
    }
    #endif
    fatalError("Skybox image '\(name)' not found.")
}()

/// The main game scene for iOS. Renders the same 3D RealityKit content as visionOS
/// but in a standard, non-AR RealityView with a fixed isometric camera angle.
/// Player movement is controlled via swipe gestures on the scene.
struct iOSGameSceneView: View {
    
    // ───────── Scene templates ─────────
    @State var wallTemplate:  Entity?
    @State var playerTemplate: Entity?
    @State var slotTemplate:  Entity?
    @State var boxTemplate:   Entity?
    
    // ───────── App & env ─────────
    @Environment(AppModel.self) var appModel
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    
    // ───────── Callbacks ─────────
    let onDismiss: () -> Void
    
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

    // ───────── iOS-specific state ─────────
    @State private var cameraAnchor: Entity?
    @State private var sceneRoot: Entity?

    /// Whether the level selection sheet is presented.
    @State private var isLevelSheetPresented = false

    /// Game controller input manager for MFi, Xbox, and PlayStation controllers.
    @State private var gameControllerManager = GameControllerManager()

    /// Controller connection toast message currently displayed.
    @State private var controllerToastMessage: String?
    /// Work item for auto-dismissing the controller toast.
    @State private var controllerToastDismissTask: DispatchWorkItem?

    /// VoiceOver focus state for directing focus after level completion.
    @AccessibilityFocusState private var isNextLevelFocused: Bool

    /// Accumulated rotation from drag gestures (radians around Y axis).
    @State private var cameraRotation: Float = 0

    /// Base rotation before current gesture (for additive two-finger rotation).
    @State private var baseCameraRotation: Float = 0
    
    /// Trigger counter for movement haptic feedback via `.sensoryFeedback()`.
    @State private var movementHapticTrigger = 0
    
    /// Whether a magnify gesture is currently in progress.
    /// Uses `@GestureState` so it auto-resets on gesture end **and** cancel
    /// (Apple docs: `onEnded` only fires on success; `@GestureState` always resets).
    @GestureState private var isMagnifying = false

    /// Zoom level committed between gestures (the baseline for the next pinch).
    @State private var committedZoom: Float = 1.0

    /// Live zoom updated every frame during a pinch gesture.
    /// **Intentionally unclamped** so the value always changes and SwiftUI never
    /// suppresses gesture callbacks due to repeated identical state writes.
    @State private var liveZoom: Float = 1.0

    /// Effective zoom used by the camera — clamped to the valid range.
    private var effectiveZoom: Float {
        min(max(liveZoom, Camera.minZoom), Camera.maxZoom)
    }

    /// Tracked view size for aspect-ratio-aware camera framing.
    @State private var viewSize: CGSize = .zero
    
    // ───────── iOS camera constants ─────────
    private enum Camera {
        /// Minimum horizontal orbit distance from camera to level center.
        static let minDistance:     Float = 0.35
        /// Extra margin multiplier applied after computing the required distance.
        static let distanceScale:  Float = 1.15
        /// Multiplier: elevation = horizontal distance × elevationScale.
        /// Set to 1.0 for a clean ~45° isometric angle (Apple HIG recommended).
        static let elevationScale: Float = 1.0
        static let minZoom:        Float = 0.5
        static let maxZoom:        Float = 2.0
        /// Extra cells of padding around the board for comfortable framing.
        static let paddingCells:   Float = 3.0
        /// Minimum effective grid extent (cells) so tiny levels don't over-zoom.
        static let minCells:       Float = 6.0
        /// Z-axis foreshortening at the ~45° isometric view angle.
        static let foreshortening: Float = 0.75
        /// Vertical field of view in degrees (must match PerspectiveCameraComponent).
        static let fovDegrees:     Float = 50.0
    }
    
    // ───────── Computed properties ─────────
    
    var currentLevelLines: [String] {
        guard let worldName = (appModel.activeWorld?.worldName ?? appModel.selectedWorld?.worldName) else { return [] }
        guard let idx = appModel.selectedLevelIndex,
              let levels = appModel.levelLoader.cache[worldName],
              levels.indices.contains(idx) else { return [] }
        return levels[idx]
    }
    
    // MARK: - Body
    
    var body: some View {
        ZStack {
            gameSceneContent
            controlsOverlay

            // Level completion celebration overlay
            if showCompletionOverlay {
                LevelCompletionView(
                    stars: completionStars,
                    scoreGained: completionScoreGained,
                    totalScore: completionTotalScore,
                    pushCount: completionPushCount,
                    parPushes: completionParPushes,
                    onDismiss: { dismissCompletionOverlay() }
                )
                .transition(.opacity)
                .zIndex(100)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: showCompletionOverlay)
            .modifier(GameAccessibilityActions(
                transformDirection: transformDirectionForCamera,
                movePlayer: { c, r in movePlayer(columnDelta: c, rowDelta: r) },
                undoMove: undoMove
            ))
            .modifier(GameSheets(
                isLevelSheetPresented: $isLevelSheetPresented,
                appModel: appModel,
                toggleSolution: { toggleSolution() }
            ))
            .modifier(GameKeyboardHandlers(
                isAnimating: isAnimating,
                isLevelCompleted: isLevelCompleted,
                transformDirection: transformDirectionForCamera,
                movePlayer: { c, r in movePlayer(columnDelta: c, rowDelta: r) }
            ))
            .modifier(GameChangeHandlers(
                isLevelSheetPresented: $isLevelSheetPresented,
                appModel: appModel,
                scenePhase: scenePhase,
                levelRoot: levelRoot,
                isLevelCompleted: isLevelCompleted,
                loadCurrentLevel: loadCurrentLevel,
                cancelDropAnimation: {
                    dropAnimationTask?.cancel()
                    dropAnimationTask = nil
                }
            ))
            #if !os(tvOS)
            .sensoryFeedback(.impact(weight: .light), trigger: movementHapticTrigger)
            .sensoryFeedback(.success, trigger: isLevelCompleted) { _, newValue in
                newValue
            }
            #endif
            // Game controller: directional movement
            .onChange(of: gameControllerManager.lastInput) { _, input in
                guard let input, !isAnimating, !isLevelCompleted, !appModel.isPlayingSolution else { return }
                let dir = transformDirectionForCamera(columnDelta: input.column, rowDelta: input.row)
                movePlayer(columnDelta: dir.column, rowDelta: dir.row)
            }
            // Game controller: non-directional button actions
            .onChange(of: gameControllerManager.lastAction) { _, event in
                guard let event else { return }
                switch event.action {
                case .undo:
                    guard !isAnimating, !isLevelCompleted, !appModel.isPlayingSolution else { return }
                    undoMove()
                case .toggleSolution:
                    toggleSolution()
                case .previousLevel:
                    previousLevel()
                case .nextLevel:
                    nextLevel()
                case .menu:
                    isLevelSheetPresented.toggle()
                }
            }
            // Game controller: connection / disconnection HUD toast
            .onChange(of: gameControllerManager.lastConnectionEvent) { _, event in
                guard let event else { return }
                showControllerToast(name: event.controllerName, connected: event.isConnected)
            }
            .overlay(alignment: .top) { controllerConnectionToast }
            .task { gameControllerManager.start() }
            .onDisappear { gameControllerManager.stop() }
            #if os(macOS)
            .focusedSceneValue(\.gameActions, GameActions(
                undoMove: undoMove,
                previousLevel: previousLevel,
                nextLevel: nextLevel
            ))
            #endif
    }

    // MARK: - Game Scene Content

    /// The core RealityView — scene setup extracted into a separate computed property
    /// so the modifier chain below doesn't bloat the type-checker context.
    private var realityViewContent: some View {
        RealityView { content in
            let root = Entity()
            root.name = "iOSSceneRoot"
            content.add(root)
            sceneRoot = root

            // Apply skybox panorama + IBL + directional light.
            let env: EnvironmentResource? = makeSceneEnvironment(root: root)
            if let env { content.environment = .skybox(env) }

            let camAnchor = Entity()
            camAnchor.name = "CameraAnchor"
            camAnchor.components.set(
                PerspectiveCameraComponent(fieldOfViewInDegrees: 50)
            )
            root.addChild(camAnchor)
            cameraAnchor = camAnchor

            let scene: Entity
            do {
                scene = try await Entity(named: "Scene", in: realityKitContentBundle)
            } catch {
                AppLogger.ui.error("Failed to load Scene entity: \(error.localizedDescription)")
                await MainActor.run { onDismiss() }
                return
            }

            scene.findEntity(named: "ParticleEmitterFireworks")?.isEnabled = false
            await MainActor.run { appModel.gameScene = scene }
            root.addChild(scene)

            guard let wallEntity = scene.findEntity(named: "Wall"),
                  let playerTemplateEntity = scene.findEntity(named: "Player"),
                  let slotEntity = scene.findEntity(named: "Slot"),
                  let boxEntity = scene.findEntity(named: "Box") else {
                AppLogger.ui.error("Missing template entities in Scene (Wall/Player/Slot/Box)")
                await MainActor.run { onDismiss() }
                return
            }

            wallTemplate = wallEntity;  wallEntity.removeFromParent()
            playerTemplate = playerTemplateEntity; playerTemplateEntity.removeFromParent()
            slotTemplate  = slotEntity; slotEntity.removeFromParent()
            boxTemplate   = boxEntity; boxEntity.removeFromParent()

            if appModel.selectedLevelIndex != nil {
                let newRoot = buildLevel(from: currentLevelLines,
                                         wall: wallEntity, player: playerTemplateEntity,
                                         slot: slotEntity, box: boxEntity)
                newRoot.isEnabled = false
                scene.addChild(newRoot)
                levelRoot = newRoot
                appModel.animationService.playIdleAnimation()

                // Animate entities dropping in one by one;
                // audio is started by performDropAnimation after the first entity lands.
                performDropAnimation(on: newRoot, reduceMotion: reduceMotion)
            }

            updateCamera()

        } placeholder: {
            ProgressView()
                .controlSize(.large)
                .tint(.white)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    /// The `realityViewContent` wrapped with camera / interaction / overlay modifiers.
    private var gameSceneContent: some View {
        realityViewContent
        .onChange(of: cameraRotation) { updateCamera() }
        .onChange(of: liveZoom) { updateCamera() }
        .onChange(of: viewSize) { updateCamera() }
        .onChange(of: appModel.levelWidth) { committedZoom = 1.0; liveZoom = 1.0; updateCamera() }
        .onChange(of: appModel.levelDepth) { committedZoom = 1.0; liveZoom = 1.0; updateCamera() }
        // Commit zoom when the magnify gesture ends OR is cancelled.
        // @GestureState guarantees this fires in both cases.
        .onChange(of: isMagnifying) { _, active in
            if !active {
                committedZoom = effectiveZoom
                liveZoom = committedZoom
            }
        }
        .opacity(appModel.isPlayingSolution ? 0.7 : 1)
        .animation(reduceMotion ? nil : .default, value: appModel.isPlayingSolution)
        .accessibilityLabel("Push Box puzzle game board. Use accessibility actions or arrow keys to move.")
        #if !os(tvOS)
        .gesture(swipeGesture)
        .gesture(zoomMagnificationGesture.simultaneously(with: cameraRotationGesture))
        #endif
        .background(Color.black)
        .ignoresSafeArea()
        .overlay {
            // Show loading overlay only when truly waiting for assets —
            // NOT during the drop animation (which IS the visual transition).
            if !isLevelReady && dropAnimationTask == nil {
                ZStack {
                    Color.black
                    VStack(spacing: 16) {
                        ProgressView()
                            .controlSize(.large)
                            .tint(.white)
                        Text("Loading level…")
                            .font(.headline)
                            .foregroundStyle(.white.secondary)
                    }
                }
                .ignoresSafeArea()
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.35), value: isLevelReady)
        .animation(.easeInOut(duration: 0.35), value: dropAnimationTask == nil)
        .onGeometryChange(for: CGSize.self) { proxy in
            proxy.size
        } action: { newSize in
            viewSize = newSize
        }
    }

    // MARK: - Controls Overlay

    /// Top and bottom control bars overlaid on the game scene.
    private var controlsOverlay: some View {
        VStack {
            HStack(alignment: .top, spacing: 12) {
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.body.weight(.semibold))
                        .frame(width: 44, height: 44)
                        .contentShape(Circle())
                }
                .buttonStyle(.glass)
                .buttonBorderShape(.circle)
                .accessibilityLabel("Close game")

                Button {
                    isLevelSheetPresented = true
                } label: {
                    Image(systemName: "square.grid.3x3")
                        .font(.body.weight(.semibold))
                        .frame(width: 44, height: 44)
                        .contentShape(Circle())
                }
                .buttonStyle(.glass)
                .buttonBorderShape(.circle)
                .accessibilityLabel("Change level")

                iOSGameGauges()
                    .environment(appModel)

                Spacer()
            }
            #if os(macOS)
            .padding(.top, 20)
            .padding(.leading, 16)
            #else
            .padding(.top, 12)
            #endif

            Spacer()

            iOSGameToolbar(
                undoAction: undoMove,
                previousLevelAction: previousLevel,
                nextLevelAction: nextLevel,
                solutionAction: { toggleSolution() },
                isLevelReady: isLevelReady,
                isUndoDisabled: moveHistory.isEmpty || isLevelCompleted
            )
            .environment(appModel)
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
    }
    
    // MARK: - Camera
    
    private func updateCamera() {
        guard let cam = cameraAnchor else { return }
        
        let cols = Float(puzzleGrid.first?.count ?? 0)
        let rows = Float(puzzleGrid.count)
        
        // Screen aspect ratio (width / height) — adapts to portrait & landscape.
        // Avoid using UIScreen.main (deprecated). Prefer the view's measured size.
        let aspect: Float
        if viewSize.width > 0 && viewSize.height > 0 {
            aspect = Float(viewSize.width / viewSize.height)
        } else {
            // Fallback to a safe default aspect ratio when size is not yet known.
            // 9:16 covers common portrait; this value only applies briefly during setup.
            aspect = Float(9.0 / 16.0)
        }
        
        // Padded level dimensions in world units.
        let paddedCols = max(cols + Camera.paddingCells, Camera.minCells)
        let paddedRows = max(rows + Camera.paddingCells, Camera.minCells)
        let levelWidth = paddedCols * GameLayout.cellSize
        let levelDepth = paddedRows * GameLayout.cellSize
        
        // Perspective FoV half-angles (vertical from component, horizontal from aspect).
        let vHalf = Camera.fovDegrees / 2.0 * .pi / 180.0
        let hHalf = atan(tan(vHalf) * aspect)
        
        // Required camera-to-center distance to frame each axis.
        // Width maps directly to screen horizontal;
        // depth is foreshortened by the ~45° isometric viewing angle.
        let distForWidth  = (levelWidth / 2) / tan(hHalf)
        let distForHeight = (levelDepth * Camera.foreshortening / 2) / tan(vHalf)
        let viewDistance  = max(distForWidth, distForHeight)
        
        // Convert view distance to horizontal orbit distance.
        // Actual camera distance = √(hDist² + elev²) = hDist × √(1 + elevationScale²)
        let diagFactor = sqrt(1.0 + Camera.elevationScale * Camera.elevationScale)
        let baseDistance = max(viewDistance / diagFactor * Camera.distanceScale,
                              Camera.minDistance)
        
        let zoom = effectiveZoom
        let distance  = baseDistance / zoom
        let elevation = baseDistance * Camera.elevationScale / zoom
        
        let x = distance * sin(cameraRotation)
        let z = distance * cos(cameraRotation)
        
        cam.position = SIMD3<Float>(x, elevation, z)
        cam.look(at: SIMD3<Float>(0, GameLayout.levelYOffset, 0), from: cam.position, relativeTo: nil)
    }
    
    // MARK: - Gestures
    
    #if !os(tvOS)
    /// Swipe gesture for player movement.
    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 30, coordinateSpace: .local)
            .onEnded { value in
                guard !isAnimating, !isLevelCompleted, !appModel.isPlayingSolution else { return }
                
                let dx = value.translation.width
                let dy = value.translation.height
                
                let (columnDelta, rowDelta): (Int, Int)
                if abs(dx) > abs(dy) {
                    // Horizontal swipe
                    columnDelta = dx > 0 ? 1 : -1
                    rowDelta = 0
                } else {
                    // Vertical swipe
                    columnDelta = 0
                    rowDelta = dy > 0 ? 1 : -1
                }
                
                // Transform based on camera rotation for intuitive controls
                let transformedDirection = transformDirectionForCamera(
                    columnDelta: columnDelta,
                    rowDelta: rowDelta
                )
                
                movementHapticTrigger += 1
                
                movePlayer(
                    columnDelta: transformedDirection.column,
                    rowDelta: transformedDirection.row
                )
            }
    }
    
    /// Pinch gesture for zoom.
    ///
    /// Three-layer strategy that avoids the "stuck-at-max" bug:
    ///
    /// 1. **`@GestureState isMagnifying`** — auto-resets on gesture end *and*
    ///    cancel.  Apple docs: "`onEnded` is only performed if the gesture ends
    ///    successfully"; `@GestureState` always resets.  An `.onChange` handler
    ///    commits the clamped zoom when this flips to `false`.
    ///
    /// 2. **Unclamped `liveZoom`** — written every frame during the gesture so
    ///    the value always changes.  If we clamped here, repeated writes of the
    ///    same boundary value would look like no-ops to SwiftUI, which can
    ///    suppress further gesture callbacks and freeze the recogniser.
    ///
    /// 3. **Clamped `effectiveZoom`** — a computed property the camera reads.
    ///    The camera never moves beyond min/max, but the gesture stays alive
    ///    because `liveZoom` keeps changing underneath.
    private var zoomMagnificationGesture: some Gesture {
        MagnifyGesture()
            .updating($isMagnifying) { _, state, _ in
                state = true
            }
            .onChanged { value in
                // Intentionally unclamped — see doc comment above.
                liveZoom = committedZoom * Float(value.magnification)
            }
            .onEnded { value in
                let final = committedZoom * Float(value.magnification)
                committedZoom = min(max(final, Camera.minZoom), Camera.maxZoom)
                liveZoom = committedZoom
            }
    }

    /// Two-finger rotation gesture for camera orbit.
    private var cameraRotationGesture: some Gesture {
        RotateGesture()
            .onChanged { value in
                cameraRotation = baseCameraRotation + Float(value.rotation.radians)
            }
            .onEnded { value in
                baseCameraRotation = baseCameraRotation + Float(value.rotation.radians)
            }
    }
    #endif
    
    /// Transforms swipe direction based on camera rotation for intuitive controls.
    private func transformDirectionForCamera(columnDelta: Int, rowDelta: Int) -> (column: Int, row: Int) {
        // Determine the nearest cardinal direction the camera is facing
        let normalizedRotation = cameraRotation.truncatingRemainder(dividingBy: 2 * .pi)
        let angle = normalizedRotation < 0 ? normalizedRotation + 2 * .pi : normalizedRotation
        
        let rawQuadrant = (angle + .pi / 4) / (.pi / 2)
        let quadrant = rawQuadrant.isFinite ? Int(rawQuadrant) % 4 : 0
        
        switch quadrant {
        case 0: return (columnDelta, rowDelta)           // Front
        case 1: return (rowDelta, -columnDelta)          // Right
        case 2: return (-columnDelta, -rowDelta)         // Back
        case 3: return (-rowDelta, columnDelta)           // Left
        default: return (columnDelta, rowDelta)
        }
    }
    
    // MARK: - Controller Connection Toast
    
    /// Shows a temporary toast when a game controller connects or disconnects.
    private func showControllerToast(name: String, connected: Bool) {
        controllerToastDismissTask?.cancel()
        
        let message = connected
            ? String(localized: "\(name) Connected")
            : String(localized: "\(name) Disconnected")
        
        withAnimation(.easeInOut(duration: 0.3)) {
            controllerToastMessage = message
        }
        
        // Announce to VoiceOver so screen reader users hear the connection change.
        AccessibilityNotification.Announcement(message).post()
        
        let dismissItem = DispatchWorkItem { [self] in
            withAnimation(.easeInOut(duration: 0.3)) {
                self.controllerToastMessage = nil
            }
        }
        controllerToastDismissTask = dismissItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5, execute: dismissItem)
    }
    
    /// A non-interactive toast banner shown at the top of the game scene.
    @ViewBuilder
    private var controllerConnectionToast: some View {
        if let message = controllerToastMessage {
            Text(message)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.primary)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial, in: Capsule())
                .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
                .padding(.top, 50)
                .transition(.move(edge: .top).combined(with: .opacity))
                .accessibilityAddTraits(.updatesFrequently)
                .allowsHitTesting(false)
        }
    }
}

// MARK: - ViewModifiers (break up type-checker expression)

/// Accessibility custom actions for VoiceOver directional movement.
private struct GameAccessibilityActions: ViewModifier {
    let transformDirection: (Int, Int) -> (column: Int, row: Int)
    let movePlayer: (Int, Int) -> Void
    let undoMove: () -> Void

    func body(content: Content) -> some View {
        content
            .accessibilityAction(named: "Move Up") {
                let dir = transformDirection(0, -1)
                movePlayer(dir.column, dir.row)
            }
            .accessibilityAction(named: "Move Down") {
                let dir = transformDirection(0, 1)
                movePlayer(dir.column, dir.row)
            }
            .accessibilityAction(named: "Move Left") {
                let dir = transformDirection(-1, 0)
                movePlayer(dir.column, dir.row)
            }
            .accessibilityAction(named: "Move Right") {
                let dir = transformDirection(1, 0)
                movePlayer(dir.column, dir.row)
            }
            .accessibilityAction(named: "Undo Move") {
                undoMove()
            }
    }
}

/// Sheet presentations (level selection + store).
private struct GameSheets: ViewModifier {
    @Binding var isLevelSheetPresented: Bool
    let appModel: AppModel
    let toggleSolution: () -> Void
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $isLevelSheetPresented) {
                NavigationStack {
                    iOSControlPanel(
                        onLevelSelected: { world, levelIndex in
                            appModel.selectedWorld = world
                            appModel.activeWorld = world
                            appModel.selectedLevelIndex = levelIndex
                            appModel.progressService.currentLevelPushes = 0
                            isLevelSheetPresented = false
                        }
                    )
                    .navigationTitle("Select Level")
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") {
                                isLevelSheetPresented = false
                            }
                        }
                    }
                }
                .environment(appModel)
                #if os(iOS)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationBackground(reduceTransparency ? .regularMaterial : .ultraThinMaterial)
                #else
                .frame(minWidth: 700, idealWidth: 800, minHeight: 450, idealHeight: 550)
                #endif
            }
            .sheet(isPresented: Binding(
                get: { appModel.inAppPurchaseService.isStoreSheetPresented },
                set: { appModel.inAppPurchaseService.isStoreSheetPresented = $0 }
            )) {
                SolutionCreditsStoreView()
                    .environment(appModel)
                    #if os(iOS)
                    .presentationDetents([.medium])
                    #else
                    .frame(minWidth: 450, idealWidth: 500, minHeight: 400, idealHeight: 500)
                    #endif
            }
            #if os(iOS)
            .persistentSystemOverlays(.hidden)
            .statusBarHidden()
            .defersSystemGestures(on: .bottom)
            #endif
    }
}

/// Keyboard arrow-key handlers.
private struct GameKeyboardHandlers: ViewModifier {
    let isAnimating: Bool
    let isLevelCompleted: Bool
    let transformDirection: (Int, Int) -> (column: Int, row: Int)
    let movePlayer: (Int, Int) -> Void

    func body(content: Content) -> some View {
        content
            .focusable()
            .onKeyPress(.upArrow) {
                guard !isAnimating, !isLevelCompleted else { return .handled }
                let dir = transformDirection(0, -1)
                movePlayer(dir.column, dir.row)
                return .handled
            }
            .onKeyPress(.downArrow) {
                guard !isAnimating, !isLevelCompleted else { return .handled }
                let dir = transformDirection(0, 1)
                movePlayer(dir.column, dir.row)
                return .handled
            }
            .onKeyPress(.leftArrow) {
                guard !isAnimating, !isLevelCompleted else { return .handled }
                let dir = transformDirection(-1, 0)
                movePlayer(dir.column, dir.row)
                return .handled
            }
            .onKeyPress(.rightArrow) {
                guard !isAnimating, !isLevelCompleted else { return .handled }
                let dir = transformDirection(1, 0)
                movePlayer(dir.column, dir.row)
                return .handled
            }
    }
}

/// onChange / onReceive handlers for state synchronisation.
private struct GameChangeHandlers: ViewModifier {
    @Binding var isLevelSheetPresented: Bool
    let appModel: AppModel
    let scenePhase: ScenePhase
    let levelRoot: Entity?
    let isLevelCompleted: Bool
    let loadCurrentLevel: () -> Void
    var cancelDropAnimation: (() -> Void)?

    func body(content: Content) -> some View {
        content
            .onChange(of: isLevelSheetPresented) { _, isPresented in
                if isPresented {
                    appModel.audioService.stopPuzzleAudio()
                } else {
                    if appModel.isPuzzleAudioEnabled && levelRoot != nil && !isLevelCompleted {
                        appModel.audioService.playPuzzleAudio()
                    }
                }
            }
            .onChange(of: appModel.selectedLevelIndex) { _, _ in loadCurrentLevel() }
            .onChange(of: appModel.activeWorld) { _, _ in loadCurrentLevel() }
            .onChange(of: scenePhase) { oldPhase, phase in
                switch phase {
                case .background, .inactive:
                    cancelDropAnimation?()
                    appModel.animationService.playerAnimationController?.pause()
                    appModel.audioService.stopPuzzleAudio()
                    appModel.animationService.stopFireworks()
                    appModel.progressService.saveProgress()
                case .active:
                    if oldPhase == .background || oldPhase == .inactive {
                        appModel.animationService.playerAnimationController?.resume()
                        if appModel.isPuzzleAudioEnabled && levelRoot != nil && !isLevelCompleted {
                            appModel.audioService.playPuzzleAudio()
                        }
                    }
                @unknown default:
                    break
                }
            }
    }

}

// MARK: - Environment Setup

/// Configures the root entity with IBL and a directional light, and returns
/// the skybox `EnvironmentResource` for the caller to apply to `content`.
/// Mirrors the approach from Apple's BOT-anist sample.
@MainActor
private func makeSceneEnvironment(root: Entity) -> EnvironmentResource? {
    // Tell RealityKit to apply IBL from the skybox at full strength.
    root.components.set(
        EnvironmentLightingConfigurationComponent(environmentLightingWeight: 1.0)
    )

    // A single warm-white directional light supplements the skybox IBL,
    // matching the BOT-anist lighting setup (intensity 2000).
    let keyLight = Entity()
    keyLight.name = "DirectionalLight"
    var keyLightComp = DirectionalLightComponent()
    keyLightComp.intensity = 2000
    keyLight.components.set(keyLightComp)
    keyLight.look(at: [0, 0, 0], from: [2, 4, 2], relativeTo: nil)
    root.addChild(keyLight)

    // Load the equirectangular panorama for use as skybox + IBL source.
    return try? EnvironmentResource(equirectangular: skyImage)
}
#endif

