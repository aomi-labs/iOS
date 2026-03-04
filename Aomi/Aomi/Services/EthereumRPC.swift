import Foundation

enum EthereumRPC {
    static func sendRawTransaction(signedTx: String, rpcURL: URL) async throws -> String {
        var request = URLRequest(url: rpcURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30

        let body: [String: Any] = [
            "jsonrpc": "2.0",
            "id": 1,
            "method": "eth_sendRawTransaction",
            "params": [signedTx.hasPrefix("0x") ? signedTx : "0x" + signedTx]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, _) = try await URLSession.shared.data(for: request)

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw RPCError.invalidResponse
        }
        if let error = json["error"] as? [String: Any],
           let message = error["message"] as? String {
            throw RPCError.rpcError(message)
        }
        guard let result = json["result"] as? String else {
            throw RPCError.invalidResponse
        }
        return result
    }

    enum RPCError: LocalizedError {
        case invalidResponse
        case rpcError(String)

        var errorDescription: String? {
            switch self {
            case .invalidResponse: return "Invalid RPC response"
            case .rpcError(let msg): return "RPC error: \(msg)"
            }
        }
    }
}
