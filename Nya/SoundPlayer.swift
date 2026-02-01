//
//  SoundPlayer.swift
//  Nya
//
//  Created by maa on 2026/02/01.
//

import AppKit
import AVFoundation

@MainActor
final class SoundPlayer {
    static let shared = SoundPlayer()

    private var audioPlayer: AVAudioPlayer?

    private init() {}

    func playMeow() {
        // まずはカスタム音声ファイルを試す
        if let url = Bundle.main.url(forResource: "meow", withExtension: "mp3") {
            do {
                audioPlayer = try AVAudioPlayer(contentsOf: url)
                audioPlayer?.play()
                return
            } catch {
                print("🐱 Failed to play meow.mp3: \(error)")
            }
        }

        // フォールバック: システムサウンド
        NSSound.beep()
        print("🐱 Meow! (system beep)")
    }
}
