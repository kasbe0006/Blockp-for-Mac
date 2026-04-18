import Foundation

public enum RuleType: String, Codable, CaseIterable, Sendable {
    case domain
    case exactHost
    case keyword
}

public struct BlockRule: Codable, Hashable, Sendable {
    public var type: RuleType
    public var value: String

    public init(type: RuleType, value: String) {
        self.type = type
        self.value = value
    }
}

public struct BlockList: Codable, Sendable {
    public var rules: [BlockRule]

    public init(rules: [BlockRule]) {
        self.rules = rules
    }
}
