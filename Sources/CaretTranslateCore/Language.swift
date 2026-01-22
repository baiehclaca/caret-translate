import Foundation

public struct Language: Equatable, Hashable, Codable, Sendable {
    public let code: String

    public init(code: String) {
        self.code = code.lowercased()
    }

    public static let auto = Language(code: "auto")
}

public struct LanguagePair: Equatable, Hashable, Codable, Sendable {
    public let from: Language
    public let to: Language

    public init(from: Language, to: Language) {
        self.from = from
        self.to = to
    }
}
