import XCTest
@testable import Aomi

final class ModelsTests: XCTestCase {
    func testChatMessageCreation() async {
        await MainActor.run {
            let msg = ChatMessage(role: .user, content: [.text("Hello")])
            XCTAssertEqual(msg.role, .user)
            XCTAssertEqual(msg.textContent, "Hello")
        }
    }

    func testWidgetPayloadDecoding() throws {
        let json = """
        {"widget_type":"portfolio_overview","data":{"total_value":"12345.67","tokens":[]}}
        """.data(using: .utf8)!
        let payload = try JSONDecoder().decode(WidgetPayload.self, from: json)
        XCTAssertEqual(payload.widgetType, "portfolio_overview")
    }

    func testSessionResponseDecoding() throws {
        let json = """
        {
          "messages": [
            {"sender":"user","content":"hello","timestamp":"12:00:00 UTC","is_streaming":false}
          ],
          "system_events": [],
          "title": "Test",
          "is_processing": false
        }
        """.data(using: .utf8)!
        let response = try JSONDecoder().decode(SessionResponse.self, from: json)
        XCTAssertEqual(response.messages.count, 1)
        XCTAssertEqual(response.messages[0].sender, .user)
    }

    func testJSONValueDecoding() throws {
        let json = """
        {"name":"test","count":42,"active":true,"tags":["a","b"],"extra":null}
        """.data(using: .utf8)!
        let value = try JSONDecoder().decode(JSONValue.self, from: json)
        XCTAssertEqual(value["name"]?.stringValue, "test")
        XCTAssertEqual(value["count"]?.numberValue, 42)
    }

    func testToolResultTupleDecoding() throws {
        let json = """
        ["balance_check","1.5 ETH"]
        """.data(using: .utf8)!
        let tuple = try JSONDecoder().decode(ToolResultTuple.self, from: json)
        XCTAssertEqual(tuple.topic, "balance_check")
        XCTAssertEqual(tuple.content, "1.5 ETH")
    }
}
