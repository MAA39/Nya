# Phase 3 参考コード集

このファイルはコーディング時にコピペで使えるスニペット集。
Deep Research調査結果から抜粋・整理したもの。

---

## 1. AppleScript（ブラウザURL取得）

### Chrome用（落ちない版）

```applescript
tell application "Google Chrome"
  if not (exists front window) then return ""
  if (count of tabs of front window) = 0 then return ""
  set theTab to active tab of front window
  if theTab is missing value then return ""
  set theURL to URL of theTab
  if theURL is missing value then return ""
  return theURL as text
end tell
```

### Safari用（落ちない版）

```applescript
tell application "Safari"
  if not (exists front document) then return ""
  set theURL to URL of front document
  if theURL is missing value then return ""
  return theURL as text
end tell
```

---

## 2. AppleScriptRunner.swift

```swift
import Foundation

enum AppleScriptError: Error, CustomStringConvertible {
    case compileFailed(message: String)
    case executeFailed(code: Int, message: String)
    case notAuthorized

    var description: String {
        switch self {
        case .compileFailed(let message):
            return "AppleScript compile failed: \(message)"
        case .executeFailed(let code, let message):
            return "AppleScript execute failed (\(code)): \(message)"
        case .notAuthorized:
            return "Automation permission denied. Please allow in System Settings."
        }
    }
}

final class AppleScriptRunner {
    private var cache: [String: NSAppleScript] = [:]
    private let lock = NSLock()

    func run(_ source: String) throws -> String {
        let script: NSAppleScript = try {
            lock.lock()
            defer { lock.unlock() }

            if let cached = cache[source] {
                return cached
            }

            guard let newScript = NSAppleScript(source: source) else {
                throw AppleScriptError.compileFailed(message: "NSAppleScript(source:) returned nil")
            }

            cache[source] = newScript
            return newScript
        }()

        var errorInfo: NSDictionary?
        let result = script.executeAndReturnError(&errorInfo)

        if let errorInfo {
            let code = (errorInfo[NSAppleScript.errorNumber] as? Int) ?? -1
            let message = (errorInfo[NSAppleScript.errorMessage] as? String) ?? "Unknown error"

            // -1743 = Automation permission denied
            if code == -1743 {
                throw AppleScriptError.notAuthorized
            }

            throw AppleScriptError.executeFailed(code: code, message: message)
        }

        return result.stringValue ?? ""
    }
}
```

---

## 3. URLMonitor.swift

```swift
import AppKit
import Foundation

@MainActor
final class URLMonitor: ObservableObject {
    @Published var currentURL: URL?
    @Published var currentHost: String?
    @Published var isAuthorized: Bool = true

    private let runner = AppleScriptRunner()
    private var timer: DispatchSourceTimer?
    private let queue = DispatchQueue(label: "URLMonitor.timer", qos: .utility)

    private let chromeScript = #"""
    tell application "Google Chrome"
      if not (exists front window) then return ""
      if (count of tabs of front window) = 0 then return ""
      set theTab to active tab of front window
      if theTab is missing value then return ""
      set theURL to URL of theTab
      if theURL is missing value then return ""
      return theURL as text
    end tell
    """#

    private let safariScript = #"""
    tell application "Safari"
      if not (exists front document) then return ""
      set theURL to URL of front document
      if theURL is missing value then return ""
      return theURL as text
    end tell
    """#

    func start() {
        observeFrontmostApp()
        rescheduleTimer(interval: 10)
    }

    func stop() {
        timer?.cancel()
        timer = nil
    }

    private func observeFrontmostApp() {
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            let bundleID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? ""

            if bundleID == "com.apple.Safari" || bundleID == "com.google.Chrome" {
                self.rescheduleTimer(interval: 30)
                self.tick() // 前面になった瞬間に1回チェック
            } else {
                self.rescheduleTimer(interval: 10)
                self.currentURL = nil
                self.currentHost = nil
            }
        }
    }

    private func rescheduleTimer(interval: TimeInterval) {
        timer?.cancel()

        let t = DispatchSource.makeTimerSource(queue: queue)
        t.schedule(
            deadline: .now() + interval,
            repeating: interval,
            leeway: .milliseconds(6000) // 20% leeway for 30s interval
        )
        t.setEventHandler { [weak self] in
            Task { @MainActor in
                self?.tick()
            }
        }
        t.resume()
        timer = t
    }

    private func tick() {
        guard let bundleID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier else {
            return
        }

        let script: String
        switch bundleID {
        case "com.apple.Safari":
            script = safariScript
        case "com.google.Chrome":
            script = chromeScript
        default:
            return
        }

        do {
            let urlString = try runner.run(script).trimmingCharacters(in: .whitespacesAndNewlines)

            if urlString.isEmpty {
                currentURL = nil
                currentHost = nil
                return
            }

            if let url = URL(string: urlString) {
                currentURL = url
                currentHost = url.host?.replacingOccurrences(of: "www.", with: "")
            }

            isAuthorized = true

        } catch AppleScriptError.notAuthorized {
            isAuthorized = false
            currentURL = nil
            currentHost = nil
        } catch {
            // Other errors: log and continue
            print("URLMonitor error: \(error)")
        }
    }
}
```

