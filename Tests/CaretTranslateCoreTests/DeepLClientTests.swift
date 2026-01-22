import XCTest
@testable import CaretTranslateCore

final class DeepLClientTests: XCTestCase {
    func testFetchLanguagesBuildsRequestAndParsesResponse() async throws {
        let mock = MockHTTPClient()
        let client = DeepLClient(authKey: "test-key:fx", httpClient: mock)
        mock.nextData = """
        [
          { "language": "EN", "name": "English" },
          { "language": "DE", "name": "German" }
        ]
        """.data(using: .utf8)!

        let languages = try await client.fetchLanguages(type: .source)

        XCTAssertEqual(languages, [
            DeepLLanguage(code: "EN", name: "English"),
            DeepLLanguage(code: "DE", name: "German")
        ])
        XCTAssertEqual(mock.lastRequest?.httpMethod, "GET")
        XCTAssertEqual(
            mock.lastRequest?.value(forHTTPHeaderField: "Authorization"),
            "DeepL-Auth-Key test-key:fx"
        )
        XCTAssertEqual(
            mock.lastRequest?.url?.absoluteString,
            "https://api-free.deepl.com/v2/languages?type=source"
        )
    }

    func testTranslateBuildsRequestAndParsesResponse() async throws {
        let mock = MockHTTPClient()
        let client = DeepLClient(authKey: "test-key:fx", httpClient: mock)
        mock.nextData = """
        { "translations": [ { "text": "Hallo" } ] }
        """.data(using: .utf8)!

        let result = try await client.translate(text: "hello", source: "EN", target: "DE")

        XCTAssertEqual(result, "Hallo")
        XCTAssertEqual(mock.lastRequest?.httpMethod, "POST")
        XCTAssertEqual(
            mock.lastRequest?.value(forHTTPHeaderField: "Authorization"),
            "DeepL-Auth-Key test-key:fx"
        )
        XCTAssertEqual(
            mock.lastRequest?.value(forHTTPHeaderField: "Content-Type"),
            "application/x-www-form-urlencoded"
        )
        XCTAssertEqual(
            mock.lastRequest?.url?.absoluteString,
            "https://api-free.deepl.com/v2/translate"
        )
        let body = String(data: mock.lastRequest?.httpBody ?? Data(), encoding: .utf8) ?? ""
        XCTAssertTrue(body.contains("text=hello"))
        XCTAssertTrue(body.contains("source_lang=EN"))
        XCTAssertTrue(body.contains("target_lang=DE"))
    }

    func testTranslateOmitsSourceLangWhenNil() async throws {
        let mock = MockHTTPClient()
        let client = DeepLClient(authKey: "test-key:fx", httpClient: mock)
        mock.nextData = """
        { "translations": [ { "text": "Hallo" } ] }
        """.data(using: .utf8)!

        let result = try await client.translate(text: "hello", source: nil, target: "DE")

        XCTAssertEqual(result, "Hallo")
        let body = String(data: mock.lastRequest?.httpBody ?? Data(), encoding: .utf8) ?? ""
        XCTAssertTrue(body.contains("text=hello"))
        XCTAssertFalse(body.contains("source_lang="))
        XCTAssertTrue(body.contains("target_lang=DE"))
    }

    func testTranslateIncludesFormalityWhenProvided() async throws {
        let mock = MockHTTPClient()
        let client = DeepLClient(authKey: "test-key:fx", httpClient: mock)
        mock.nextData = """
        { "translations": [ { "text": "Hallo" } ] }
        """.data(using: .utf8)!

        _ = try await client.translate(text: "hello", source: "EN", target: "DE", formality: .more)

        let body = String(data: mock.lastRequest?.httpBody ?? Data(), encoding: .utf8) ?? ""
        XCTAssertTrue(body.contains("formality=more"))
    }
}

private final class MockHTTPClient: HTTPClient {
    var lastRequest: URLRequest?
    var nextData: Data = Data()
    var nextResponse: URLResponse = HTTPURLResponse(
        url: URL(string: "https://api-free.deepl.com")!,
        statusCode: 200,
        httpVersion: nil,
        headerFields: nil
    )!

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        lastRequest = request
        return (nextData, nextResponse)
    }
}
