import Foundation

public struct DeepLLanguage: Codable, Equatable {
    public let code: String
    public let name: String

    public init(code: String, name: String) {
        self.code = code
        self.name = name
    }

    private enum CodingKeys: String, CodingKey {
        case code = "language"
        case name
    }
}

public enum DeepLLanguageType: String {
    case source
    case target
}

public protocol HTTPClient {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

extension URLSession: HTTPClient {}

public struct DeepLClient {
    private let authKey: String
    private let baseURL: URL
    private let httpClient: HTTPClient

    public init(authKey: String, baseURL: URL? = nil, httpClient: HTTPClient = URLSession.shared) {
        self.authKey = authKey
        self.baseURL = baseURL ?? DeepLClient.endpoint(for: authKey)
        self.httpClient = httpClient
    }

    public func fetchLanguages(type: DeepLLanguageType) async throws -> [DeepLLanguage] {
        var components = URLComponents(url: baseURL.appendingPathComponent("v2/languages"), resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "type", value: type.rawValue)
        ]
        guard let url = components?.url else {
            throw DeepLError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("DeepL-Auth-Key \(authKey)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await httpClient.data(for: request)
        try validate(response: response)
        return try JSONDecoder().decode([DeepLLanguage].self, from: data)
    }

    public func translate(
        text: String,
        source: String?,
        target: String,
        formality: TranslationFormality? = nil
    ) async throws -> String? {
        let url = baseURL.appendingPathComponent("v2/translate")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("DeepL-Auth-Key \(authKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        var items: [(String, String)] = [
            ("text", text),
            ("target_lang", target)
        ]
        if let source {
            items.append(("source_lang", source))
        }
        if let formality, formality != .default {
            items.append(("formality", formality.rawValue))
        }
        let body = DeepLClient.formEncode(items)
        request.httpBody = body.data(using: .utf8)

        let (data, response) = try await httpClient.data(for: request)
        try validate(response: response)
        let payload = try JSONDecoder().decode(DeepLTranslationResponse.self, from: data)
        return payload.translations.first?.text
    }

    static func endpoint(for authKey: String) -> URL {
        let isFree = authKey.lowercased().hasSuffix(":fx")
        if isFree {
            return URL(string: "https://api-free.deepl.com")!
        }
        return URL(string: "https://api.deepl.com")!
    }

    private static func formEncode(_ items: [(String, String)]) -> String {
        items.map { key, value in
            "\(urlEncode(key))=\(urlEncode(value))"
        }.joined(separator: "&")
    }

    private static func urlEncode(_ value: String) -> String {
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_.~")
        return value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
    }

    private func validate(response: URLResponse) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            return
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            throw DeepLError.httpStatus(httpResponse.statusCode)
        }
    }
}

private struct DeepLTranslationResponse: Codable {
    let translations: [DeepLTranslationItem]
}

private struct DeepLTranslationItem: Codable {
    let text: String
}

public enum DeepLError: Error {
    case invalidURL
    case httpStatus(Int)
}
