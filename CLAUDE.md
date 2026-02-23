# CLAUDE.md - NyaSquat

## Project Overview

NyaSquat = SNS使いすぎ検知 → スクワット強制のmacOSメニューバーアプリ。
Twitter/YouTube等を15分使うとスクワットウィンドウが自動起動、10回やらないと閉じれない。

- **Target**: macOS 14.0+ (Sonoma)
- **Framework**: SwiftUI + MenuBarExtra
- **Detection**: Apple Vision (VNHumanBodyPoseObservation) + カメラ
- **Concept**: 猫が見張ってる accountability app

## Build Commands

```bash
# ビルド
xcodebuild -scheme NyaSquat -configuration Debug build

# クリーンビルド
xcodebuild -scheme NyaSquat clean && xcodebuild -scheme NyaSquat -configuration Debug build

# アプリ起動
open ~/Library/Developer/Xcode/DerivedData/NyaSquat-*/Build/Products/Debug/NyaSquat.app
```

## Architecture

### ファイル構成
```
NyaSquat/
├── NyaSquatApp.swift       # エントリ: MenuBarExtra + Window定義
├── MenuView.swift          # メニューバーUI（SNS時間表示、設定）
├── SquatView.swift         # メインUI: モード選択→カメラ/手動→完了
├── SquatDetector.swift     # カメラ+Vision骨格検出+スクワット判定
├── SquatCounter.swift      # カウンター（セッション/日次）
├── SquatSettings.swift     # 設定（目標回数、トリガー時間等）
├── SNSMonitor.swift        # NSWorkspace/AppleScriptでSNS使用時間計測
├── CameraPreviewView.swift # NSViewRepresentable: カメラ映像プレビュー
├── StickFigureView.swift   # 棒人間アニメーション表示
├── AngleCalculator.swift   # 膝角度計算（Hip-Knee-Ankle 3点）
├── SoundPlayer.swift       # 猫鳴き声再生
└── NyaSquat.entitlements   # カメラ+AppleEvents+Sandbox
```

### フロー
1. SNSMonitor: Twitter/YouTube検知 → 累積タイマー
2. 15分到達 → SquatView自動起動（猫鳴き声）
3. モード選択: カメラ or 手動
4. カメラ: Vision骨格検出で自動カウント / 手動: スペースキー
5. 10回完了 → 完了画面（猫鳴き声） → タイマーリセット

## Key Configuration

- **Bundle ID**: com.masakazu.NyaSquat
- **LSUIElement**: YES (Dockに出ない)
- **Sandbox**: Enabled
- **Entitlements**: camera, apple-events
- **SWIFT_DEFAULT_ACTOR_ISOLATION**: MainActor
- **Xcode project**: objectVersion 77 (PBXFileSystemSynchronizedRootGroup)
  → NyaSquat/フォルダ内のSwiftファイルは自動でビルド対象に含まれる

## 技術メモ

### Actor Isolation (重要)
- `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` が有効
- SquatDetectorの`captureOutput`は`nonisolated`（バックグラウンドキューから呼ばれる）
- **poseRequestはcaptureOutput内でローカル生成**すること（MainActorプロパティにアクセス不可）
- 状態更新は `Task { @MainActor in }` で明示的にメインに戻す

### スクワット検出パラメータ
- Standing: >160°
- Squatting: <100°
- EMA smoothing: 0.3
- Cooldown: 0.5秒
- 3点: Hip-Knee-Ankle角度

### カメラプレビュー
- CameraPreviewView = NSViewRepresentable + AVCaptureVideoPreviewLayer
- 左右反転（鏡像モード）有効
- SquatDetector.captureSessionを共有

### モード選択 & フォールバック
- 起動時にカメラ/手動の選択UI表示
- カメラモードで5秒以上人体未検出 → 手動切替ボタン表示
- カメラモード中もスペースキーは常に有効（隠しボタン）

## Linear管理

プロジェクト: NyaSquat (100days100prd workspace)
- 完了: 100-11, 100-18, 100-19, 100-20, 100-21, 100-22
- 残: 100-12(コードレビュー), 100-13(カメラ検証), 100-14(手動検証), 100-15(SNS監視), 100-16(動画エクスポート), 100-17(このファイル)
