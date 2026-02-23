//
//  NyaSquatApp.swift
//  NyaSquat
//
//  Based on Nya by maa, extended with squat features
//

import SwiftUI

@main
struct NyaSquatApp: App {
    @StateObject private var monitor = AppMonitor()
    @StateObject private var squatCounter = SquatCounter()
    @State private var showSquatWindow = false

    var body: some Scene {
        // Menu Bar
        MenuBarExtra("NyaSquat", systemImage: "cat.fill") {
            MenuBarView(
                monitor: monitor,
                squatCounter: squatCounter,
                showSquatWindow: $showSquatWindow
            )
        }

        // Squat Window (opens when triggered)
        Window("NyaSquat", id: "squat-window") {
            SquatView(
                squatCounter: squatCounter,
                onComplete: {
                    showSquatWindow = false
                    monitor.resetTimer()
                    // Close the squat window
                    NSApp.windows
                        .first { $0.identifier?.rawValue == "squat-window" || $0.title == "NyaSquat" }?
                        .close()
                }
            )
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 420, height: 560)
    }
}
