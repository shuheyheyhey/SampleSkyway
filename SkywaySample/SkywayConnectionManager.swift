//
//  SkywayConnectionManager.swift
//  SkywaySample
//
//  Created by Shuhei Yukawa
//

import Foundation
import SkyWayRoom
import SkyWayCore

public protocol ConferenceConnectionDelegate: AnyObject {
    func didCloseRoom()
    func didReceiveStatusError(error: ConferenceStatusError)
}

public protocol ConferenceStreamDelegate: AnyObject {
    func streamChanged(stream: ConferenceStream)
    func streamAdded(stream: ConferenceStream)
    func streamRemoved(stream: ConferenceStream)
}

public enum ConferenceConnectionError: Error {
    case alreadyConnected
    case nowDisconnecting
    case couldNotPrepareConnection
    case cannotGetLocalMedia
    case connectionError(error: Error)
}

extension ConferenceConnectionError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .alreadyConnected: return "ConferenceConnectionError.alreadyConnected"
        case .nowDisconnecting: return "ConferenceConnectionError.nowDisconnecting"
        case .couldNotPrepareConnection: return "ConferenceConnectionError.couldNotPrepareConnection"
        case .cannotGetLocalMedia: return "ConferenceConnectionError.cannotGetLocalMedia"
        case .connectionError(let error): return "ConferenceConnectionError.connectionError \(error.localizedDescription)"
        }
    }
}

public enum ConferenceStatusError: Error {
    case receiveAudioError(Error)
    case receiveVideoError(Error)
    case removeVideoError(Error)
    case joinMemberError(Error)
}

extension ConferenceStatusError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .receiveAudioError(let error):
            return "ConferenceStatusError.receiveAudioError \(error.localizedDescription)"
        case .receiveVideoError(let error):
            return "ConferenceStatusError.receiveVideoError \(error.localizedDescription)"
        case .removeVideoError(let error):
            return "ConferenceStatusError.removeVideoError \(error.localizedDescription)"
        case .joinMemberError(let error):
            return "ConferenceStatusError.joinMemberError \(error.localizedDescription)"
        }
    }
}

public enum ConferenceMediaError: Error {
    case notFoundOtherCamera
    case noSupportedCameras
}

extension ConferenceMediaError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .noSupportedCameras: return "ConferenceMediaError.noSupportedCameras"
        case .notFoundOtherCamera: return "ConferenceMediaError.notFoundOtherCamera"
        }
    }
}

private extension Error {
    func toSkywayError() -> Error? {
        return SkywayError(error: self)
    }
}

public struct SkywayError {
    public let _nsError: NSError
    public init(_nsError: NSError) {
        precondition(_nsError.domain == Self._nsErrorDomain)
        self._nsError = _nsError
    }

    // swiftlint:disable:next force_unwrapping
    public static var _nsErrorDomain: String { return Bundle.main.bundleIdentifier! }
    public typealias Code = SKWErrorCode

    var code: Code {
        // swiftlint:disable:next force_unwrapping
        return Code(rawValue: UInt(bitPattern: self._nsError.code))!
    }
}

extension SkywayError {
    public init?(error: Error) {
        let nsError = error as NSError
        guard nsError.domain == Self._nsErrorDomain else {
            return nil
        }
        self = .init(_nsError: nsError)
    }
}

extension SkywayError: LocalizedError {
    public var errorDescription: String? {
        let message: String = {
            switch self.code {
            case .availableCameraIsMissing:
                return "avaliable camera is missing"
            case .cameraIsNotSet:
                return "camera is not set"
            case .contextSetupError:
                return "context setup error"
            case .channelFindError:
                return "channel find error"
            case .channelCreateError:
                return "channel create error"
            case .channelFindOrCreateError:
                return "channel find or create error"
            case .channelJoinError:
                return "channel join error"
            case .channelLeaveError:
                return "channel leave error"
            case .channelCloseError:
                return "channel close error"
            case .memberUpdateMetadataError:
                return "member update metadata error"
            case .memberLeaveError:
                return "member leave error"
            case .localPersonPublishError:
                return "local person publish error"
            case .localPersonSubscribeError:
                return "local person subscribe error"
            case .localPersonUnpublishError:
                return "local person unpublish error"
            case .localPersonUnsubscribeError:
                return "local person unsubscribe error"
            case .remotePersonSubscribeError:
                return "remote person subscribe error"
            case .remotePersonUnsubscribeError:
                return "remote person unsubscribe error"
            case .publicationUpdateMetadataError:
                return "publication update metadata error"
            case .publicationCancelError:
                return "publication cancel error"
            case .publicationEnableError:
                return "publication enable error"
            case .publicationDisableError:
                return "publication disable error"
            case .subscriptionCancelError:
                return "subscription cancel error"
            case .contextDisposeError:
                return "context dispose error"
            case .fatalErrorRAPIReconnectFailed:
                return "fatal error RAPI reconnect failed"
            @unknown default:
                return "unknown error"
            }
        }()
        return "\(message): [\(self.code.rawValue)]"
    }
}

