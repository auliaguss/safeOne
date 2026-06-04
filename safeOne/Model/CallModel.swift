//
//  CallModel.swift
//  safeOne
//
//  Created by Ivan Yuantama Pradipta on 03/06/26.
//

import Foundation

struct InitiateCallResponse: Codable {
    let callId: String
    let channelName: String
    let agoraToken: String
    let agoraAppId: String
}

struct AnswerCallResponse: Codable {
    let callId: String
    let channelName: String
    let agoraToken: String
    let agoraAppId: String
    let elderName: String
}
