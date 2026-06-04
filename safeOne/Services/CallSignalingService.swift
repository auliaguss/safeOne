import Foundation

enum CallSignalEvent: Codable, Equatable {
    case join(callID: UUID, userID: UUID)
    case offer(callID: UUID, senderID: UUID, sdp: String)
    case answer(callID: UUID, senderID: UUID, sdp: String)
    case iceCandidate(callID: UUID, senderID: UUID, candidate: String, sdpMid: String?, sdpMLineIndex: Int?)
    case leave(callID: UUID, userID: UUID)
}

final class CallSignalingService: NSObject, URLSessionWebSocketDelegate {
    private var webSocketTask: URLSessionWebSocketTask?
    private lazy var session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    var onEvent: ((CallSignalEvent) -> Void)?

    func connect(callID: UUID, token: String?) {
        guard let baseURL = AppConfiguration.backendBaseURL else { return }
        var components = URLComponents(url: baseURL.appendingPathComponent("calls/\(callID.uuidString)/signal"), resolvingAgainstBaseURL: false)
        components?.scheme = baseURL.scheme == "https" ? "wss" : "ws"

        guard let url = components?.url else { return }
        var request = URLRequest(url: url)
        if let token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        webSocketTask = session.webSocketTask(with: request)
        webSocketTask?.resume()
        receiveNextMessage()
    }

    func send(_ event: CallSignalEvent) {
        guard let data = try? encoder.encode(event),
              let text = String(data: data, encoding: .utf8)
        else { return }

        webSocketTask?.send(.string(text)) { _ in }
    }

    func disconnect() {
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
    }

    private func receiveNextMessage() {
        webSocketTask?.receive { [weak self] result in
            guard let self else { return }

            if case .success(let message) = result {
                switch message {
                case .string(let text):
                    if let data = text.data(using: .utf8),
                       let event = try? decoder.decode(CallSignalEvent.self, from: data) {
                        DispatchQueue.main.async {
                            self.onEvent?(event)
                        }
                    }
                case .data(let data):
                    if let event = try? decoder.decode(CallSignalEvent.self, from: data) {
                        DispatchQueue.main.async {
                            self.onEvent?(event)
                        }
                    }
                @unknown default:
                    break
                }
                receiveNextMessage()
            }
        }
    }
}

