# Phase 3 技術設計書: URL監視機能

## 技術スタック

| 項目 | 技術 | 理由 |
|------|------|------|
| URL取得 | NSAppleScript | 高速（プロセス起動不要）、エラー情報取得可能 |
| タイマー | DispatchSourceTimer | 省電力（leeway対応）、GCDで安定 |
| 前面アプリ検知 | NSWorkspace | 既存実装を活用 |
| 設定保存 | @AppStorage + Codable→Data | SwiftUIと相性◎ |
| 音量制御 | AVAudioPlayer.volume | 既存実装を拡張 |

---

## アーキテクチャ

### ファイル構成（新規/変更）

```
Nya/
├── NyaApp.swift              # 変更: Settings画面追加
├── ActiveAppMonitor.swift    # 変更: URLMonitorと連携
├── URLMonitor.swift          # 新規: URL監視ロジック
├── AppleScriptRunner.swift   # 新規: AppleScript実行ユーティリティ
├── AppSettings.swift         # 新規: 設定の永続化
├── SettingsView.swift        # 新規: 設定画面UI
├── SoundPlayer.swift         # 変更: 音量設定対応
└── Info.plist                # 変更: 権限設定追加
```

### クラス図

```
┌─────────────────┐     ┌─────────────────┐
│   NyaApp        │────▶│  AppSettings    │
│   (SwiftUI)     │     │  (@AppStorage)  │
└────────┬────────┘     └─────────────────┘
         │                      ▲
         ▼                      │
┌─────────────────┐     ┌───────┴─────────┐
│ ActiveAppMonitor│────▶│   URLMonitor    │
│ (既存拡張)       │     │ (新規)          │
└─────────────────┘     └────────┬────────┘
                                 │
                                 ▼
                        ┌─────────────────┐
                        │AppleScriptRunner│
                        │ (新規)          │
                        └─────────────────┘
```

---

## 詳細設計

### 1. AppleScriptRunner（新規）

**責務**: AppleScriptの実行とエラーハンドリング

**設計方針**:
- NSAppleScriptを使用（Processでosascript実行は避ける）
- スクリプトをキャッシュして再利用
- エラーコード-1743（権限なし）を検出してUI誘導

**インターフェース**:
```swift
final class AppleScriptRunner {
    func run(_ source: String) throws -> String
}

enum AppleScriptError: Error {
    case compileFailed(message: String)
    case executeFailed(code: Int, message: String)
    case notAuthorized  // -1743
}
```

### 2. URLMonitor（新規）

**責務**: ブラウザのアクティブタブURL監視

**設計方針**:
- DispatchSourceTimerでポーリング
- 前面アプリがブラウザの時のみポーリング（30秒間隔）
- それ以外は停止（省電力重視）
- 監視対象はfront window（アクティブウィンドウ）のみ
- leewayを設定して省電力化

**状態管理**:
```
[Idle] ─(ブラウザが前面に)─▶ [Monitoring:30秒]
                                    │
                    (別アプリに切替) │
                                    ▼
                                 [Idle]
```

**インターフェース**:
```swift
@MainActor
final class URLMonitor: ObservableObject {
    @Published var currentURL: URL?
    @Published var currentHost: String?
    
    func start()
    func stop()
}
```

### 3. AppSettings（新規）

**責務**: 設定の永続化

**設計方針**:
- 単純値は@AppStorage
- 配列（ブロックリスト）はCodable→Data→@AppStorage

**インターフェース**:
```swift
@MainActor
final class AppSettings: ObservableObject {
    @AppStorage("volumePercent") var volumePercent: Int = 70
    @AppStorage("gracePeriod") var gracePeriod: Int = 10
    @AppStorage("repeatInterval") var repeatInterval: Int = 15
    
    var blockedDomains: [String]  // getter/setter内でJSON変換
}
```

### 4. 警告ロジック（ActiveAppMonitor拡張）

**状態遷移**:
```
[Safe] ─(ブロックURL検知)─▶ [Grace Period] ─(時間経過)─▶ [Warning]
   ▲                              │                          │
   │                              │                          │
   └──────(別サイト/アプリ)────────┴──────(別サイト/アプリ)────┘
```

**タイマー管理**:
- graceTimer: 猶予時間カウント用
- repeatTimer: 繰り返し警告用

---

## 権限設定

### Info.plist に追加

```xml
<key>NSAppleEventsUsageDescription</key>
<string>Nyaはブラウザのタブを監視して、SNSの見すぎを防ぎます。</string>
```

### Entitlements に追加（必要に応じて）

```xml
<key>com.apple.security.automation.apple-events</key>
<true/>
```

### 権限エラー時のUI対応

エラーコード-1743を検知したら：
1. アラートを表示
2. 「システム設定を開く」ボタンで誘導
3. `NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation")!)`

---

## ポーリング設計

### 間隔の根拠

| 状態 | 間隔 | 理由 |
|------|------|------|
| ブラウザ前面 | 30秒 | 省電力重視、見すぎ防止には十分な精度 |
| その他アプリ前面 | 停止 | ブラウザ以外は監視不要 |
| leeway | 20% | システムにタイマーをまとめさせて省電力 |

### 30秒を選んだ理由

- 省電力・メモリ消費を最小化
- 「ダラダラ見すぎ」防止には40秒後（検知30秒+猶予10秒）の警告で十分
- 1時間あたりの実行回数: 120回（3秒なら1,200回）

---

## エラーハンドリング

| エラー | 原因 | 対応 |
|--------|------|------|
| -1743 | オートメーション権限なし | 設定画面への誘導UIを表示 |
| ウィンドウなし | ブラウザにウィンドウがない | 空文字を返す（AppleScript側で処理） |
| ブラウザ未起動 | ブラウザが起動していない | 空文字を返す（AppleScript側で処理） |
| タブなし | ウィンドウにタブがない | 空文字を返す（AppleScript側で処理） |

---

## テスト観点

### 単体テスト

- [ ] AppleScriptRunner: Chrome/Safari両方でURL取得できる
- [ ] AppleScriptRunner: ブラウザ未起動時に空文字を返す
- [ ] URLMonitor: 前面アプリ切替でポーリング間隔が変わる
- [ ] AppSettings: ブロックリストの保存/読み込み

### 統合テスト

- [ ] ブロックURLを開いて猶予時間後に音が鳴る
- [ ] 別サイトに移動すると鳴り止む
- [ ] 設定変更が即座に反映される

### 手動テスト

- [ ] 初回起動時に権限ダイアログが出る
- [ ] 権限拒否後に誘導UIが表示される
- [ ] メニューバーに現在のホストが表示される

---

## 実装順序

1. **AppleScriptRunner.swift** - 基盤
2. **URLMonitor.swift** - URL取得とポーリング
3. **AppSettings.swift** - 設定永続化
4. **SettingsView.swift** - 設定UI
5. **Info.plist** - 権限設定
6. **ActiveAppMonitor.swift** - 警告ロジック統合
7. **NyaApp.swift** - Settings画面への導線
8. **SoundPlayer.swift** - 音量設定対応

---

## 参考リンク

- [NSAppleScript - Apple Developer](https://developer.apple.com/documentation/foundation/nsapplescript)
- [DispatchSourceTimer - Apple Developer](https://developer.apple.com/documentation/dispatch/dispatchsourcetimer)
- [App Sandbox Entitlements - Apple Developer](https://developer.apple.com/documentation/bundleresources/entitlements)
- [Sandboxing and Automation - Apple QA1888](https://developer.apple.com/library/archive/qa/qa1888/_index.html)
