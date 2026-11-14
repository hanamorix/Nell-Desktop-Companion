import Foundation

public enum Mode: String, Codable, Sendable, CaseIterable { case code, chat }

public enum JSONValue: Codable, Sendable, Equatable {
    case string(String), number(Double), bool(Bool), object([String: JSONValue]), array([JSONValue]), null

    public init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { self = .null }
        else if let v = try? c.decode(Bool.self) { self = .bool(v) }
        else if let v = try? c.decode(Double.self) { self = .number(v) }
        else if let v = try? c.decode(String.self) { self = .string(v) }
        else if let v = try? c.decode([JSONValue].self) { self = .array(v) }
        else { self = .object(try c.decode([String: JSONValue].self)) }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .string(let v): try c.encode(v)
        case .number(let v): try c.encode(v)
        case .bool(let v): try c.encode(v)
        case .object(let v): try c.encode(v)
        case .array(let v): try c.encode(v)
        case .null: try c.encodeNil()
        }
    }

    public var string: String? { if case .string(let s) = self { s } else { nil } }
}

public struct HookEvent: Decodable, Sendable, Equatable {
    public var name: String
    public var sessionId: String
    public var toolName: String?
    public var toolInput: [String: JSONValue]?
    public var toolUseId: String?
    public var prompt: String?
    public var message: String?
    public var notificationType: String?
    public var lastAssistantMessage: String?
    public var error: String?

    enum CodingKeys: String, CodingKey {
        case name = "hook_event_name", sessionId = "session_id", toolName = "tool_name", toolInput = "tool_input",
             toolUseId = "tool_use_id", prompt, message, notificationType = "notification_type",
             lastAssistantMessage = "last_assistant_message", error
    }

    public static func decode(_ data: Data) throws -> HookEvent {
        try JSONDecoder().decode(HookEvent.self, from: data)
    }
}
