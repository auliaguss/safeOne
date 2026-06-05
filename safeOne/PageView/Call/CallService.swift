//
//  CallService.swift
//  safeOne
//
//  Created by Ivan Yuantama Pradipta on 03/06/26.
//

// CallService.swift
import Foundation

class CallService {
    static let shared = CallService()
    private let baseURL = AppConfig.baseURL

    // Elder: initiate call
    func initiateCall(token: String) async throws -> InitiateCallResponse {
        guard let url = URL(string: "\(baseURL)/calls/initiate") else {
            throw URLError(.badURL)
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        print("📡 Hitting: \(url)")           // ← tambahkan
        print("🔑 Header token: \(token)")    // ← tambahkan
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            let err = try? JSONDecoder().decode([String: String].self, from: data)
            throw NSError(domain: err?["error"] ?? "Server error", code: 0)
        }
        return try JSONDecoder().decode(InitiateCallResponse.self, from: data)
    }

    // Child: answer call
    func answerCall(callId: String, token: String) async throws -> AnswerCallResponse {
        guard let url = URL(string: "\(baseURL)/calls/\(callId)/answer") else {
            throw URLError(.badURL)
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            let err = try? JSONDecoder().decode([String: String].self, from: data)
            throw NSError(domain: err?["error"] ?? "Server error", code: 0)
        }
        return try JSONDecoder().decode(AnswerCallResponse.self, from: data)
    }

    // Both: decline call
    func declineCall(callId: String, token: String) async throws {
        guard let url = URL(string: "\(baseURL)/calls/\(callId)/decline") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        _ = try await URLSession.shared.data(for: request)
    }

    // Both: end call
    func endCall(callId: String, token: String) async throws {
        guard let url = URL(string: "\(baseURL)/calls/\(callId)/end") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        _ = try await URLSession.shared.data(for: request)
    }
}
