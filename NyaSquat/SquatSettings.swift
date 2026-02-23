//
//  SquatSettings.swift
//  NyaSquat
//

import SwiftUI
import Combine

final class SquatSettings: ObservableObject {
    static let shared = SquatSettings()

    @AppStorage("triggerMinutes") var triggerMinutes: Int = 15
    @AppStorage("squatTarget") var squatTarget: Int = 10
    @AppStorage("showSkipButton") var showSkipButton: Bool = true
    @AppStorage("playCatSound") var playCatSound: Bool = true

    private init() {}
}
