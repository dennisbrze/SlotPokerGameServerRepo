import Foundation
import Starscream

class WebSocketServer: WebSocketDelegate {
    private var server: Server!
    private var clients: [WebSocket] = []

    init() {
        server = Server()
        server.delegate = self
    }

    func start() {
        do {
            try server.start(port: 8080)
            print("WebSocket server started on port 8080")
        } catch {
            print("Failed to start WebSocket server: \(error)")
        }
    }

    func stop() {
        server.stop()
        print("WebSocket server stopped")
    }

    // WebSocketDelegate methods
    func didReceive(event: WebSocketEvent, client: WebSocket) {
        switch event {
        case .connected:
            clients.append(client)
            print("Client connected: \(client)")
        case .disconnected:
            if let index = clients.firstIndex(of: client) {
                clients.remove(at: index)
            }
            print("Client disconnected: \(client)")
        case .text(let message):
            handleMessage(message, from: client)
        default:
            break
        }
    }

    private func handleMessage(_ message: String, from client: WebSocket) {
        guard let messageData = message.data(using: .utf8),
              let clientMessage = try? JSONDecoder().decode(ClientMessage.self, from: messageData) else {
            print("Invalid message format")
            return
        }

        switch clientMessage.type {
        case "playerAction":
            // Handle player actions
            if let action = clientMessage.data.action,
               let amount = clientMessage.data.amount {
                // Update game state based on action
                // For example:
                // pokerGame.playerAction(player: currentPlayer, action: .raise(amount))
            }
        default:
            print("Unknown message type: \(clientMessage.type)")
        }
    }

    func broadcast(message: String) {
        for client in clients {
            client.write(string: message)
        }
    }
}
