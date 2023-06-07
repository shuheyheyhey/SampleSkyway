//
//  SkywayStreamManager.swift
//  SkywaySample
//
//  Created by Shuhei Yukawa
//

import Foundation
import SkyWayRoom
import SkyWayCore

enum SkywayStreamManagerError: LocalizedError {
    case couldNotFindPublication

    var errorDescription: String? {
        return "Could not find any publications"
    }
}

struct SkywayRoomMemberMetaData: Codable {
    let userName: String
}

struct SkywayVideoPublicationMetaData: Codable {
    let date: String
}

public struct ConferenceStream: Hashable {
    public static func == (lhs: ConferenceStream, rhs: ConferenceStream) -> Bool {
        return lhs.peerId == rhs.peerId &&
        lhs.isMe == rhs.isMe &&
        lhs.isMute == rhs.isMute &&
        lhs.userName == rhs.userName &&
        (lhs.remoteVideoStream == nil) == (rhs.remoteVideoStream == nil)
    }
    
    public let peerId: String
    public let isMe: Bool
    public var isMute: Bool
    public let userName: String
    internal var remoteVideoStream: VideoStreamProtocol?
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(self.peerId)
        hasher.combine(self.isMe)
        hasher.combine(self.isMute)
        hasher.combine(self.userName)
        hasher.combine(self.remoteVideoStream == nil)
    }
    
    static func translate(from member: RoomMember, isMute: Bool, videoPublication: RoomPublication?, decoder: JSONDecoder) throws -> ConferenceStream? {
        guard let userName = try Self.getUserName(from: member, decoder: decoder) else {
            return nil
        }
        
        let conferenceStream = ConferenceStream(peerId: member.id,
                                                isMe: member is LocalRoomMember,
                                                isMute: isMute,
                                                userName: userName)
        return conferenceStream
    }

    private static func getUserName(from member: RoomMember, decoder: JSONDecoder) throws -> String? {
        guard let metadata = member.metadata?.data(using: .utf8) else { return nil }
        let result = try decoder.decode(SkywayRoomMemberMetaData.self, from: metadata)
        return result.userName
    }
}

actor Streams {
    private(set) var localStream: ConferenceStream?
    private(set) var remoteStreams: [ConferenceStream] = []

    var allStreams: [ConferenceStream] {
        var streams = self.remoteStreams
        if let localStream = self.localStream {
            streams += [localStream]
        }
        return streams
    }

    func setLocalStream(_ stream: ConferenceStream) {
        self.localStream = stream
    }

    func updateLocalStream(isMute: Bool) -> ConferenceStream? {
        var stream = self.localStream
        stream?.isMute = isMute
        self.localStream = stream
        return self.localStream
    }

    func updateLocalStream(videoStream: VideoStreamProtocol?) {
        self.localStream?.remoteVideoStream = videoStream
    }

    func appendRemoteStream(_ stream: ConferenceStream) {
        if let alreadyExistedIndex = self.remoteStreams.firstIndex(where: { $0.peerId == stream.peerId }) {
            // すでに存在する場合は削除して上書き
            self.remoteStreams.remove(at: alreadyExistedIndex)
        }
        self.remoteStreams.append(stream)
    }

    func removeRemoteStream(id: String) -> ConferenceStream? {
        var removedStream: ConferenceStream?
        let newStreams = self.remoteStreams.filter { stream in
            if stream.peerId == id {
                removedStream = stream
                return false
            }
            return true
        }
        self.remoteStreams = newStreams
        return removedStream
    }

    func updateRemoteStream(id: String, isMute: Bool) -> ConferenceStream? {
        var updatedStream: ConferenceStream?
        let newStreams = self.remoteStreams.map { stream in
            var stream = stream
            if stream.peerId == id {
                stream.isMute = isMute
                updatedStream = stream
            }
            return stream
        }
        self.remoteStreams = newStreams

        return updatedStream
    }

    func updateRemoteStream(id: String, remoteVideoStream: VideoStreamProtocol?) -> ConferenceStream? {
        var updatedStream: ConferenceStream?
        let newStreams = self.remoteStreams.map { stream in
            var stream = stream
            if stream.peerId == id {
                stream.remoteVideoStream = remoteVideoStream
                updatedStream = stream
            }
            return stream
        }
        self.remoteStreams = newStreams
        return updatedStream
    }
    
    func removeAll() {
        self.localStream = nil
        self.remoteStreams = []
    }
}

final class SkywayStreamManager {
    private static let maxSubscribersCount: Int32 = 99
    internal var streams = Streams()
    internal var streamsCount: Int {
        get async {
            return await self.streams.allStreams.count
        }
    }

    internal func setupLocalStream(me: LocalRoomMember,
                                   userName: String,
                                   isMute: Bool) async throws {
        try await self.publishLocalAudioStream(me: me, isMute: isMute)
        let conferenceStream = ConferenceStream(peerId: me.id,
                                                isMe: true,
                                                isMute: isMute,
                                                userName: userName)
        await self.streams.setLocalStream(conferenceStream)
    }

