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
    }
}

// MARK: - URL Scheme
// Register "waterpuzzle" in Info.plist > URL Types for deep link support:
//   URL Schemes: waterpuzzle
//   URL Identifier: $(PRODUCT_BUNDLE_IDENTIFIER)
// This enables Widget and Shortcuts integration via waterpuzzle://play?mode=0&level=5