public struct InitialCallSettings {
    public let isMuting: Bool
    public let outputSpeaker: OutputVoiceSpeaker
    public let isOutgoingCall: Bool

    public init(isMuting: Bool, outputSpeaker: OutputVoiceSpeaker, isOutgoingCall: Bool) {
        self.isMuting = isMuting
        self.outputSpeaker = outputSpeaker
        self.isOutgoingCall = isOutgoingCall
    }
}

actor SkywayConnections {
    private(set) var room: SkyWayRoom.Room?
    private(set) var me: SkyWayRoom.LocalRoomMember?

    func setRoomAndMe(room: SkyWayRoom.Room?, me: SkyWayRoom.LocalRoomMember?) {
        self.room = room
        self.me = me
    }

    func setToNilIfNeeded() -> (room: SkyWayRoom.Room, me: SkyWayRoom.LocalRoomMember)? {
        guard let room = self.room,
              let me = self.me else {
            return nil
        }
        self.room?.delegate = nil
        self.room = nil
        self.me = nil
        return (room, me)
    }

    var isConnected: Bool {
        return self.room != nil || self.me != nil
    }
}

actor ConferenceSettingsStatus {
    private(set) var isMuted: Bool = false
    private(set) var outputVoiceSpeaker: OutputVoiceSpeaker = .telephoneSpeaker

    func setIsMuted(_ isMuted: Bool) {
        self.isMuted = isMuted
    }

    func setOutputVoiceSpeaker(_ speaker: OutputVoiceSpeaker) {
        self.outputVoiceSpeaker = speaker
    }

    func switchMuted() {
        self.isMuted = !self.isMuted
    }
}

final class SkywayConnectionManager {
    private static let token = ""
    private static let userName = "Test"
    
    
    public weak var delegate: ConferenceConnectionDelegate?
    public weak var streamDelegate: ConferenceStreamDelegate?
    
    private let skywayConnections = SkywayConnections()
    private let conferenceSettingsStatus = ConferenceSettingsStatus()
    
    private let streamManager = SkywayStreamManager()
    
    public var streams: [ConferenceStream] {
        get async { await self.streamManager.streams.allStreams }
    }
    
    public var localStram: ConferenceStream? {
        get async { await self.streamManager.streams.localStream }
    }
    
    public var isMute: Bool {
        get async { await self.conferenceSettingsStatus.isMuted }
    }
    
    public var hasShareVideo: Bool {
        get async { await self.localStram?.remoteVideoStream != nil }
    }
    
    public func connect(roomType: RoomType,
                        roomName: String,
                        settings: InitialCallSettings) async throws {
        do {
            if await self.skywayConnections.isConnected {
                throw ConferenceConnectionError.alreadyConnected
            }
            // Room への参加
            _ = try await self.joinRoom(roomName: roomName,
                                        roomType: roomType)
            // 自身のストリーム管理
            try await self.setupLocalStream(settings: settings)

            // すでに参加済みの他人のストリーム追加
            if let members = await self.skywayConnections.room?.members {
                try await self.streamManager.manageAlreadyParticipants(members)
                // すでに共有されているストリームをサブスクライブ
                try await self.subscribeAlreadyParticipatedMembers(members: members)
            }

            // スピーカー、ミュート設定
            await self.conferenceSettingsStatus.setIsMuted(settings.isMuting)
            await self.switchOutputAudio(type: settings.outputSpeaker)
        } catch let error {
            // ここでエラーが起きた場合も接続エラーを伝える
            try? await self.disconnect()
            
            guard let skywayError = error.toSkywayError() else {
                throw error
            }
            
            throw skywayError
        }
    }
    public func disconnect() async throws {
        guard let connectedObject = await self.skywayConnections.setToNilIfNeeded() else {
            throw ConferenceConnectionError.nowDisconnecting
        }

        // ここで問題が起きても無視して処理を継続させてコンテキストを終了させる
        try? await connectedObject.me.leave()
        try? await connectedObject.room.dispose()

        // カメラのキャプチャ停止
        CameraVideoSource.shared().stopCapturing()

        // Skyway 停止
        try await Context.dispose()
    }

    public func switchMute() async throws {
        // すでに接続済なら mute に変更
        if !(await self.skywayConnections.isConnected) {
            return
        }

        let newSettingMute = !(await self.conferenceSettingsStatus.isMuted)
        guard let me = await self.skywayConnections.me else { return }
        guard let result = try await self.streamManager.updateMute(isMute: newSettingMute, me: me) else {
            return
        }
        await self.conferenceSettingsStatus.switchMuted()
        
        self.streamDelegate?.streamChanged(stream: result)
    }