---

## 4. AppSettings.swift

```swift
import SwiftUI

@MainActor
final class AppSettings: ObservableObject {
    @AppStorage("volumePercent") var volumePercent: Int = 70
    @AppStorage("gracePeriod") var gracePeriod: Int = 10
    @AppStorage("repeatInterval") var repeatInterval: Int = 15

    @AppStorage("blockedDomainsData") private var blockedDomainsData: Data = Data()

    static let defaultBlockedDomains = [
        "twitter.com",
        "x.com",
        "instagram.com",
        "facebook.com",
        "youtube.com",
        "tiktok.com",
        "reddit.com"
    ]

    var blockedDomains: [String] {
        get {
            guard !blockedDomainsData.isEmpty,
                  let decoded = try? JSONDecoder().decode([String].self, from: blockedDomainsData) else {
                return Self.defaultBlockedDomains
            }
            return decoded
        }
        set {
            blockedDomainsData = (try? JSONEncoder().encode(newValue)) ?? Data()
        }
    }

    func isBlocked(host: String?) -> Bool {
        guard let host = host?.lowercased() else { return false }
        return blockedDomains.contains { domain in
            host == domain || host.hasSuffix(".\(domain)")
        }
    }

    func addDomain(_ domain: String) {
        let normalized = domain.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty, !blockedDomains.contains(normalized) else { return }
        blockedDomains.append(normalized)
    }

    func removeDomain(at index: Int) {
        guard blockedDomains.indices.contains(index) else { return }
        blockedDomains.remove(at: index)
    }
}
```

---

## 5. SettingsView.swift

```swift
import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings: AppSettings
    @State private var newDomain: String = ""

    var body: some View {
        Form {
            Section("音量") {
                HStack {
                    Text("🔊")
                    Slider(value: Binding(
                        get: { Double(settings.volumePercent) },
                        set: { settings.volumePercent = Int($0) }
                    ), in: 0...100, step: 1)
                    Text("\(settings.volumePercent)%")
                        .monospacedDigit()
                        .frame(width: 50)
                }
            }

            Section("タイミング") {
                Stepper("⏱️ 猶予時間: \(settings.gracePeriod)秒", value: $settings.gracePeriod, in: 1...60)
                Stepper("🔁 繰り返し: \(settings.repeatInterval)秒", value: $settings.repeatInterval, in: 5...60)
            }

            Section("ブロック対象ドメイン") {
                List {
                    ForEach(settings.blockedDomains, id: \.self) { domain in
                        Text(domain)
                    }
                    .onDelete { indexSet in
                        for index in indexSet {
                            settings.removeDomain(at: index)
                        }
                    }
                }
                .frame(height: 150)

                HStack {
                    TextField("ドメインを追加", text: $newDomain)
                        .textFieldStyle(.roundedBorder)
                    Button("追加") {
                        settings.addDomain(newDomain)
                        newDomain = ""
                    }
                    .disabled(newDomain.isEmpty)
                }
            }
        }
        .padding()
        .frame(width: 400, height: 400)
    }
}
```

