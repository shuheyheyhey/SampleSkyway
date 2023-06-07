//
//  SpeakerController.swift
//
//  Created by Shuhei Yukawa
//

import Foundation
import AVKit

public enum OutputVoiceSpeaker {
    case speaker
    case telephoneSpeaker
}

public class SpeakerController {
    private let audioSession = AVAudioSession.sharedInstance()

    public init() {}

    /// 音声出力先の変更
    ///
    /// - Parameters:
    ///   - type: 出力先
    public func setSpeaker(type: OutputVoiceSpeaker) {
        switch type {
        case .telephoneSpeaker:
            self.setForIphoneSpeaker()
        case .speaker:
            self.setForSpeaker()
        }
    }

    /// 現在の音声出力先の取得
    ///
    public func currentSpeakerSetting() -> OutputVoiceSpeaker {
        let session = AVAudioSession.sharedInstance()
        guard let output = session.currentRoute.outputs.first else {
            return .telephoneSpeaker
        }
        return output.portType == .builtInSpeaker ? .speaker : .telephoneSpeaker
    }

    private func setForIphoneSpeaker() {
        do {
            let port = AVAudioSession.PortOverride.none
            try self.audioSession.overrideOutputAudioPort(port)
        } catch {
            print("Unable to set up the audio setForIphoneSpeaker")
        }
    }

    private func setForSpeaker() {
        do {
            let port = AVAudioSession.PortOverride.speaker
            try self.audioSession.overrideOutputAudioPort(port)
        } catch {
            print("Unable to set up the audio setForSpeaker")
        }
    }
}