    internal func manageAlreadyParticipants(_ members: [RoomMember]) async throws {
        let decoder = JSONDecoder()
        for member in members {
            // 自分(ローカルの追加)は無視
            if member is LocalRoomMember { continue }
            let audioPublication = member.publications.first { $0.contentType == .audio }
            let videoPublication = member.publications.first { $0.contentType == .video }
            guard let conferenceStream = try ConferenceStream.translate(from: member,
                                                                        isMute: !(audioPublication?.state == .enabled),
                                                                        videoPublication: videoPublication,
                                                                        decoder: decoder) else {
                continue
            }

            await self.streams.appendRemoteStream(conferenceStream)
        }
    }

    internal func joinMember(_ member: RoomMember) async throws -> ConferenceStream? {
        // 自分(ローカルの追加)は無視
        if member is LocalRoomMember { return nil }

        let decoder = JSONDecoder()
        let audioPublication = member.publications.first { $0.contentType == .audio }
        let videoPublication = member.publications.first { $0.contentType == .video }
        guard let conferenceStream = try ConferenceStream.translate(from: member,
                                                                    isMute: !(audioPublication?.state == .enabled),
                                                                    videoPublication: videoPublication,
                                                                    decoder: decoder) else {
            return nil
        }

        await self.streams.appendRemoteStream(conferenceStream)
        return conferenceStream
    }

    internal func leaveMember(id: String) async -> ConferenceStream? {
        guard let removedStream = await self.streams.removeRemoteStream(id: id) else { return nil }
        return removedStream
    }

    internal func subscribe(me: LocalRoomMember, publication: RoomPublication) async throws -> RoomSubscription? {
        // 自身のパブリッシュはサブスクライブしない
        if publication.publisher is LocalRoomMember { return nil }

        switch publication.contentType {
        case .audio, .video:
            let option = SubscriptionOptions()
            return try await me.subscribe(publicationId: publication.id, options: option)
        default:
            return nil
        }
    }
}

// MARK: オーディオ操作関連
extension SkywayStreamManager {
    private func publishLocalAudioStream(me: SkyWayRoom.LocalRoomMember, isMute: Bool) async throws {
        let audioSource: MicrophoneAudioSource = .init()
        let audioStream = audioSource.createStream()
        let roomPublicationOptions = RoomPublicationOptions()
        roomPublicationOptions.maxSubscribers = Self.maxSubscribersCount
        let publication = try await me.publish(audioStream, options: roomPublicationOptions)
        if isMute {
            try await publication.disable()
        }
    }

    internal func updateMute(isMute: Bool, me: LocalRoomMember) async throws -> ConferenceStream? {
        let publication = me.publications.first { $0.contentType == .audio }
        guard let publication = publication else {
            throw SkywayStreamManagerError.couldNotFindPublication
        }
        if isMute {
            try await publication.disable()
        } else {
            try await publication.enable()
        }
        // 通常ありえない
        guard let result = await self.streams.updateLocalStream(isMute: isMute) else {
            return nil
        }

        return result
    }

    internal func updateMuteForRemote(id: String, publication: RoomPublication?) async -> ConferenceStream? {
        return await self.streams.updateRemoteStream(id: id, isMute: !(publication?.state == .enabled))
    }
}

// MARK: ビデオ操作関連
extension SkywayStreamManager {
    internal func addVideoForRemote(id: String, me: LocalRoomMember, publication: RoomPublication) async throws -> ConferenceStream? {

        guard let stream = try await self.subscribe(me: me, publication: publication)?.stream as? VideoStreamProtocol,
              let result = await self.streams.updateRemoteStream(id: id, remoteVideoStream: stream) else {
            return nil
        }
        return result
    }

    internal func removeVideoPublishedDateForRemote(id: String, me: LocalRoomMember, publication: RoomPublication) async throws -> ConferenceStream? {
        let subscription = me.subscriptions.first { subscription in
            return subscription.publication?.id == publication.id
        }
        try await subscription?.cancel()

        guard let result = await self.streams.updateRemoteStream(id: id, remoteVideoStream: nil) else {
            return nil
        }
        return result
    }

    internal func updateCameraCapture(me: LocalRoomMember) async throws -> ConferenceStream? {
        if try await self.cancelCapturingIfNeeded(me: me) {
            return await self.streams.localStream
        }

        // 存在しない場合は作成してセットアップ
        try await self.createCameraResourceForLocalStream(me: me)
        return await self.streams.localStream
    }

    internal func cancelCapturingIfNeeded(me: LocalRoomMember) async throws -> Bool {
        let publication = me.publications.first { $0.contentType == .video }
        if let publication = publication {
            try await publication.cancel()
            await self.streams.updateLocalStream(videoStream: nil)
            return true
        }
        return false
    }

    private func createCameraResourceForLocalStream(me: LocalRoomMember) async throws {
        // フロントカメラを優先に取得可能なカメラを取得
        let supportedCameras = CameraVideoSource.supportedCameras()
        let camera: AVCaptureDevice? = supportedCameras.first { $0.position == .front } ?? supportedCameras.first { $0.position == .back }

        guard let camera = camera else {
            throw ConferenceMediaError.noSupportedCameras
        }

        try await CameraVideoSource.shared().startCapturing(with: camera, options: nil)
        let stream = CameraVideoSource.shared().createStream()
        let options = RoomPublicationOptions()
        options.maxSubscribers = Self.maxSubscribersCount

        _ = try await me.publish(stream, options: options)
        await self.streams.updateLocalStream(videoStream: stream)
    }
}
