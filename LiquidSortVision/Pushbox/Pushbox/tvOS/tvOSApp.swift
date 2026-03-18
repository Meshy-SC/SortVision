// tvOSApp.swift
// tvOS app entry point with SwiftData + CloudKit configuration.

#if os(tvOS)
import SwiftUI
import SwiftData

@main
struct PushboxTVApp: App {
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
            tvOSMainView()
                .modelContainer(modelContainer)
                .cloudKitLifecycle()
                .environment(appModel)
        }
    }
}
#endif
