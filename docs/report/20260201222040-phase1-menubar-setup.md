# Phase 1: MenuBarExtra + アクティブアプリ監視の実装

## 実行日時
2026-02-01 22:20

## 受けた指示

Nya（macOSメニューバー常駐アプリ）のPhase 1実装：
1. プロジェクト構造を確認
2. 最小構成でMenuBarExtraが表示されるようにNyaApp.swiftを修正
3. WindowGroupを削除してMenuBarExtraだけにする
4. ActiveAppMonitor.swiftを作成（アクティブアプリ名をログ出力）
5. xcodebuildでビルドして動作確認

## 実装内容

### 1. NyaApp.swift の修正

WindowGroupからMenuBarExtraに変更：

```swift
@main
struct NyaApp: App {
    @StateObject private var monitor = ActiveAppMonitor()

    var body: some Scene {
        MenuBarExtra("Nya", systemImage: "cat.fill") {
            Text("🐱 Nya is watching...")
            Divider()
            if let currentApp = monitor.currentAppName {
                Text("Current: \(currentApp)")
            }
            Divider()
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }
    }
}
```

### 2. ActiveAppMonitor.swift の新規作成

NSWorkspace.shared.notificationCenterを使用してアプリ切り替えを監視：

```swift
@MainActor
final class ActiveAppMonitor: ObservableObject {
    @Published var currentAppName: String?
    private var cancellable: AnyCancellable?

    init() {
        currentAppName = NSWorkspace.shared.frontmostApplication?.localizedName

        cancellable = NSWorkspace.shared.notificationCenter
            .publisher(for: NSWorkspace.didActivateApplicationNotification)
            .sink { [weak self] notification in
                guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey]
                        as? NSRunningApplication else { return }
                let appName = app.localizedName ?? "Unknown"
                self?.currentAppName = appName
                print("🐱 App switched to: \(appName)")
            }
    }
}
```

## 変更ファイル一覧

| ファイル | 変更種別 | 内容 |
|---------|---------|------|
| `Nya/NyaApp.swift` | 修正 | WindowGroup → MenuBarExtra |
| `Nya/ActiveAppMonitor.swift` | 新規 | アクティブアプリ監視クラス |

## ビルド結果

```
** BUILD SUCCEEDED **
```

## Phase 1 完了状況

- [x] MenuBarExtraが表示される
- [x] Quitボタンで終了できる
- [x] アクティブアプリ名をログ出力

## 次のステップ（Phase 2）

- [ ] 禁止アプリリストの定義
- [ ] 禁止アプリ検知ロジック
- [ ] 検知時に猫が鳴く（音声再生）
- [ ] 検知回数カウント
