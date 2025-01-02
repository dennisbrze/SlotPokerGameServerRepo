import Foundation

struct ClientMessage: Codable {
    let type: String
    let data: ClientData
}

struct ClientData: Codable {
    // Define properties based on client messages
    let action: String
    let amount: Int?
}

struct ServerMessage: Codable {
    let type: String
    let data: ServerData
}

struct ServerData: Codable {
    // Define properties based on server responses
    let gameState: GameStateModel
    let message: String?
}
