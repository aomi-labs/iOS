# Aomi Backend API Connection Guide

This document explains how to connect to a deployed Aomi instance from any client (iOS, web, mobile).

## Base URL

**Production:** `https://aomi.dev`

The backend API is served from the same origin as the frontend. All API endpoints are prefixed with `/api/`.

## Authentication

### Headers

| Header | Required | Description |
|--------|----------|-------------|
| `X-Session-Id` | Yes (most endpoints) | Unique session identifier. Generate a UUID on the client side. |
| `X-API-Key` | Conditional | Required for non-default namespaces. Contact Aomi for API keys. |

### Session ID Generation

The client is responsible for generating and persisting a session ID. Use a UUID v4:

```swift
// iOS/Swift
let sessionId = UUID().uuidString

// JavaScript
const sessionId = crypto.randomUUID()
```

Persist this session ID locally to maintain conversation continuity across app restarts.

---

## Core Endpoints

### 1. Health Check

```
GET /health
```

Returns `"OK"` if the server is running. No authentication required.

---

### 2. Send Chat Message

```
POST /api/chat
```

**Headers:**
- `X-Session-Id: <session-id>` (required)
- `X-API-Key: <api-key>` (required for non-default namespaces)

**Query Parameters:**

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `message` | string | Yes | The user's message |
| `namespace` | string | No | Backend namespace (default: `"default"`) |
| `public_key` | string | No | User's wallet address (for wallet-connected sessions) |
| `user_state` | JSON | No | Client-side state to sync (JSON string) |

**Example Request:**

```bash
curl -X POST "https://aomi.dev/api/chat?message=Hello%20Aomi" \
  -H "X-Session-Id: 550e8400-e29b-41d4-a716-446655440000"
```

**Response:**

```json
{
  "messages": [
    {
      "sender": "user",
      "content": "Hello Aomi",
      "label": null
    },
    {
      "sender": "assistant", 
      "content": "Hello! How can I help you today?",
      "label": null
    }
  ],
  "system_events": [],
  "title": "New Conversation",
  "is_processing": false,
  "user_state": null
}
```

---

### 3. Get Session State (Polling)

```
GET /api/state
```

Poll this endpoint to get the current session state, including any new messages.

**Headers:**
- `X-Session-Id: <session-id>` (required)

**Query Parameters:**

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `user_state` | JSON | No | Client-side state to sync |

**Response:** Same structure as `/api/chat`

**Note:** If the session doesn't exist yet, returns empty state:

```json
{
  "messages": [],
  "system_events": [],
  "title": null,
  "is_processing": false,
  "user_state": null
}
```

---

### 4. Real-time Updates (SSE)

```
GET /api/updates
```

Server-Sent Events stream for real-time updates (title changes, tool completions, etc.)

**Headers:**
- `X-Session-Id: <session-id>` (required)

**Example (JavaScript):**

```javascript
const eventSource = new EventSource('/api/updates', {
  headers: { 'X-Session-Id': sessionId }
});

eventSource.onmessage = (event) => {
  const data = JSON.parse(event.data);
  console.log('Update:', data);
};
```

**Note:** For iOS, use a library like `EventSource` or implement SSE manually with `URLSession`.

---

### 5. Interrupt Processing

```
POST /api/interrupt
```

Stop the AI from continuing its current response.

**Headers:**
- `X-Session-Id: <session-id>` (required)

**Response:** Current session state

---

### 6. Send System Message

```
POST /api/system?message=<system-message>
```

Send a system-level command (e.g., switch backend, clear context).

**Headers:**
- `X-Session-Id: <session-id>` (required)

---

## Session Management

### List Sessions

```
GET /api/sessions?public_key=<wallet-address>
```

Get all sessions for a wallet address.

**Response:**

```json
[
  {
    "session_id": "550e8400-e29b-41d4-a716-446655440000",
    "title": "My Conversation",
    "is_archived": false
  }
]
```

