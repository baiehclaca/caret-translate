import Foundation

struct LanguageMenuItem: Equatable {
    let code: String
    let name: String

    init(code: String, name: String) {
        self.code = code
        self.name = name
    }

    /// Creates a menu item from a language option.
    init(_ option: LanguageOption) {
        self.code = option.code
        self.name = option.name
    }

    var label: String {
        "\(name) (\(code.uppercased()))"
    }
}
