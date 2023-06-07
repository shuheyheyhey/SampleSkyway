//
//  SkywayVideoView.swift
//
//  Created by Shuhei Yukawa
//

import Foundation
import SkyWayCore

public final class SkywayVideoView: UIView {
    private var stream: ConferenceStream?
    private var skwVideo = VideoView(frame: CGRect(x: 0, y: 0, width: 200, height: 200))

    override public init(frame: CGRect) {
        super.init(frame: frame)
        self.setComponent()
        self.setLayout()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public func setStream(stream: ConferenceStream?) {
        guard let stream = stream else {
            return
        }

        // すでにセットされている場合
        if let currentStream = self.stream {
            if currentStream.peerId != stream.peerId {
                currentStream.remoteVideoStream?.detach(self.skwVideo)
                // ストリームを入れ替えると直前のストリームの最後のフレームがビューに残り続ける。これを回避するため再生成する
                self.skwVideo.removeFromSuperview()
                self.recreateVideoView()
            }
        }
        
        self.renderVideo(stream: stream)
    }

    private func setMirror() {
        guard let stream = self.stream else { return }
        let cameraPosition = CameraVideoSource.shared().camera?.position ?? .front
        if stream.isMe && cameraPosition == .front {
            self.skwVideo.transform = CGAffineTransform(scaleX: -1, y: 1)
        } else {
            self.skwVideo.transform = CGAffineTransform(scaleX: 1, y: 1)
        }
    }

    private func renderVideo(stream: ConferenceStream) {
        stream.remoteVideoStream?.attach(self.skwVideo)
        self.stream = stream

        self.setMirror()
    }

    // detach, attach の置き換えでは問題が起きるので作り直し
    private func recreateVideoView() {
        self.skwVideo = VideoView(frame: CGRect(x: 0, y: 0, width: 200, height: 200))
        
        self.setComponent()
        self.setLayout()
    }

    private func setComponent() {
        self.skwVideo.videoContentMode = .scaleAspectFit
        self.skwVideo.backgroundColor = UIColor(white: 0.1, alpha: 1.0)
        self.addSubview(self.skwVideo)
    }

    private func setLayout() {
        self.skwVideo.translatesAutoresizingMaskIntoConstraints = false
        self.skwVideo.topAnchor.constraint(equalTo: self.topAnchor).isActive = true
        self.skwVideo.bottomAnchor.constraint(equalTo: self.bottomAnchor).isActive = true
        self.skwVideo.leftAnchor.constraint(equalTo: self.leftAnchor).isActive = true
        self.skwVideo.rightAnchor.constraint(equalTo: self.rightAnchor).isActive = true
    }
}

