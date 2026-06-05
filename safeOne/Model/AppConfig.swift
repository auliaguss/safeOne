//
//  AppConfig.swift
//  safeOne
//

import Foundation

enum AppConfig {
    #if DEBUG
    static let baseURL = "http://10.64.49.194:3000/api"
    #else
    static let baseURL = "https://safe-one-backend.vercel.app/api"
    #endif
}
