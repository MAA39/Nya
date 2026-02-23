//
//  SquatView.swift
//  NyaSquat
//
//  スクワットウィンドウ
//  FIX 100-18: カメラプレビュー追加
//  FIX 100-20: カメラYes/No選択
//  FIX 100-21: カメラモード時フォールバックUI
//  FIX 100-22: 起動時・完了時に猫鳴き声
//

import SwiftUI

struct SquatView: View {
    @ObservedObject var squatCounter: SquatCounter
    @StateObject private var detector = SquatDetector()
    @State private var manualDepth: Double = 0
    @State private var isManualMode: Bool = false
    @State private var showComplete: Bool = false
    @State private var elapsed: Int = 0
    @State private var timer: Timer?
    // 100-20: モード選択
    @State private var showModeSelection: Bool = true
    // 100-21: カメラモード検出失敗のフォールバック
    @State private var cameraFailSeconds: Int = 0

    var onComplete: () -> Void

    var body: some View {
        ZStack {
            // Background
            LinearGradient(
                colors: [Color(red: 0.07, green: 0.09, blue: 0.15),
                         Color(red: 0.06, green: 0.09, blue: 0.16)],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            if showModeSelection {
                modeSelectionView
            } else if showComplete {
                completeView
            } else {
                activeView
            }
        }
        .frame(minWidth: 420, minHeight: 560)
        .onDisappear { stopSession() }
    }

    // MARK: - Mode Selection (100-20)
    private var modeSelectionView: some View {
        VStack(spacing: 20) {
            Spacer()

            Text("🐱 にゃー！").font(.system(size: 40))
            Text("スクワットの時間だよ！")
                .font(.title2).fontWeight(.bold)

            VStack(spacing: 12) {
                Button(action: {
                    showModeSelection = false
                    isManualMode = false
                    startSession(useCamera: true)
                }) {
                    HStack {
                        Image(systemName: "camera.fill")
                        Text("📷 カメラでスクワット")
                    }
                    .frame(maxWidth: 240)
                    .padding(.vertical, 10)
                }
                .buttonStyle(.bordered)
                .tint(.cyan)

                Button(action: {
                    showModeSelection = false
                    isManualMode = true
                    startSession(useCamera: false)
                }) {
                    HStack {
                        Image(systemName: "keyboard")
                        Text("⌨️ 手動でカウント")
                    }
                    .frame(maxWidth: 240)
                    .padding(.vertical, 10)
                }
                .buttonStyle(.bordered)
                .tint(.secondary)
            }

            Text("カメラで体の動きを検出します\n手動はスペースキーでカウント")
                .font(.caption).foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Spacer()
        }
        .onAppear {
            // 100-22: 起動時に鳴く
            SoundPlayer.shared.playMeow()
        }
    }

    // MARK: - Active View
    private var activeView: some View {
        VStack(spacing: 12) {
            // Header
            HStack {
                HStack(spacing: 4) {
                    Image(systemName: "timer").font(.caption)
                    Text(formatTime(elapsed))
                        .font(.system(.caption, design: .monospaced))
                }
                .padding(.horizontal, 10).padding(.vertical, 5)
                .background(.white.opacity(0.1)).cornerRadius(12)

                Spacer()

                Text(isManualMode ? "⌨️ Manual" : "📷 Camera")
                    .font(.caption).fontWeight(.semibold)
                    .foregroundColor(isManualMode ? .secondary : .cyan)
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(.white.opacity(0.1)).cornerRadius(12)
            }
            .padding(.horizontal, 20).padding(.top, 16)

            Text("🐱 腕を前でクロスしてスクワット！")
                .font(.headline).padding(.top, 4)

            // 100-18: カメラプレビュー + 棒人間オーバーレイ
            ZStack {
                if !isManualMode, let session = detector.captureSession {
                    CameraPreviewView(session: session)
                        .cornerRadius(12)
                        .opacity(0.7)
                }
                StickFigureView(
                    points: detector.bodyPoints,
                    isCamera: !isManualMode,
                    manualDepth: manualDepth
                )
            }
            .frame(width: 280, height: 300)
            .background(Color.black.opacity(0.3))
            .cornerRadius(12)

            // Knee angle
            Text("Knee: \(Int(isManualMode ? (180 - manualDepth * 90) : detector.kneeAngle))°")
                .font(.system(.caption2, design: .monospaced))
                .foregroundColor(.secondary)
                .padding(.horizontal, 10).padding(.vertical, 3)
                .background(.black.opacity(0.3)).cornerRadius(6)

            // Counter ring
            counterRing

            // Manual mode or fallback controls (100-21)
            if isManualMode {
                Text("スペースキー or ボタンでカウント")
                    .font(.caption2).foregroundColor(.white.opacity(0.3))
                manualSquatButton
            } else if !detector.isPersonDetected {
                VStack(spacing: 8) {
                    Text("人が検出されていません…カメラの前に立ってね")
                        .font(.caption).foregroundColor(.orange)
                    // 100-21: 5秒以上検出失敗でフォールバックボタン表示
                    if cameraFailSeconds >= 5 {
                        Button(action: {
                            isManualMode = true
                            detector.stopCamera()
                        }) {
                            Text("⌨️ 手動モードに切替")
                                .font(.caption).fontWeight(.semibold)
                        }
                        .buttonStyle(.bordered).tint(.orange)
                    }
                }
            }

            // カメラモードでもスペースキーは常に有効（隠しボタン）
            if !isManualMode {
                Button(action: doManualSquat) {
                    EmptyView()
                }
                .keyboardShortcut(.space, modifiers: [])
                .frame(width: 0, height: 0).opacity(0)
            }

            Spacer()

            // Skip button
            if SquatSettings.shared.showSkipButton {
                Button("スキップ") {
                    stopSession()
                    onComplete()
                }
                .buttonStyle(.plain).foregroundColor(.secondary)
                .font(.caption).padding(.bottom, 12)
            }
        }
    }

    // MARK: - Counter Ring
    private var counterRing: some View {
        ZStack {
            Circle().stroke(.white.opacity(0.08), lineWidth: 5)
                .frame(width: 96, height: 96)
            Circle()
                .trim(from: 0, to: squatCounter.progress)
                .stroke(.cyan, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .frame(width: 96, height: 96)
                .animation(.easeOut(duration: 0.3), value: squatCounter.progress)
            VStack(spacing: 0) {
                Text("\(squatCounter.currentCount)")
                    .font(.system(size: 32, weight: .heavy, design: .rounded))
                Text("/ \(squatCounter.target)")
                    .font(.caption2).foregroundColor(.secondary)
            }
        }
    }

    // MARK: - Manual Squat Button
    private var manualSquatButton: some View {
        Button(action: doManualSquat) {
            Text("スクワット！（Space）")
                .fontWeight(.semibold)
                .padding(.horizontal, 24).padding(.vertical, 10)
        }
        .buttonStyle(.bordered).tint(.cyan)
        .keyboardShortcut(.space, modifiers: [])
    }

    // MARK: - Complete View
    private var completeView: some View {
        VStack(spacing: 16) {
            Spacer()
            Text("🎉").font(.system(size: 52))
            Text("お疲れ！🐱").font(.title).fontWeight(.heavy)

            HStack(spacing: 32) {
                VStack {
                    Text("\(squatCounter.currentCount)")
                        .font(.system(size: 28, weight: .heavy)).foregroundColor(.cyan)
                    Text("SQUATS").font(.caption2).foregroundColor(.secondary)
                }
                VStack {
                    Text(formatTime(elapsed))
                        .font(.system(size: 28, weight: .heavy)).foregroundColor(.cyan)
                    Text("TIME").font(.caption2).foregroundColor(.secondary)
                }
            }

            Text("今日のトータル: \(squatCounter.todayTotal)回")
                .font(.caption).foregroundColor(.secondary)

            Button("閉じる") { onComplete() }
                .buttonStyle(.bordered).tint(.cyan).padding(.top, 8)

            Spacer()
        }
        .onAppear {
            // 100-22: 完了時にも鳴く
            SoundPlayer.shared.playMeow()
        }
    }

    // MARK: - Session Management
    private func startSession(useCamera: Bool) {
        squatCounter.startSession()
        elapsed = 0
        cameraFailSeconds = 0

        if useCamera {
            detector.startCamera()

            // カメラ起動後に確認
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                if !detector.isCameraAvailable {
                    print("🐱 カメラ利用不可、マニュアルモードに切替")
                    isManualMode = true
                }
            }
        }

        // Wire up squat detection callback
        detector.onSquatCompleted = {
            squatCounter.increment()
            checkComplete()
        }

        // Elapsed timer + camera fail counter
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            Task { @MainActor in
                elapsed += 1
                // 100-21: カメラモードで未検出の時間をカウント
                if !isManualMode && !detector.isPersonDetected {
                    cameraFailSeconds += 1
                } else {
                    cameraFailSeconds = 0
                }
            }
        }
    }

    private func stopSession() {
        detector.stopCamera()
        timer?.invalidate()
        timer = nil
    }

    private func doManualSquat() {
        withAnimation(.easeIn(duration: 0.2)) { manualDepth = 1.0 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            withAnimation(.easeOut(duration: 0.25)) { manualDepth = 0.0 }
        }
        squatCounter.increment()
        checkComplete()
    }

    private func checkComplete() {
        if squatCounter.isComplete {
            stopSession()
            withAnimation { showComplete = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                onComplete()
            }
        }
    }

    private func formatTime(_ s: Int) -> String {
        String(format: "%d:%02d", s / 60, s % 60)
    }
}
