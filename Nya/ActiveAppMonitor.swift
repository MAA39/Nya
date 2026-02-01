//
//  ActiveAppMonitor.swift
//  Nya
//
//  Created by maa on 2026/02/01.
//

import AppKit
import Combine

@MainActor
final class ActiveAppMonitor: ObservableObject {
    @Published var currentAppName: String?
    @Published var distractionCount: Int = 0
    @Published var isCurrentlyDistracted: Bool = false

    private var cancellable: AnyCancellable?

    // 禁止アプリリスト
    let blockedApps: Set<String> = [
        "Twitter",
        "X",
        "Instagram",
        "Facebook",
        "YouTube",
        "TikTok",
        "Reddit"
    ]

    init() {
        // 初期値を設定
        currentAppName = NSWorkspace.shared.frontmostApplication?.localizedName

        // アプリ切り替えを監視
        // 重要: NotificationCenter.default ではなく NSWorkspace.shared.notificationCenter を使う
        cancellable = NSWorkspace.shared.notificationCenter
            .publisher(for: NSWorkspace.didActivateApplicationNotification)
            .sink { [weak self] notification in
                guard let self,
                      let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey]
                        as? NSRunningApplication else { return }

                let appName = app.localizedName ?? "Unknown"
                self.currentAppName = appName

                print("🐱 App switched to: \(appName)")

                // 禁止アプリチェック
                let isBlocked = self.isBlocked(appName: appName)
                self.isCurrentlyDistracted = isBlocked

                if isBlocked {
                    self.handleDistraction(appName: appName)
                }
            }
    }

    private func isBlocked(appName: String) -> Bool {
        blockedApps.contains(appName)
    }

    private func handleDistraction(appName: String) {
        distractionCount += 1
        print("🚨 Distraction detected: \(appName) (count: \(distractionCount))")
        SoundPlayer.shared.playMeow()
    }
}
