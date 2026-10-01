//
//  VideoView.swift
//  safeOne
//

import SwiftUI
import AgoraRtcKit

// View untuk menampilkan video stream (local atau remote)
struct VideoView: UIViewRepresentable {
    let uid: UInt             // 0 = local, lainnya = remote uid
    let agoraManager: AgoraManager

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .black
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        if uid == 0 {
            agoraManager.setupLocalVideo(view: uiView)
        } else {
            agoraManager.setupRemoteVideo(uid: uid, view: uiView)
        }
    }
}
