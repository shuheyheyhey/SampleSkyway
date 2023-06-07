//
//  ViewModel.swift
//  SkywaySample
//
//  Created by Shuhei Yukawa
//

import Foundation
import Combine
import SkyWayRoom

enum CallState {
    case connected
    case unconnected
}

enum MuteState: String {
    case mute = "MuteOn"
    case unmute = "MuteOff"
    
    public var iconImage: UIImage? {
        switch self {
        case .mute: return UIImage(systemName: "mic.fill")
        case .unmute: return UIImage(systemName: "mic.slash.fill")
        }
    }
}

enum CameraState: String {
    case on = "CamOn"
    case off = "CamOff"
    
    public var iconImage: UIImage? {
        switch self {
        case .on: return UIImage(systemName: "video.fill")
        case .off: return UIImage(systemName: "video.slash.fill")
        }
    }
}

class ViewModel {
    @Published private(set) var memberList: [ConferenceStream] = []
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var alertMessage: String? = nil
    
    @Published private(set) var callState: CallState = .unconnected
    @Published private(set) var muteState: MuteState = .unmute
    @Published private(set) var cameraState: CameraState = .on
    
    private let skywayConnectionManager = SkywayConnectionManager()
    
    func connect(roomName: String, isP2P: Bool) async throws {
        defer {
            self.isLoading = false
        }
        self.isLoading = true
        self.skywayConnectionManager.delegate = self
        self.skywayConnectionManager.streamDelegate = self
        try await skywayConnectionManager.connect(roomType: isP2P ? .P2P : .SFU, roomName: roomName, settings: InitialCallSettings(isMuting: false, outputSpeaker: .telephoneSpeaker, isOutgoingCall: false))
        
       
        self.callState = .connected
        self.memberList = await self.skywayConnectionManager.streams
    }
    
    func disconnect() async throws {
        defer {
            self.isLoading = false
        }
        self.isLoading = true
        self.skywayConnectionManager.delegate = nil
        self.skywayConnectionManager.streamDelegate = nil
        try await skywayConnectionManager.disconnect()
        
        // 表示の更新
        self.memberList = []
        self.callState = .unconnected
        
    }
}

extension ViewModel {
    func getStream(peerId: String) async -> ConferenceStream? {
        return await self.skywayConnectionManager.streams.first { stream in
            return stream.peerId == peerId
        }
    }
    
    func switchMute() async throws {
        try await self.skywayConnectionManager.switchMute()
        let isMute = await self.skywayConnectionManager.isMute
        self.muteState = !isMute ? .mute : .unmute
    }
    
    func switchSpeaker() async {
        await self.skywayConnectionManager.switchOutputAudio(type: nil)
    }
    
    func switchCamera() async throws {
        try await self.skywayConnectionManager.switchShareVideo()
        let hasShareVideo = await self.skywayConnectionManager.hasShareVideo
        self.cameraState = !hasShareVideo ? .on : .off
    }
    
    func switchCameraPosition() async throws {
        try await self.skywayConnectionManager.switchCamera()
    }
}

extension ViewModel: ConferenceConnectionDelegate {
    func didCloseRoom() {
        Task {
            do {
                try await self.disconnect()
            } catch let error {
                print("[SkywaySample ViewModel.didCloseRoom \(error.localizedDescription)]")
            }
        }
    }
    
    func didReceiveStatusError(error: ConferenceStatusError) {
        self.alertMessage = error.localizedDescription
    }
}

extension ViewModel: ConferenceStreamDelegate {
    func streamChanged(stream: ConferenceStream) {
        let index = self.memberList.firstIndex { item in
            return item.peerId == stream.peerId
        }
        
        guard let index = index else { return }
        self.memberList[index] = stream
    }
    
    func streamAdded(stream: ConferenceStream) {
        self.memberList.append(stream)
        
    }
    
    func streamRemoved(stream: ConferenceStream) {
        self.memberList.removeAll { item in
            return item.peerId == stream.peerId
        }
    }
}
