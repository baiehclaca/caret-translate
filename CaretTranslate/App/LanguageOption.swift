import Foundation

struct LanguageOption: Identifiable, Comparable {
    let id: String
    let code: String
    let name: String

    /// Creates a language option with a normalized code and display name.
    init(code: String, name: String) {
        let normalized = code.lowercased()
        self.id = normalized
        self.code = normalized
        self.name = name
    }

    /// Returns the display label for the language option.
    var label: String {
        "\(name) (\(code.uppercased()))"
    }

    static func < (lhs: LanguageOption, rhs: LanguageOption) -> Bool {
        lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
    }

    static let auto = LanguageOption(code: "auto", name: "Auto Detect")
}
