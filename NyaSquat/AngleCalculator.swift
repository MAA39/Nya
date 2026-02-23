//
//  AngleCalculator.swift
//  NyaSquat
//

import Foundation
import Vision

struct AngleCalculator {
    /// 3点から角度を計算（度数法）
    /// vertex が中心（膝）、p1 が hip、p2 が ankle
    static func angle(p1: CGPoint, vertex: CGPoint, p2: CGPoint) -> Double {
        let v1 = CGVector(dx: p1.x - vertex.x, dy: p1.y - vertex.y)
        let v2 = CGVector(dx: p2.x - vertex.x, dy: p2.y - vertex.y)

        let dot = v1.dx * v2.dx + v1.dy * v2.dy
        let cross = v1.dx * v2.dy - v1.dy * v2.dx
        let rad = atan2(cross, dot)
        return abs(rad * 180.0 / .pi)
    }

    /// VNRecognizedPoint → CGPoint 変換
    static func point(from vnPoint: VNRecognizedPoint) -> CGPoint? {
        guard vnPoint.confidence > 0.3 else { return nil }
        return CGPoint(x: vnPoint.location.x, y: vnPoint.location.y)
    }

    /// 左右の膝角度を計算（hip-knee-ankle）
    static func kneeAngles(from observation: VNHumanBodyPoseObservation) -> (left: Double?, right: Double?) {
        let joints = try? observation.recognizedPoints(.all)
        guard let joints else { return (nil, nil) }

        var leftAngle: Double?
        var rightAngle: Double?

        // Left leg
        if let lHip = joints[.leftHip].flatMap({ point(from: $0) }),
           let lKnee = joints[.leftKnee].flatMap({ point(from: $0) }),
           let lAnkle = joints[.leftAnkle].flatMap({ point(from: $0) }) {
            leftAngle = angle(p1: lHip, vertex: lKnee, p2: lAnkle)
        }

        // Right leg
        if let rHip = joints[.rightHip].flatMap({ point(from: $0) }),
           let rKnee = joints[.rightKnee].flatMap({ point(from: $0) }),
           let rAnkle = joints[.rightAnkle].flatMap({ point(from: $0) }) {
            rightAngle = angle(p1: rHip, vertex: rKnee, p2: rAnkle)
        }

        return (leftAngle, rightAngle)
    }
}
