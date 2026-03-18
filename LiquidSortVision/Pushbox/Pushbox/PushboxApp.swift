// PushboxApp.swift
// Main app entry point with SwiftData + CloudKit configuration.

#if os(visionOS)
import SwiftUI
import SwiftData

@main
struct PushboxApp: App {
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
        // 2D control panel window for level/world selection
        WindowGroup(id: "ControlPanel") {
            ControlPanelWindowView()
                .modelContainer(modelContainer)
                .cloudKitLifecycle()
                .environment(appModel)
        }
        .windowStyle(.plain)
        .windowResizability(.contentSize)
        .defaultSize(width: 750, height: 575)

        // 2D window for purchasing solution credits (sheets don't work from immersive space attachments)
        WindowGroup(id: "SolutionCreditsStore") {
            SolutionCreditsStoreView()
                .environment(appModel)
                .modelContainer(modelContainer)
                .frame(width: 440, height: 640)
                .glassBackgroundEffect()
                .onDisappear {
                    appModel.inAppPurchaseService.isStoreSheetPresented = false
                }
        }
        .windowStyle(.plain)
        .windowResizability(.contentSize)
        .defaultSize(width: 440, height: 640)

        // Mixed immersive space for placement + gameplay
        ImmersiveSpace(id: "GameSpace") {
            ImmersiveGameView()
                .environment(appModel)
        }
        .immersionStyle(selection: .constant(.mixed), in: .mixed)
    }
}
#endif
