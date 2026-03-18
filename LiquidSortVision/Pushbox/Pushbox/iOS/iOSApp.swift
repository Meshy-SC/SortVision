// iOSApp.swift
// iOS app entry point with SwiftData + CloudKit configuration.

#if os(iOS)
import SwiftUI
import SwiftData

@main
struct PushboxiOSApp: App {
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
            iOSMainView()
                .modelContainer(modelContainer)
                .cloudKitLifecycle()
                .environment(appModel)
                .preferredColorScheme(appModel.resolvedColorScheme)
        }
    }
}
#endif
