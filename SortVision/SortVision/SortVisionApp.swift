//
//  SortVisionApp.swift
//  SortVision
//
//  Created by Ahmed DALHI on 05/03/2026.
//

import SwiftUI

@main
struct SortVisionApp: App {
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
// Register "flowvision" in Info.plist > URL Types for deep link support:
//   URL Schemes: flowvision
//   URL Identifier: $(PRODUCT_BUNDLE_IDENTIFIER)
// This enables Widget and Shortcuts integration via flowvision://play?mode=0&level=5
