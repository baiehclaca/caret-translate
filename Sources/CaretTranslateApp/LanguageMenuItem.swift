import Foundation

struct LanguageMenuItem: Equatable {
    let code: String
    let name: String

    init(code: String, name: String) {
        self.code = code
        self.name = name
    }

    init(_ item: LanguageCatalogItem) {
        self.code = item.code
        self.name = item.name
    }

    var label: String {
        "\(name) (\(code.uppercased()))"
    }
}