---

## 6. SoundPlayer.swift（音量対応版）

```swift
import AVFoundation

@MainActor
final class SoundPlayer {
    static let shared = SoundPlayer()
    private var audioPlayer: AVAudioPlayer?

    private init() {
        loadSound()
    }

    private func loadSound() {
        if let url = Bundle.main.url(forResource: "meow", withExtension: "mp3") {
            do {
                audioPlayer = try AVAudioPlayer(contentsOf: url)
                audioPlayer?.prepareToPlay()
            } catch {
                print("Failed to load sound: \(error)")
            }
        }
    }

    func playMeow(volumePercent: Int = 70) {
        if audioPlayer == nil {
            loadSound()
        }

        guard let player = audioPlayer else {
            NSSound.beep()
            return
        }

        player.volume = Float(volumePercent) / 100.0
        player.currentTime = 0
        player.play()
    }
}
```

---

## 7. Info.plist 追加項目

```xml
<!-- Apple Events permission description -->
<key>NSAppleEventsUsageDescription</key>
<string>Nyaはブラウザのタブを監視して、SNSの見すぎを防ぎます。</string>
```

---

## 8. 権限エラー時のUI誘導

```swift
import SwiftUI
import AppKit

struct PermissionAlertView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundColor(.orange)

            Text("オートメーション権限が必要です")
                .font(.headline)

            Text("Nyaがブラウザを監視するには、システム設定で許可が必要です。")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)

            Button("システム設定を開く") {
                openAutomationSettings()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .frame(width: 300)
    }

    private func openAutomationSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation") {
            NSWorkspace.shared.open(url)
        }
    }
}
```

---

## 9. 警告ロジック統合（ActiveAppMonitor拡張）

```swift
// ActiveAppMonitor.swift に追加するプロパティとメソッド

// プロパティ追加
private var graceTimer: Timer?
private var repeatTimer: Timer?
private var blockedStartTime: Date?

// メソッド追加
private func handleURLChange(host: String?, settings: AppSettings) {
    let isBlocked = settings.isBlocked(host: host)

    if isBlocked {
        if blockedStartTime == nil {
            // ブロックURL検知開始
            blockedStartTime = Date()
            startGraceTimer(settings: settings)
        }
    } else {
        // ブロック解除
        stopAllTimers()
        blockedStartTime = nil
    }
}

private func startGraceTimer(settings: AppSettings) {
    graceTimer?.invalidate()
    graceTimer = Timer.scheduledTimer(withTimeInterval: TimeInterval(settings.gracePeriod), repeats: false) { [weak self] _ in
        Task { @MainActor in
            self?.triggerWarning(settings: settings)
        }
    }
}

private func triggerWarning(settings: AppSettings) {
    distractionCount += 1
    SoundPlayer.shared.playMeow(volumePercent: settings.volumePercent)
    startRepeatTimer(settings: settings)
}

private func startRepeatTimer(settings: AppSettings) {
    repeatTimer?.invalidate()
    repeatTimer = Timer.scheduledTimer(withTimeInterval: TimeInterval(settings.repeatInterval), repeats: true) { [weak self] _ in
        Task { @MainActor in
            self?.distractionCount += 1
            SoundPlayer.shared.playMeow(volumePercent: settings.volumePercent)
        }
    }
}

private func stopAllTimers() {
    graceTimer?.invalidate()
    graceTimer = nil
    repeatTimer?.invalidate()
    repeatTimer = nil
}
```

---

## 10. BundleID一覧（対象ブラウザ）

```swift
enum BrowserBundleID {
    static let safari = "com.apple.Safari"
    static let chrome = "com.google.Chrome"

    // 将来拡張用
    static let firefox = "org.mozilla.firefox"
    static let brave = "com.brave.Browser"
    static let edge = "com.microsoft.edgemac"
    static let arc = "company.thebrowser.Browser"

    static let supported: Set<String> = [safari, chrome]

    static func isSupported(_ bundleID: String?) -> Bool {
        guard let bundleID else { return false }
        return supported.contains(bundleID)
    }
}
```
