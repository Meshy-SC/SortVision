// AppModel.swift
// Central app state coordinator that connects services and manages navigation.

import Foundation
import SwiftUI
import RealityKit
import SwiftData
#if os(visionOS)
import ARKit
#endif

// MARK: - AppModel

/// Central coordinator for the PushBox app.
/// Manages navigation state, scene references, and delegates functionality to specialized services.
/// Uses @Observable for fine-grained property tracking - only views accessing changed properties re-render.
@MainActor
@Observable
final class AppModel {

    // MARK: - Services

    /// In-App Purchase and solution credits management.
    let inAppPurchaseService: InAppPurchaseService

    /// Audio playback management.
    let audioService: AudioService

    /// Player animation and visual effects management.
    let animationService: AnimationService

    /// Game progress and persistence management.
    let progressService: ProgressService

    /// Level loading and caching service.
    let levelLoader: LevelLoader

    /// Game Center leaderboard and authentication service.
    let gameCenterService: GameCenterService

    // MARK: - Scene & Navigation State

    /// The main RealityKit scene entity.
    var gameScene: Entity? {
        didSet {
            // Stop audio on the old scene to prevent overlapping playback
            // when a new scene is loaded (e.g. selecting a level from the sheet).
            if let oldScene = oldValue, oldValue !== gameScene {
                oldScene.findEntity(named: "puzzleAudio")?.stopAllAudio()
            }
            // Configure services with scene reference when it's set
            audioService.configure(with: gameScene)
            animationService.configure(with: gameScene)
        }
    }

    /// Whether the control panel window is currently open.
    var isControlPanelOpen = true

    #if os(visionOS)
    /// Current camera viewpoint direction.
    var currentViewpoint: SquareAzimuth = .front
    #endif

    /// Currently selected world in the control panel.
    var selectedWorld: World? = World.allWorlds.first {
        didSet {
            if oldValue?.worldName != selectedWorld?.worldName {
                // Don't reset level selection if a game is actively in progress
                if activeWorld == nil {
                    selectedLevelIndex = nil
                }
            }
        }
    }

    /// Currently selected level index.
    var selectedLevelIndex: Int?

    /// Active world (the one currently being played).
    var activeWorld: World?

    // MARK: - Auto-solver Flags

    /// Whether the auto-solver is currently playing.
    var isPlayingSolution = false

    /// Whether the auto-solver is paused.
    var isSolutionPaused = false

    /// Whether startSolution() is currently in progress (prevents concurrent calls).
    var isStartingSolution = false

    /// The individual move characters for the current solution playback.
    var solutionMoves: [Character] = []

    #if os(visionOS)
    // MARK: - Game Phase (visionOS only)

    /// Phases of the immersive game session.
    enum GamePhase {
        /// Control panel is shown, no immersive space open.
        case controlPanel
        /// Immersive space open, user placing the board on the floor.
        case placing
        /// Board placed, gameplay active.
        case playing
    }

    /// Current phase of the immersive game session.
    var gamePhase: GamePhase = .controlPanel

    /// Shared world tracking provider for placement and viewpoint.
    var worldTrackingProvider: WorldTrackingProvider?

    // MARK: - Session Anchor State (visionOS only)

    /// Whether a spatial anchor has been established for this session.
    var hasSessionAnchor: Bool = false

    /// The world transform of the established session anchor.
    var sessionAnchorTransform: Transform?
    #endif

    // MARK: - Layout Helpers

    /// Size of each grid cell in points.
    var cellDisplaySize: Double = 100

    /// Width of the current level in cells.
    var levelWidth = 1

    /// Depth of the current level in cells.
    var levelDepth = 1

    // MARK: - Initialization

    /// Primary initializer with ModelContext for SwiftData persistence.
    init(modelContext: ModelContext) {
        self.inAppPurchaseService = InAppPurchaseService(modelContext: modelContext)
        self.audioService = AudioService()
        self.animationService = AnimationService()
        self.progressService = ProgressService(modelContext: modelContext)
        self.levelLoader = LevelLoader()
        self.gameCenterService = GameCenterService()
    }

    /// Initializer with explicit service injection for testing.
    init(
        inAppPurchaseService: InAppPurchaseService,
        audioService: AudioService,
        animationService: AnimationService,
        progressService: ProgressService,
        levelLoader: LevelLoader,
        gameCenterService: GameCenterService = GameCenterService()
    ) {
        self.inAppPurchaseService = inAppPurchaseService
        self.audioService = audioService
        self.animationService = animationService
        self.progressService = progressService
        self.levelLoader = levelLoader
        self.gameCenterService = gameCenterService
    }
    
