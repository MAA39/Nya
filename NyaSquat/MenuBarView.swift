//
//  MenuBarView.swift
//  NyaSquat
//

import SwiftUI

struct MenuBarView: View {
    @ObservedObject var monitor: AppMonitor
    @ObservedObject var squatCounter: SquatCounter
    @Binding var showSquatWindow: Bool
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("🐱 NyaSquat")
                .font(.headline)
                .padding(.vertical, 4)

            Divider()

            Text("📊 今日のスクワット: \(squatCounter.todayTotal)回")
                .foregroundColor(.secondary)

            if monitor.isCurrentlyDistracted {
                Text("⏱️ SNS: \(monitor.timerText)")
                    .foregroundColor(.red)
            } else {
                Text("⏱️ SNS: 監視中")
                    .foregroundColor(.secondary)
            }

            if let app = monitor.currentAppName {
                Text("Current: \(app)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Divider()

            Button("🏋️ スクワット開始") {
                openWindow(id: "squat-window")
                showSquatWindow = true
            }

            Divider()

            Button("終了") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }
        .padding(.horizontal, 4)
        .onChange(of: monitor.shouldTriggerSquat) { triggered in
            if triggered {
                openWindow(id: "squat-window")
                showSquatWindow = true
            }
        }
    }
}
