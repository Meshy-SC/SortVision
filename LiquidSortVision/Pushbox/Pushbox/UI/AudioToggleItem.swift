// AudioToggleItem.swift
// Data-driven item for audio setting toggles, shared across platforms.

import SwiftUI

// MARK: - AudioToggleItem

/// Data-driven definition of a single audio toggle setting.
///
/// Each item binds a display title and SF Symbols to an `AppModel`
/// key path, and optionally triggers side effects (e.g., starting or
/// stopping playback) when the toggle changes. The canonical list
/// in ``allToggles`` drives both the visionOS popover and iOS sheet.
@MainActor
struct AudioToggleItem: Identifiable {
    let id: String
    let title: String
    let enabledIcon: String
    let disabledIcon: String
    let keyPath: ReferenceWritableKeyPath<AppModel, Bool>
    
    /// Optional action when the toggle is turned **on** (e.g. start playback).
    var onEnable: ((AppModel) -> Void)?
    
    /// Optional action when the toggle is turned **off** (e.g. stop playback).
    var onDisable: ((AppModel) -> Void)?
    
    // MARK: - All Toggles
    
    /// The canonical list of audio toggles shown in settings.
    /// The order here determines the display order in both platforms.
    static let allToggles: [AudioToggleItem] = [
        AudioToggleItem(
            id: "puzzle", title: "Puzzle Audio",
            enabledIcon: "speaker.wave.2.fill", disabledIcon: "speaker.slash.fill",
            keyPath: \.isPuzzleAudioEnabled,
            onEnable:  { $0.audioService.playPuzzleAudio() },
            onDisable: { $0.audioService.stopPuzzleAudio() }
        ),
        AudioToggleItem(
            id: "walk", title: "Walk Audio",
            enabledIcon: "figure.walk", disabledIcon: "figure.walk.circle",
            keyPath: \.isWalkAudioEnabled
        ),
        AudioToggleItem(
            id: "push", title: "Push Audio",
            enabledIcon: "cube.box.fill", disabledIcon: "cube.box",
            keyPath: \.isPushAudioEnabled
        ),
        AudioToggleItem(
            id: "undo", title: "Undo Audio",
            enabledIcon: "arrow.uturn.backward", disabledIcon: "arrow.uturn.backward.circle",
            keyPath: \.isUndoAudioEnabled
        ),
        AudioToggleItem(
            id: "fireworks", title: "Fireworks Audio",
            enabledIcon: "sparkles", disabledIcon: "sparkles",
            keyPath: \.isFireworksAudioEnabled
        ),
        AudioToggleItem(
            id: "arrival", title: "Arrival Audio",
            enabledIcon: "speaker.wave.2.fill", disabledIcon: "speaker.slash.fill",
            keyPath: \.isArrivalAudioEnabled
        ),
        AudioToggleItem(
            id: "puzzleSolved", title: "Puzzle Solved Audio",
            enabledIcon: "sparkles", disabledIcon: "sparkles",
            keyPath: \.isPuzzleSolvedAudioEnabled
        ),
        AudioToggleItem(
            id: "stuck", title: "Stuck Audio",
            enabledIcon: "exclamationmark.triangle.fill", disabledIcon: "exclamationmark.triangle",
            keyPath: \.isStuckAudioEnabled
        )
    ]
    
    // MARK: - View Builder
    
    /// Creates a SwiftUI `Toggle` configured for this descriptor.
    @MainActor @ViewBuilder
    func makeToggle(for appModel: AppModel) -> some View {
        let isOn = appModel[keyPath: keyPath]
        Toggle(isOn: Binding(
            get: { appModel[keyPath: keyPath] },
            set: { newValue in
                appModel[keyPath: keyPath] = newValue
                if newValue {
                    onEnable?(appModel)
                } else {
                    onDisable?(appModel)
                }
            }
        )) {
            Label(title, systemImage: isOn ? enabledIcon : disabledIcon)
        }
        .toggleStyle(.switch)
    }
}