### Create Session

```
POST /api/sessions
```

**Headers:**
- `X-Session-Id: <new-session-id>` (required - client generates this)

**Body:**

```json
{
  "public_key": "0x..."  // optional wallet address
}
```

### Get Session

```
GET /api/sessions/:session_id
```

**Headers:**
- `X-Session-Id: <session-id>` (must match path param)

### Delete/Archive Session

```
DELETE /api/sessions/:session_id
```

or

```
POST /api/sessions/:session_id/archive
```

### Rename Session

```
PATCH /api/sessions/:session_id
```

**Body:**

```json
{
  "title": "New Title"
}
```

### Unarchive Session

```
POST /api/sessions/:session_id/unarchive
```

---

## Control Endpoints

### Get Available Models

```
GET /api/control/models?rig=<namespace>
```

**Headers:**
- `X-Session-Id: <session-id>` (required)

### Set Model

```
POST /api/control/model
```

**Headers:**
- `X-Session-Id: <session-id>` (required)

### Get Namespaces

```
GET /api/control/namespaces
```

**Headers:**
- `X-Session-Id: <session-id>` (required)

---

## Wallet Integration

### Bind Wallet (Internal)

```
POST /api/wallet/bind
```

Used internally by Telegram bot to bind wallet addresses. Requires `x-wallet-bind-key` header.

---

## iOS Implementation Notes

### 1. HTTP Client Setup

```swift
class AomiClient {
    private let baseURL = URL(string: "https://aomi.dev")!
    private var sessionId: String
    
    init() {
        // Load from UserDefaults or generate new
        if let stored = UserDefaults.standard.string(forKey: "aomi_session_id") {
            self.sessionId = stored
        } else {
            self.sessionId = UUID().uuidString
            UserDefaults.standard.set(sessionId, forKey: "aomi_session_id")
        }
    }
    
    func sendMessage(_ message: String) async throws -> ChatResponse {
        var components = URLComponents(url: baseURL.appendingPathComponent("/api/chat"), resolvingAgainstBaseURL: true)!
        components.queryItems = [URLQueryItem(name: "message", value: message)]
        
        var request = URLRequest(url: components.url!)
        request.httpMethod = "POST"
        request.setValue(sessionId, forHTTPHeaderField: "X-Session-Id")
        
        let (data, _) = try await URLSession.shared.data(for: request)
        return try JSONDecoder().decode(ChatResponse.self, from: data)
    }
}
```

### 2. Response Models

```swift
struct ChatResponse: Codable {
    let messages: [ChatMessage]
    let systemEvents: [SystemEvent]
    let title: String?
    let isProcessing: Bool
    let userState: UserState?
    
    enum CodingKeys: String, CodingKey {
        case messages
        case systemEvents = "system_events"
        case title
        case isProcessing = "is_processing"
        case userState = "user_state"
    }
}

struct ChatMessage: Codable {
    let sender: String  // "user" | "assistant" | "system"
    let content: String
    let label: String?
}

struct SystemEvent: Codable {
    // Event-specific fields
}
```

### 3. Polling vs SSE

For simplicity, you can poll `/api/state` every 1-2 seconds while `is_processing` is true:

```swift
func pollUntilComplete() async throws -> ChatResponse {
    while true {
        let state = try await getState()
        if !state.isProcessing {
            return state
        }
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
    }
}
```

For better UX, implement SSE for real-time streaming.

---

## Error Handling

| Status | Meaning |
|--------|---------|
| 400 | Bad Request - Missing required parameters |
| 401 | Unauthorized - Missing or invalid API key |
| 403 | Forbidden - API key doesn't allow this namespace |
| 404 | Not Found - Session doesn't exist |
| 500 | Server Error |

---

## Rate Limits

Currently no strict rate limits, but be reasonable:
- Don't poll faster than 500ms
- Don't send more than ~10 messages per minute

---

## Questions?

Contact the Aomi team for API keys or integration support.
