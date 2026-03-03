import XCTest
@testable import Aomi

final class APIClientTests: XCTestCase {
    func testBuildChatRequest() async throws {
        let client = await AomiAPIClient(baseURL: "https://api.test.com")
        let request = try await client.buildChatRequest(
            sessionId: "test-session",
            message: "hello",
            namespace: nil,
            publicKey: "0x123",
            userState: nil
        )
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.value(forHTTPHeaderField: "X-Session-Id"), "test-session")
        XCTAssertTrue(request.url!.absoluteString.contains("message=hello"))
        XCTAssertTrue(request.url!.absoluteString.contains("public_key=0x123"))
    }

    func testBuildSessionListRequest() async throws {
        let client = await AomiAPIClient(baseURL: "https://api.test.com")
        let request = try await client.buildSessionListRequest(publicKey: "0x123")
        XCTAssertEqual(request.httpMethod, "GET")
        XCTAssertTrue(request.url!.absoluteString.contains("public_key=0x123"))
    }

    func testNoSessionThrows() async {
        let client = await AomiAPIClient(baseURL: "https://api.test.com")
        do {
            _ = try await client.sendMessage("hello")
            XCTFail("Should throw")
        } catch {
            XCTAssertTrue(error is AomiAPIClient.APIError)
        }
    }
}
