//
//  SquatCounter.swift
//  NyaSquat
//

import SwiftUI
import Combine

@MainActor
final class SquatCounter: ObservableObject {
    @Published var currentCount: Int = 0
    @Published var todayTotal: Int = 0
    @Published var isActive: Bool = false

    var target: Int { SquatSettings.shared.squatTarget }
    var isComplete: Bool { currentCount >= target }
    var progress: Double {
        guard target > 0 else { return 0 }
        return min(Double(currentCount) / Double(target), 1.0)
    }

    func increment() {
        currentCount += 1
        todayTotal += 1
        if SquatSettings.shared.playCatSound {
            SoundPlayer.shared.playMeow()
        }
    }

    func reset() {
        currentCount = 0
        isActive = false
    }

    func startSession() {
        currentCount = 0
        isActive = true
    }
}