    public func switchOutputAudio(type: OutputVoiceSpeaker?) async {
        // すでに接続済なら mute に変更
        if !(await self.skywayConnections.isConnected) {
            return
        }

        // https://lisb.myjetbrains.com/youtrack/issue/albero-7734
        // 指定があれば指定通り、なければスイッチする。この対応は発着信の時に実際のモデル変更ができないためである
        let newType: OutputVoiceSpeaker
        if let type = type {
            newType = type
        } else {
            newType = await self.conferenceSettingsStatus.outputVoiceSpeaker == .speaker ? .telephoneSpeaker : .speaker
        }

        await self.conferenceSettingsStatus.setOutputVoiceSpeaker(newType)
        await MainActor.run {
            SpeakerController().setSpeaker(type: newType)
        }
    }

    public func getOutputVoiceSpeaker() async -> OutputVoiceSpeaker {
        return await self.conferenceSettingsStatus.outputVoiceSpeaker
    }
    
    public func switchShareVideo() async throws {
        guard let me = await self.skywayConnections.me,
              let stream = try await self.streamManager.updateCameraCapture(me: me) else { return }
        self.streamDelegate?.streamChanged(stream: stream)
    }

    public func switchCamera() async throws {
        // front or back
        let currentDevice = CameraVideoSource.shared().camera
        var newDevice: AVCaptureDevice?
        if currentDevice?.position == .front {
            newDevice = CameraVideoSource.supportedCameras().first { $0.position == .back }
        } else if currentDevice?.position == .back {
            newDevice = CameraVideoSource.supportedCameras().first { $0.position == .front }
        }

        guard let newDevice = newDevice else {
            throw ConferenceMediaError.notFoundOtherCamera
        }
        try await CameraVideoSource.shared().change(newDevice)

        // デバイスの切り替わりの完了を通知 to VideoView
//        await MainActor.run {
//            NotificationCenter.default.post(name: Notification.Name.ConferenceNotification.changeCameraPosition, object: nil)
//        }
    }
}

// Room参加
extension SkywayConnectionManager {
    private func joinRoom(roomName: String, roomType: RoomType) async throws -> SkyWayRoom.LocalRoomMember {
        let contextOptions = ContextOptions()
        contextOptions.logLevel = .trace
        try await Context.setup(withToken: Self.token, options: contextOptions)

        let roomInit = Room.InitOptions()
        roomInit.name = roomName

        let hasToUseSfu = roomType == .SFU
        let room: SkyWayRoom.Room = try await {
            if hasToUseSfu {
                return try await SkyWayRoom.SFURoom.findOrCreate(with: roomInit)
            }

            return try await SkyWayRoom.P2PRoom.findOrCreate(with: roomInit)
        }()

        room.delegate = self

        // Memo: メタデータのやり取りの確認のため、あえて memberInit.name は利用しない

        let metadata = SkywayRoomMemberMetaData(userName: Self.userName)
        let data = try JSONEncoder().encode(metadata)
        let json = String(data: data, encoding: .utf8)
        let memberInit = Room.MemberInitOptions()
        memberInit.metadata = json

        let me = try await room.join(with: memberInit)
        await self.skywayConnections.setRoomAndMe(room: room, me: me)

        return me
    }

    private func setupLocalStream(settings: InitialCallSettings) async throws {
        // Join 後、await によってコンテキストスイッチが切り替わっている間に disconnect されることを考慮して毎回 me を参照する
        guard let meObject = await self.skywayConnections.me else {
            throw ConferenceConnectionError.couldNotPrepareConnection
        }

        try await self.streamManager.setupLocalStream(me: meObject,
                                                      userName: Self.userName,
                                                      isMute: settings.isMuting)
    }

    /// 接続時にすでに参加しているメンバーのSubscribeを行う
    ///
    private func subscribeAlreadyParticipatedMembers(members: [RoomMember]) async throws {
        for member in members {
            // 自分(ローカルの追加)は無視
            if member is LocalRoomMember { continue }

            for publication in member.publications {
                try await self.subscribeMember(member: member, publication: publication)
            }
        }
    }

