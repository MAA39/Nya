//
//  AppMonitor.swift
//  NyaSquat
//
//  SNS監視 + 滞在時間タイマー → スクワット発火
//

import AppKit
import Combine

@MainActor
final class AppMonitor: ObservableObject {
    @Published var currentAppName: String?
    @Published var isCurrentlyDistracted: Bool = false
    @Published var distractionSeconds: Int = 0
    @Published var shouldTriggerSquat: Bool = false

    private var cancellable: AnyCancellable?
    private var timer: Timer?
    private var settings = SquatSettings.shared

    // 禁止アプリリスト（アプリ名）
    let blockedApps: Set<String> = [
        "Twitter", "X", "Instagram", "Facebook",
        "YouTube", "TikTok", "Reddit"
    ]

    // 禁止URL（ブラウザタブ用）
    let blockedURLPatterns: [String] = [
        "twitter.com", "x.com", "youtube.com",
        "instagram.com", "tiktok.com", "reddit.com"
    ]

    var triggerMinutes: Int { settings.triggerMinutes }
    var triggerSeconds: Int { settings.triggerMinutes * 60 }
    var progressRatio: Double {
        guard triggerSeconds > 0 else { return 0 }
        return min(Double(distractionSeconds) / Double(triggerSeconds), 1.0)
    }
    var timerText: String {
        let mins = distractionSeconds / 60
        let secs = distractionSeconds % 60
        let total = settings.triggerMinutes
        return String(format: "%d:%02d / %d:00", mins, secs, total)
    }

    init() {
        currentAppName = NSWorkspace.shared.frontmostApplication?.localizedName

        // アプリ切り替え監視
        cancellable = NSWorkspace.shared.notificationCenter
            .publisher(for: NSWorkspace.didActivateApplicationNotification)
            .sink { [weak self] notification in
                guard let self,
                      let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey]
                        as? NSRunningApplication else { return }

                let appName = app.localizedName ?? "Unknown"
                self.currentAppName = appName

                let isBlocked = self.isBlockedApp(appName: appName)
                self.isCurrentlyDistracted = isBlocked

                if isBlocked {
                    self.startTimer()
                } else {
                    self.stopTimer()
                }
            }

        // 初期状態チェック
        if let name = currentAppName, isBlockedApp(appName: name) {
            isCurrentlyDistracted = true
            startTimer()
        }
    }

    // MARK: - Blocked Check

    private func isBlockedApp(appName: String) -> Bool {
        blockedApps.contains(appName)
    }

    // MARK: - Timer

    private func startTimer() {
        guard timer == nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.distractionSeconds += 1

                if self.distractionSeconds >= self.triggerSeconds && !self.shouldTriggerSquat {
                    self.shouldTriggerSquat = true
                    SoundPlayer.shared.playMeow()
                    print("🐱 Squat time! (\(self.distractionSeconds)s on SNS)")
                }
            }
        }
    }

    private func stopTimer() {
        // SNS離れてもタイマーはリセットしない（累積）
        timer?.invalidate()
        timer = nil
    }

    func resetTimer() {
        timer?.invalidate()
        timer = nil
        distractionSeconds = 0
        shouldTriggerSquat = false
    }
}
