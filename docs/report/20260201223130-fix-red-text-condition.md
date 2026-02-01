# 修正: 禁止アプリ表示中のみ赤字にする

## 実行日時
2026-02-01 22:31

## 受けた指示

現状の問題：`distractionCount > 0`で赤字判定しているため、一度でも禁止アプリを開くとその後ずっと赤字のまま。

修正：現在表示中のアプリが禁止アプリの場合のみ赤字にする。

## 実装内容

### ActiveAppMonitor.swift

`isCurrentlyDistracted`プロパティを追加：

```swift
@Published var isCurrentlyDistracted: Bool = false

// アプリ切り替え時
let isBlocked = self.isBlocked(appName: appName)
self.isCurrentlyDistracted = isBlocked

if isBlocked {
    self.handleDistraction(appName: appName)
}
```

### NyaApp.swift

赤字条件を変更：

```swift
// Before
.foregroundColor(monitor.distractionCount > 0 ? .red : .secondary)

// After
.foregroundColor(monitor.isCurrentlyDistracted ? .red : .secondary)
```

## 変更ファイル一覧

| ファイル | 変更種別 | 内容 |
|---------|---------|------|
| `Nya/ActiveAppMonitor.swift` | 修正 | `isCurrentlyDistracted`プロパティ追加 |
| `Nya/NyaApp.swift` | 修正 | 赤字条件を`isCurrentlyDistracted`に変更 |

## ビルド結果

```
** BUILD SUCCEEDED **
```

## 動作確認

- YouTube開く → 赤字 + カウント増加 + 音
- Xcode開く → 通常色（カウントはそのまま）
- Twitter開く → 赤字 + カウント増加 + 音
