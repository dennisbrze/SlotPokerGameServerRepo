import Foundation
import Combine

// Enum for player actions
enum PlayerAction: Codable {
    case fold
    case raise(Int)
    case call(Int)
    case check

    enum CodingKeys: String, CodingKey {
        case type, value
    }

    enum ActionType: String, Codable {
        case fold, raise, call, check
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(ActionType.self, forKey: .type)
        switch type {
        case .fold:
            self = .fold
        case .raise:
            let value = try container.decode(Int.self, forKey: .value)
            self = .raise(value)
        case .call:
            let value = try container.decode(Int.self, forKey: .value)
            self = .call(value)
        case .check:
            self = .check
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .fold:
            try container.encode(ActionType.fold, forKey: .type)
        case .raise(let value):
            try container.encode(ActionType.raise, forKey: .type)
            try container.encode(value, forKey: .value)
        case .call(let value):
            try container.encode(ActionType.call, forKey: .type)
            try container.encode(value, forKey: .value)
        case .check:
            try container.encode(ActionType.check, forKey: .type)
        }
    }
}


// Model to represent a player
class Player: Identifiable, Codable {
    var id: UUID
    var name: String
    var chips: Int
    var currentBet: Int
    var action: PlayerAction?
    var hasFolded: Bool

    enum CodingKeys: String, CodingKey {
        case id, name, chips, currentBet, action, hasFolded
    }

    init(name: String, chips: Int) {
        self.id = UUID()
        self.name = name
        self.chips = chips
        self.currentBet = 0
        self.action = nil
        self.hasFolded = false
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(UUID.self, forKey: .id)
        self.name = try container.decode(String.self, forKey: .name)
        self.chips = try container.decode(Int.self, forKey: .chips)
        self.currentBet = try container.decode(Int.self, forKey: .currentBet)
        self.action = try container.decodeIfPresent(PlayerAction.self, forKey: .action)
        self.hasFolded = try container.decode(Bool.self, forKey: .hasFolded)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(chips, forKey: .chips)
        try container.encode(currentBet, forKey: .currentBet)
        try container.encode(action, forKey: .action)
        try container.encode(hasFolded, forKey: .hasFolded)
    }
}


// Model to represent the game state
class PokerGame: ObservableObject, Codable {
    @Published var players: [Player]
    @Published var pot: Int
    @Published var currentRound: Int
    @Published var activePlayerIndex: Int
    @Published var gameStatus: String

    enum CodingKeys: String, CodingKey {
        case players, pot, currentRound, activePlayerIndex, gameStatus
    }

    init(players: [Player], pot: Int, currentRound: Int, activePlayerIndex: Int, gameStatus: String) {
        self.players = players
        self.pot = pot
        self.currentRound = currentRound
        self.activePlayerIndex = activePlayerIndex
        self.gameStatus = gameStatus
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.players = try container.decode([Player].self, forKey: .players)
        self.pot = try container.decode(Int.self, forKey: .pot)
        self.currentRound = try container.decode(Int.self, forKey: .currentRound)
        self.activePlayerIndex = try container.decode(Int.self, forKey: .activePlayerIndex)
        self.gameStatus = try container.decode(String.self, forKey: .gameStatus)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(players, forKey: .players)
        try container.encode(pot, forKey: .pot)
        try container.encode(currentRound, forKey: .currentRound)
        try container.encode(activePlayerIndex, forKey: .activePlayerIndex)
        try container.encode(gameStatus, forKey: .gameStatus)
    }
}