    // MARK: - Preview Helper
    
    /// Creates an AppModel with an in-memory ModelContext for SwiftUI previews.
    static var preview: AppModel {
        let container = ModelContainerFactory.makePreviewContainer()
        return AppModel(modelContext: container.mainContext)
    }

    // MARK: - Navigation Computed Properties
    
    /// Whether navigation to the next level is possible (next level exists and is unlocked).
    var canGoToNextLevel: Bool {
        guard let world = activeWorld ?? selectedWorld,
              let currentIndex = selectedLevelIndex,
              let levels = levelLoader.cache[world.worldName] else {
            return false
        }
        let nextIndex = currentIndex + 1
        guard nextIndex < levels.count else { return false }
        return progressService.isLevelUnlocked(nextIndex, in: world)
    }
    
    /// Whether navigation to the previous level is possible.
    var canGoToPreviousLevel: Bool {
        guard let currentIndex = selectedLevelIndex else { return false }
        return currentIndex > 0
    }

    /// Whether a next level exists in the world (regardless of lock state).
    var hasNextLevel: Bool {
        guard let world = activeWorld ?? selectedWorld,
              let currentIndex = selectedLevelIndex,
              let levels = levelLoader.cache[world.worldName] else {
            return false
        }
        return currentIndex + 1 < levels.count
    }

    /// Whether the next level exists but is locked.
    var isNextLevelLocked: Bool {
        hasNextLevel && !canGoToNextLevel
    }

    /// Unlock requirement message for the next level, if it is locked.
    var nextLevelLockMessage: String? {
        guard let world = activeWorld ?? selectedWorld,
              let currentIndex = selectedLevelIndex else { return nil }
        return progressService.unlockRequirement(forLevel: currentIndex + 1, in: world)
    }
    
    /// Gets the optimal push count for the current level.
    var optimalPushes: Int? {
        progressService.optimalPushes(
            for: activeWorld ?? selectedWorld,
            levelIndex: selectedLevelIndex
        )
    }
    
    // MARK: - Appearance Mode

    /// User's preferred appearance mode, persisted across launches.
    @ObservationIgnored @AppStorage("appearanceMode") private var storedAppearanceMode: String = AppearanceMode.dark.rawValue

    /// The user's chosen appearance mode (system / light / dark).
    var appearanceMode: AppearanceMode {
        get {
            access(keyPath: \.appearanceMode)
            return AppearanceMode(rawValue: storedAppearanceMode) ?? .system
        }
        set {
            withMutation(keyPath: \.appearanceMode) {
                storedAppearanceMode = newValue.rawValue
            }
        }
    }

    /// Resolved `ColorScheme` for SwiftUI's `preferredColorScheme`.
    /// Returns `nil` for `.system` so the device default is used.
    var resolvedColorScheme: ColorScheme? {
        switch appearanceMode {
        case .system: return nil
        case .light:  return .light
        case .dark:   return .dark
        }
    }

    // MARK: - Board Scale (visionOS)

    @ObservationIgnored @AppStorage("boardScale") private var storedBoardScale: Double = 1.0

    var boardScale: Double {
        get {
            access(keyPath: \.boardScale)
            return storedBoardScale
        }
        set {
            withMutation(keyPath: \.boardScale) {
                storedBoardScale = newValue
            }
        }
    }

    // MARK: - Audio Toggle Bindings
    //
    // These forwarding properties bridge AudioService's @ObservationIgnored @AppStorage
    // properties to @Observable bindings. The generic helper below calls
    // access()/withMutation() to ensure SwiftUI detects changes and re-renders.
    
    /// Generic helper that bridges an `@ObservationIgnored @AppStorage` property
    /// on `AudioService` to an `@Observable` binding on `AppModel`.
    ///
    /// - Parameters:
    ///   - appModelKeyPath: The key path on `AppModel` for observation tracking.
    ///   - serviceKeyPath: The key path on `AudioService` for the actual stored value.
    ///   - newValue: When non-nil, writes `newValue` through to the service.
    /// - Returns: The current value of the service property.
    @discardableResult
    private func audioToggle(
        _ appModelKeyPath: KeyPath<AppModel, Bool>,
        service serviceKeyPath: ReferenceWritableKeyPath<AudioService, Bool>,
        set newValue: Bool? = nil
    ) -> Bool {
        if let newValue {
            withMutation(keyPath: appModelKeyPath) {
                audioService[keyPath: serviceKeyPath] = newValue
            }
            return newValue
        } else {
            access(keyPath: appModelKeyPath)
            return audioService[keyPath: serviceKeyPath]
        }
    }
    
