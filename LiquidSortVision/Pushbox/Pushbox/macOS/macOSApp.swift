// macOSApp.swift
// macOS app entry point with SwiftData + CloudKit configuration.

#if os(macOS)
import SwiftUI
import SwiftData

@main
struct PushboxMacApp: App {
    /// SwiftData ModelContainer configured with CloudKit sync.
    private let modelContainer: ModelContainer
    
    /// Central app state coordinator.
    @State private var appModel: AppModel
    
    init() {
        let container = ModelContainerFactory.makeContainer()
        self.modelContainer = container
        self._appModel = State(initialValue: AppModel(modelContext: container.mainContext))
    }
    
    var body: some Scene {
        WindowGroup {
            macOSMainView()
                .modelContainer(modelContainer)
                .cloudKitLifecycle()
                .environment(appModel)
                .preferredColorScheme(appModel.resolvedColorScheme)
        }
        .defaultSize(width: 1100, height: 750)
        .windowToolbarStyle(.unified)
        .commands {
            GameCommands()
        }
        
        // Native macOS Settings window (Cmd+,)
        Settings {
            SettingsView()
                .environment(appModel)
        }
    }
}
#endif
