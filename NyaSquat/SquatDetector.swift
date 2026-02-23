//
//  SquatDetector.swift
//  NyaSquat
//
//  カメラ → Vision骨格検出 → スクワット判定
//  FIX: actor isolation問題を修正 - poseRequestをcaptureOutput内でローカル生成
//  FIX: captureSessionを公開してプレビューレイヤーに渡せるように
//

import AVFoundation
import Vision
import SwiftUI
import Combine

enum SquatPhase {
    case standing
    case squatting
}

@MainActor
final class SquatDetector: NSObject, ObservableObject {
    @Published var bodyPoints: [VNHumanBodyPoseObservation.JointName: VNRecognizedPoint] = [:]
    @Published var kneeAngle: Double = 180
    @Published var phase: SquatPhase = .standing
    @Published var isCameraAvailable: Bool = false
    @Published var isPersonDetected: Bool = false

    var onSquatCompleted: (() -> Void)?

    // カメラセッション（プレビュー用に公開）
    private(set) var captureSession: AVCaptureSession?

    // EMA smoothing
    private var smoothedAngle: Double = 180
    private let smoothingFactor: Double = 0.3

    // Cooldown
    private var lastCountTime: Date = .distantPast
    private let cooldownInterval: TimeInterval = 0.5

    // Thresholds
    private let standingThreshold: Double = 160
    private let squattingThreshold: Double = 100

    func startCamera() {
        let session = AVCaptureSession()
        session.sessionPreset = .medium

        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .unspecified),
              let input = try? AVCaptureDeviceInput(device: device) else {
            print("🐱 [SquatDetector] カメラデバイス取得失敗")
            isCameraAvailable = false
            return
        }

        guard session.canAddInput(input) else {
            print("🐱 [SquatDetector] カメラ入力追加失敗")
            isCameraAvailable = false
            return
        }
        session.addInput(input)

        let output = AVCaptureVideoDataOutput()
        output.setSampleBufferDelegate(self, queue: DispatchQueue(label: "squat.camera"))
        output.alwaysDiscardsLateVideoFrames = true

        guard session.canAddOutput(output) else {
            print("🐱 [SquatDetector] ビデオ出力追加失敗")
            isCameraAvailable = false
            return
        }
        session.addOutput(output)

        captureSession = session
        isCameraAvailable = true
        print("🐱 [SquatDetector] カメラセッション構成完了、起動中...")

        DispatchQueue.global(qos: .userInitiated).async {
            session.startRunning()
            print("🐱 [SquatDetector] カメラセッション startRunning 完了")
        }
    }

    func stopCamera() {
        captureSession?.stopRunning()
        captureSession = nil
        isCameraAvailable = false
        print("🐱 [SquatDetector] カメラ停止")
    }

    private func processObservation(_ observation: VNHumanBodyPoseObservation) {
        guard let joints = try? observation.recognizedPoints(.all) else { return }

        let (leftAngle, rightAngle) = AngleCalculator.kneeAngles(from: observation)

        let rawAngle: Double
        switch (leftAngle, rightAngle) {
        case let (l?, r?): rawAngle = (l + r) / 2
        case let (l?, nil): rawAngle = l
        case let (nil, r?): rawAngle = r
        case (nil, nil): return
        }

        // EMA smoothing
        smoothedAngle = smoothedAngle * (1 - smoothingFactor) + rawAngle * smoothingFactor

        self.bodyPoints = joints
        self.kneeAngle = self.smoothedAngle
        self.isPersonDetected = true
        self.updatePhase()
    }

    private func updatePhase() {
        let angle = smoothedAngle

        switch phase {
        case .standing:
            if angle < squattingThreshold {
                phase = .squatting
            }
        case .squatting:
            if angle > standingThreshold {
                let now = Date()
                if now.timeIntervalSince(lastCountTime) > cooldownInterval {
                    lastCountTime = now
                    phase = .standing
                    onSquatCompleted?()
                } else {
                    phase = .standing
                }
            }
        }
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate
// FIX: poseRequestをcaptureOutput内でローカル生成して actor isolation 問題を回避
extension SquatDetector: AVCaptureVideoDataOutputSampleBufferDelegate {
    nonisolated func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        // ローカルでリクエスト生成（MainActorプロパティへのアクセスを回避）
        let request = VNDetectHumanBodyPoseRequest()
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])

        do {
            try handler.perform([request])
        } catch {
            print("🐱 [SquatDetector] Vision perform失敗: \(error)")
            return
        }

        guard let observation = request.results?.first else {
            Task { @MainActor in
                self.isPersonDetected = false
            }
            return
        }

        Task { @MainActor in
            self.processObservation(observation)
        }
    }
}
