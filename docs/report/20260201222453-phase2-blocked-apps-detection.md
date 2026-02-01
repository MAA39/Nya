# Phase 2: 禁止アプリ検知 + 猫鳴き

## 実行日時
2026-02-01 22:24

## 受けた指示

Phase 2の実装：
1. 禁止アプリリスト定義（Twitter, X, Instagram, Facebook, YouTube, TikTok, Reddit）
2. SoundPlayer.swift作成（まずはシステムサウンドでテスト）
3. ActiveAppMonitorを拡張（禁止アプリ検知、猫鳴き、検知回数カウント）
4. メニューに検知回数表示

## 実装内容

### 1. SoundPlayer.swift 新規作成

```swift
@MainActor
final class SoundPlayer {
    static let shared = SoundPlayer()
    private var audioPlayer: AVAudioPlayer?

    func playMeow() {
        // カスタム音声ファイルを試す → なければシステムビープ
        if let url = Bundle.main.url(forResource: "meow", withExtension: "mp3") {
            audioPlayer = try? AVAudioPlayer(contentsOf: url)
            audioPlayer?.play()
            return
        }
        NSSound.beep()
    }
}
```

### 2. ActiveAppMonitor.swift 拡張

禁止アプリリストと検知ロジックを追加：

```swift
@MainActor
final class ActiveAppMonitor: ObservableObject {
    @Published var currentAppName: String?
    @Published var distractionCount: Int = 0

    let blockedApps: Set<String> = [
        "Twitter", "X", "Instagram", "Facebook",
        "YouTube", "TikTok", "Reddit"
    ]

    // アプリ切り替え時に禁止アプリかチェック
    if self.isBlocked(appName: appName) {
        self.handleDistraction(appName: appName)
    }

    private func handleDistraction(appName: String) {
        distractionCount += 1
        SoundPlayer.shared.playMeow()
    }
}
```

### 3. NyaApp.swift 更新

検知回数表示を追加：

```swift
Text("Today: \(monitor.distractionCount) distractions")
    .foregroundColor(monitor.distractionCount > 0 ? .red : .secondary)
```

## 変更ファイル一覧

| ファイル | 変更種別 | 内容 |
|---------|---------|------|
| `Nya/SoundPlayer.swift` | 新規 | 音声再生クラス（システムビープ + 将来のmp3対応） |
| `Nya/ActiveAppMonitor.swift` | 修正 | 禁止アプリリスト、検知ロジック、カウント追加 |
| `Nya/NyaApp.swift` | 修正 | 検知回数表示追加 |

## ビルド結果

```
** BUILD SUCCEEDED **
```

## Phase 2 完了状況

- [x] 禁止アプリリスト定義
- [x] SoundPlayer.swift作成（システムビープ）
- [x] 禁止アプリ検知ロジック
- [x] 検知時に音が鳴る
- [x] 検知回数カウント
- [x] メニューに検知回数表示

## 動作確認方法

1. メニューバーの猫アイコンをクリック
2. 「Today: 0 distractions」と表示
3. Twitter/YouTube/Instagram等を開く
4. ビープ音が鳴り、カウントが増える

## 次のステップ（Phase 3）

- [ ] 猫の鳴き声mp3を追加
- [ ] 猫のアイコン/アニメーション
- [ ] 設定画面（禁止アプリ編集）
- [ ] 統計表示
