//
//  StickFigureView.swift
//  NyaSquat
//
//  棒人間描画（Vision骨格 or プリセットアニメーション）
//

import SwiftUI
import Vision

struct StickFigureView: View {
    let points: [VNHumanBodyPoseObservation.JointName: VNRecognizedPoint]
    let isCamera: Bool
    let manualDepth: Double  // 0=standing, 1=squatting (manual mode)

    private let jointColor = Color.cyan
    private let boneColor = Color.cyan.opacity(0.8)
    private let headRadius: CGFloat = 14

    // Bone connections
    private let bones: [(VNHumanBodyPoseObservation.JointName, VNHumanBodyPoseObservation.JointName)] = [
        // Torso
        (.nose, .neck),
        (.neck, .leftShoulder), (.neck, .rightShoulder),
        (.leftShoulder, .rightShoulder),
        (.leftShoulder, .leftHip), (.rightShoulder, .rightHip),
        (.leftHip, .rightHip),
        // Arms (crossed)
        (.leftShoulder, .leftElbow), (.leftElbow, .leftWrist),
        (.rightShoulder, .rightElbow), (.rightElbow, .rightWrist),
        // Legs
        (.leftHip, .leftKnee), (.leftKnee, .leftAnkle),
        (.rightHip, .rightKnee), (.rightKnee, .rightAnkle),
    ]

    var body: some View {
        Canvas { context, size in
            let w = size.width
            let h = size.height

            if isCamera && !points.isEmpty {
                drawCameraMode(context: context, size: size)
            } else {
                drawManualMode(context: context, size: size)
            }
        }
        .frame(width: 280, height: 300)
    }

    // MARK: - Camera Mode (real bones)
    private func drawCameraMode(context: GraphicsContext, size: CGSize) {
        let w = size.width
        let h = size.height

        func screenPoint(_ joint: VNHumanBodyPoseObservation.JointName) -> CGPoint? {
            guard let p = points[joint], p.confidence > 0.3 else { return nil }
            // Vision座標(0-1, Y up) → Screen座標
            return CGPoint(x: (1 - p.location.x) * w, y: (1 - p.location.y) * h)
        }

        // Draw bones
        for (j1, j2) in bones {
            guard let p1 = screenPoint(j1), let p2 = screenPoint(j2) else { continue }
            var path = Path()
            path.move(to: p1)
            path.addLine(to: p2)
            context.stroke(path, with: .color(boneColor), lineWidth: 3)
        }

        // Draw joints
        for (name, point) in points where point.confidence > 0.3 {
            let sp = CGPoint(x: (1 - point.location.x) * w, y: (1 - point.location.y) * h)
            let r: CGFloat = name == .nose ? headRadius : 5
            if name == .nose {
                context.stroke(Circle().path(in: CGRect(x: sp.x - r, y: sp.y - r, width: r*2, height: r*2)),
                              with: .color(jointColor), lineWidth: 2.5)
            } else {
                context.fill(Circle().path(in: CGRect(x: sp.x - r, y: sp.y - r, width: r*2, height: r*2)),
                            with: .color(jointColor))
            }
        }
    }

    // MARK: - Manual Mode (preset animation)
    private func drawManualMode(context: GraphicsContext, size: CGSize) {
        let cx = size.width / 2
        let d = manualDepth

        func lerp(_ a: CGFloat, _ b: CGFloat) -> CGFloat { a + (b - a) * d }

        // Preset positions
        let head   = CGPoint(x: cx, y: lerp(45, 80))
        let neck   = CGPoint(x: cx, y: lerp(68, 103))
        let lSh    = CGPoint(x: cx - 30, y: lerp(80, 115))
        let rSh    = CGPoint(x: cx + 30, y: lerp(80, 115))
        // Arms crossed
        let lElb   = CGPoint(x: cx - 12, y: lerp(108, 138))
        let rElb   = CGPoint(x: cx + 12, y: lerp(108, 138))
        let lWr    = CGPoint(x: cx + 14, y: lerp(100, 130))
        let rWr    = CGPoint(x: cx - 14, y: lerp(100, 130))
        // Lower body
        let lHip   = CGPoint(x: cx - 18, y: lerp(148, 175))
        let rHip   = CGPoint(x: cx + 18, y: lerp(148, 175))
        let lKnee  = CGPoint(x: cx - (20 + d * 16), y: lerp(200, 198))
        let rKnee  = CGPoint(x: cx + (20 + d * 16), y: lerp(200, 198))
        let lAnk   = CGPoint(x: cx - (18 + d * 6), y: lerp(258, 258))
        let rAnk   = CGPoint(x: cx + (18 + d * 6), y: lerp(258, 258))

        let manualBones: [(CGPoint, CGPoint)] = [
            (head, neck),
            (neck, lSh), (neck, rSh), (lSh, rSh),
            (lSh, lElb), (lElb, lWr),
            (rSh, rElb), (rElb, rWr),
            (lSh, lHip), (rSh, rHip), (lHip, rHip),
            (lHip, lKnee), (lKnee, lAnk),
            (rHip, rKnee), (rKnee, rAnk),
        ]

        // Bones
        for (p1, p2) in manualBones {
            var path = Path()
            path.move(to: p1)
            path.addLine(to: p2)
            context.stroke(path, with: .color(boneColor), lineWidth: 3)
        }

        // Joints
        let allPts: [(CGPoint, Bool)] = [
            (head, true), (neck, false), (lSh, false), (rSh, false),
            (lElb, false), (rElb, false), (lWr, false), (rWr, false),
            (lHip, false), (rHip, false),
            (lKnee, false), (rKnee, false), (lAnk, false), (rAnk, false),
        ]
        for (pt, isHead) in allPts {
            let r: CGFloat = isHead ? headRadius : 5
            let rect = CGRect(x: pt.x - r, y: pt.y - r, width: r*2, height: r*2)
            if isHead {
                context.stroke(Circle().path(in: rect), with: .color(jointColor), lineWidth: 2.5)
            } else {
                context.fill(Circle().path(in: rect), with: .color(jointColor))
            }
        }
    }
}
