//
//  NyaApp.swift
//  Nya
//
//  Created by maa on 2026/02/01.
//

import SwiftUI

@main
struct NyaApp: App {
    @StateObject private var monitor = ActiveAppMonitor()

    var body: some Scene {
        MenuBarExtra("Nya", systemImage: "cat.fill") {
            Text("🐱 Nya is watching...")
                .padding(.vertical, 4)

            Divider()

            if let currentApp = monitor.currentAppName {
                Text("Current: \(currentApp)")
                    .foregroundColor(.secondary)
            }

            Text("Today: \(monitor.distractionCount) distractions")
                .foregroundColor(monitor.isCurrentlyDistracted ? .red : .secondary)

            Divider()

            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }
    }
}