    var isPuzzleAudioEnabled: Bool {
        get { audioToggle(\.isPuzzleAudioEnabled, service: \.isPuzzleAudioEnabled) }
        set { audioToggle(\.isPuzzleAudioEnabled, service: \.isPuzzleAudioEnabled, set: newValue) }
    }
    var isWalkAudioEnabled: Bool {
        get { audioToggle(\.isWalkAudioEnabled, service: \.isWalkAudioEnabled) }
        set { audioToggle(\.isWalkAudioEnabled, service: \.isWalkAudioEnabled, set: newValue) }
    }
    var isPushAudioEnabled: Bool {
        get { audioToggle(\.isPushAudioEnabled, service: \.isPushAudioEnabled) }
        set { audioToggle(\.isPushAudioEnabled, service: \.isPushAudioEnabled, set: newValue) }
    }
    var isUndoAudioEnabled: Bool {
        get { audioToggle(\.isUndoAudioEnabled, service: \.isUndoAudioEnabled) }
        set { audioToggle(\.isUndoAudioEnabled, service: \.isUndoAudioEnabled, set: newValue) }
    }
    var isFireworksAudioEnabled: Bool {
        get { audioToggle(\.isFireworksAudioEnabled, service: \.isFireworksAudioEnabled) }
        set { audioToggle(\.isFireworksAudioEnabled, service: \.isFireworksAudioEnabled, set: newValue) }
    }
    var isArrivalAudioEnabled: Bool {
        get { audioToggle(\.isArrivalAudioEnabled, service: \.isArrivalAudioEnabled) }
        set { audioToggle(\.isArrivalAudioEnabled, service: \.isArrivalAudioEnabled, set: newValue) }
    }
    var isPuzzleSolvedAudioEnabled: Bool {
        get { audioToggle(\.isPuzzleSolvedAudioEnabled, service: \.isPuzzleSolvedAudioEnabled) }
        set { audioToggle(\.isPuzzleSolvedAudioEnabled, service: \.isPuzzleSolvedAudioEnabled, set: newValue) }
    }
    var isStuckAudioEnabled: Bool {
        get { audioToggle(\.isStuckAudioEnabled, service: \.isStuckAudioEnabled) }
        set { audioToggle(\.isStuckAudioEnabled, service: \.isStuckAudioEnabled, set: newValue) }
    }
    
    // MARK: - Derived State
    
    /// Total levels per world — delegates to the shared static on `World`.
    var worldTotalLevels: [String: Int] { World.totalLevelsPerWorld }
    
    // MARK: - Game Phase Methods

    #if os(visionOS)
    /// Transitions to the placing phase for a new level.
    func startLevelPlacement(world: World, levelIndex: Int) {
        selectedWorld = world
        activeWorld = world
        selectedLevelIndex = levelIndex
        progressService.currentLevelPushes = 0
        gamePhase = .placing
    }

    /// Confirms placement and transitions to the playing phase.
    func confirmLevelPlacement() {
        gamePhase = .playing
    }

    /// Activates a level reusing the existing session anchor (skip placement).
    func activateLevelAtSessionAnchor(world: World, levelIndex: Int) {
        selectedWorld = world
        activeWorld = world
        selectedLevelIndex = levelIndex
        progressService.currentLevelPushes = 0
        gamePhase = .playing
    }

    // MARK: - Session Anchor Methods

    func saveSessionAnchor(transform: Transform) {
        sessionAnchorTransform = transform
        hasSessionAnchor = true
    }

    func resetSessionAnchor() {
        hasSessionAnchor = false
        sessionAnchorTransform = nil
        gamePhase = .controlPanel
    }
    #endif
}

// MARK: - AppearanceMode

/// User-selectable appearance mode for the app.
enum AppearanceMode: String, CaseIterable, Identifiable {
    case system = "system"
    case light  = "light"
    case dark   = "dark"

    var id: String { rawValue }

    /// Human-readable label for the picker.
    var label: String {
        switch self {
        case .system: return "System"
        case .light:  return "Light"
        case .dark:   return "Dark"
        }
    }

    /// SF Symbol icon name.
    var icon: String {
        switch self {
        case .system: return "circle.lefthalf.filled"
        case .light:  return "sun.max"
        case .dark:   return "moon"
        }
    }
}

