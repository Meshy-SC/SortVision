//
//  water_puzzle_swiftApp.swift
//  water-puzzle-swift
//
//  Created by Ahmed DALHI on 05/03/2026.
//

import SwiftUI

@main
struct WaterPuzzleApp: App {
    var body: some Scene {
        WindowGroup {
            RootNavigationView()
            #if os(macOS)
                .frame(minWidth: 500, minHeight: 700)
            #endif
        }
        #if os(macOS)
        .defaultSize(width: 750, height: 1000)
        .commands {
            // Remove default "New Window" to keep single-window experience
            CommandGroup(replacing: .newItem) {}
        }
        #endif
        #if os(visionOS)
        .defaultSize(width: 750, height: 1000)
        #endif
    }
}
