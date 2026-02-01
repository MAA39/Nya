# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Nya（"Nab Your Attention"）は「猫が監視している」集中支援macOSメニューバーアプリ。スクリーンタイムが増えたりSNS（Twitter, Instagram等）を見ると猫が鳴いて注意する。

- **ターゲット**: macOS 13.0+ (Ventura)
- **フレームワーク**: SwiftUI + MenuBarExtra
- **コンセプト**: KIKIのような「怖かわ」accountability monster

## Build Commands

```bash
# Build the project
xcodebuild -scheme Nya -configuration Debug build

# Build for release
xcodebuild -scheme Nya -configuration Release build

# Run unit tests
xcodebuild -scheme Nya -configuration Debug test

# Run a specific test
xcodebuild -scheme Nya -configuration Debug -only-testing:NyaTests/NyaTests/testName test

# Clean build
xcodebuild -scheme Nya clean

# Launch app (after build)
open ~/Library/Developer/Xcode/DerivedData/Nya-*/Build/Products/Debug/Nya.app
```

## Architecture

- **App Entry Point**: `Nya/NyaApp.swift` - MenuBarExtra Scene（メニューバー常駐）
- **App Monitor**: `Nya/ActiveAppMonitor.swift` - NSWorkspace購読でアクティブアプリ監視
- **Unit Tests**: `NyaTests/NyaTests.swift` - Swift Testing framework (`@Test`)
- **UI Tests**: `NyaUITests/` - XCTest framework

## Key Configuration

- **Bundle ID**: `com.masakazu.Nya`
- **LSUIElement**: `YES` (Dockに出ない、メニューバーのみ)
- **Sandbox**: Enabled with hardened runtime
- **Swift Concurrency**: Uses `@MainActor` as default actor isolation

## 技術メモ

### アクティブアプリ監視
```swift
// 重要: NotificationCenter.default ではなく NSWorkspace.shared.notificationCenter を使う
NSWorkspace.shared.notificationCenter
    .publisher(for: NSWorkspace.didActivateApplicationNotification)
```

### よくある罠
1. NSWorkspace通知が届かない → `NSWorkspace.shared.notificationCenter` を使う
2. Combine購読が即解放 → `@StateObject` か App のプロパティで保持
3. 音ファイルがBundle入らない → Target Membership確認

## 進捗報告ドキュメント

作業完了時は `docs/` ディレクトリに進捗報告を保存すること。

### ファイル命名規則
```
docs/YYYYMMDDHHMMSS-XXXX.md
```
- `YYYYMMDDHHMMSS`: 作業完了時のタイムスタンプ
- `XXXX`: 作業内容を表す短い識別子（例: `phase1-menubar-setup`, `fix-audio-playback`）

### 記載内容
1. **実行日時**
2. **受けた指示**: 何を依頼されたか
3. **実装内容**: 具体的に何をしたか（コード抜粋含む）
4. **変更ファイル一覧**: ファイル名、変更種別、内容
5. **ビルド結果**
6. **完了状況**: チェックリスト形式
7. **次のステップ**: 残タスク

## 開発フェーズ

### Phase 1: 最小構成 ✅
- [x] MenuBarExtraが表示される
- [x] Quitボタンで終了できる
- [x] アクティブアプリ名をログ出力

### Phase 2: 監視機能 ✅
- [x] 禁止アプリ検知
- [x] 検知したら猫が鳴く（音声再生）
- [x] 検知回数カウント

### Phase 3: UI強化
- [ ] 猫のアイコン/アニメーション
- [ ] 設定画面（禁止アプリ編集）
- [ ] 統計表示
