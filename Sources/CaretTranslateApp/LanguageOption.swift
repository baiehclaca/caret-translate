import Foundation
import CaretTranslateCore

struct LanguageOption: Identifiable, Comparable {
    let id: String
    let code: String
    let name: String

    init(code: String, name: String) {
        self.id = code
        self.code = code
        self.name = name
    }

    init(_ language: DeepLLanguage) {
        self.init(code: language.code.lowercased(), name: language.name)
    }

    var label: String {
        "\(name) (\(code.uppercased()))"
    }

    static func < (lhs: LanguageOption, rhs: LanguageOption) -> Bool {
        lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
    }

    static let auto = LanguageOption(code: "auto", name: "Auto Detect")
}