    private func subscribeMember(member: RoomMember, publication: RoomPublication, beforeRetryError: Error? = nil) async throws {
        // Join 後、サスペンションポイントで処理が切り替わって、delegate 経由で disconnect されることを考慮して毎回 me を参照する
        guard let meObject = await self.skywayConnections.me else {
            throw ConferenceConnectionError.couldNotPrepareConnection
        }

        do {
            switch publication.contentType {
            case .video:
                // ビデオの場合はサブスクライブしたストリームを保持させる
                guard let result = try await self.streamManager.addVideoForRemote(id: member.id, me: meObject, publication: publication) else {
                    return
                }
                self.streamDelegate?.streamChanged(stream: result)
            default:
                _ = try await self.streamManager.subscribe(me: meObject, publication: publication)
            }
        } catch let error {
            // エラーでリトライされている場合で再度失敗したパターン
            if let beforeRetryError = beforeRetryError {
                // 二度 LocalPersonSubscribeError の場合はエラーを無視し、この publication への処理をスキップ
                // LocalPersonSubscribeError は同じ Publication を二度 Subscribe した場合にも発生する
                // 接続時に delegate 経由で Subscribe することもあり、このエラーが二度連続で起きた場合は多重 Subscribe として処理する
                if let formerError = SkywayError(error: beforeRetryError),
                   let laterError = SkywayError(error: error),
                   formerError.code == SKWErrorCode.localPersonSubscribeError,
                   laterError.code == SKWErrorCode.localPersonSubscribeError {
                    return
                }

                throw error
            }
            try await self.subscribeMember(member: member, publication: publication, beforeRetryError: error)
        }
    }
}

extension SkywayConnectionManager: SkyWayRoom.RoomDelegate {
    public func roomDidClose(_ room: Room) {
        // ルームが閉じられた際、終了ステータスに更新
        // 終了処理はステータス更新 delegate を受け取った側で行う
        self.delegate?.didCloseRoom()
    }

    public func room(_ room: SkyWayRoom.Room, publicationDidChangeToEnabled publication: RoomPublication) {
        if publication.publisher is LocalRoomMember { return }
        guard let id = publication.publisher?.id else { return }

        if publication.contentType == .audio {
            Task {
                guard let result = await self.streamManager.updateMuteForRemote(id: id, publication: publication) else { return }
                self.streamDelegate?.streamChanged(stream: result)
            }
        }
    }

    public func room(_ room: SkyWayRoom.Room, publicationDidChangeToDisabled publication: RoomPublication) {
        if publication.publisher is LocalRoomMember { return }
        guard let id = publication.publisher?.id else { return }

        if publication.contentType == .audio {
            Task {
                guard let result = await self.streamManager.updateMuteForRemote(id: id, publication: publication) else { return }
                self.streamDelegate?.streamChanged(stream: result)
            }
        }
    }

    public func room(_ room: SkyWayRoom.Room, memberDidJoin member: RoomMember) {
        Task {
            do {
                guard let result = try await self.streamManager.joinMember(member) else { return }
                self.streamDelegate?.streamAdded(stream: result)
            } catch let error {
                self.delegate?.didReceiveStatusError(error: .joinMemberError(error.toSkywayError() ?? error))
            }
        }
    }

    public func room(_ room: SkyWayRoom.Room, memberDidLeave member: RoomMember) {
        if member is LocalRoomMember { return }

        Task {
            guard let result = await self.streamManager.leaveMember(id: member.id) else { return }
            self.streamDelegate?.streamRemoved(stream: result)
        }
    }

    public func room(_ room: SkyWayRoom.Room, didPublishStreamOf publication: RoomPublication) {
        guard let id = publication.publisher?.id else { return }
        if publication.publisher is LocalRoomMember { return }
        // 新規のパブリッシュ
        Task {
            guard let me = await self.skywayConnections.me else { return }

            if publication.contentType == .audio {
                do {
                    guard let result = await self.streamManager.updateMuteForRemote(id: id, publication: publication) else { return }
                    _ = try await self.streamManager.subscribe(me: me, publication: publication)
                    self.streamDelegate?.streamChanged(stream: result)
                } catch let error {
                    self.delegate?.didReceiveStatusError(error: .receiveAudioError(error.toSkywayError() ?? error))
                }
            }

            if publication.contentType == .video {
                do {
                    guard let result = try await self.streamManager.addVideoForRemote(id: id, me: me, publication: publication) else { return }
                    self.streamDelegate?.streamChanged(stream: result)
                } catch let error {
                    self.delegate?.didReceiveStatusError(error: .receiveVideoError(error.toSkywayError() ?? error))
                }
            }
        }
    }

    public func room(_ room: Room, didUnpublishStreamOf publication: RoomPublication) {
        guard let id = publication.publisher?.id else { return }
        if publication.publisher is LocalRoomMember { return }
        // 新規のパブリッシュ
        Task {
            guard let me = await self.skywayConnections.me else { return }

            if publication.contentType == .video {
                do {
                    guard let result = try await self.streamManager.removeVideoPublishedDateForRemote(id: id, me: me, publication: publication) else {
                        return
                    }
                    self.streamDelegate?.streamChanged(stream: result)
                } catch let error {
                    self.delegate?.didReceiveStatusError(error: .removeVideoError(error.toSkywayError() ?? error))
                }
            }
        }
    }
}
