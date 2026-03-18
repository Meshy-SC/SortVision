# PushBox visionOS - Project Structure

A Sokoban-style puzzle game for Apple Vision Pro.

## Architecture Overview

The app follows a service-based architecture with clear separation of concerns:

```
Pushbox/
├── PushboxApp.swift              # App entry point
├── Services/                     # Business logic services
│   ├── InAppPurchaseService.swift # In-App Purchase handling
│   ├── AudioService.swift        # Audio playback
│   ├── AnimationService.swift    # Player animations & effects
│   └── ProgressService.swift     # Game progress persistence
├── Systems/
│   └── AppModel.swift            # Central state coordinator
├── Views/
│   ├── Components/               # Reusable UI components
│   │   ├── StarRatingView.swift
│   │   ├── WorldRowView.swift
│   │   └── LevelButtonView.swift
│   └── ViewModifiers/
│       └── SelectableCardToggleStyle.swift
├── UI/                           # Main views
│   ├── ControlPanelView.swift
│   ├── LevelsGridView.swift
│   └── GaugeView.swift
├── Ornaments/                    # visionOS ornament views
├── Volume/                       # 3D volume view & logic
│   ├── VolumeView.swift
│   ├── LevelBuilder.swift
│   ├── Movement.swift
│   ├── Navigation.swift
│   └── SolutionPlayback.swift
├── Data/                         # Data models & loading
│   ├── World.swift
│   ├── LevelLoader.swift
│   └── LevelProgress.swift
├── GameTypes/
│   └── GameTypes.swift           # Core game types
├── Errors/
│   └── GameError.swift           # Error definitions
└── Worlds/                       # Level data files
    ├── World1.txt
    ├── World2.txt
    ├── World3.txt
    └── World4.txt
```

## Key Patterns

### Dependency Injection
`AppModel` coordinates services via constructor injection, enabling testability:

```swift
let appModel = AppModel(
    inAppPurchaseService: mockIAP,
    audioService: mockAudio,
    ...
)
```

### Service Layer
Each service handles a single responsibility:
- **InAppPurchaseService**: StoreKit integration, credits management
- **AudioService**: All game audio playback
- **AnimationService**: RealityKit entity animations
- **ProgressService**: UserDefaults persistence, scoring

### Error Handling
Centralized `GameError` enum with localized descriptions for user-friendly error messages.

## Building

```bash
cd visionOS
xcodebuild -project Pushbox.xcodeproj -scheme Pushbox \
  -destination 'platform=visionOS Simulator,name=Apple Vision Pro' build
```
