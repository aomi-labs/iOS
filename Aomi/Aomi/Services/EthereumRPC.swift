import Foundation

enum EthereumRPC {
    static func estimateGas(to: String?, from: String?, value: String?, data: String?, rpcURL: URL) async throws -> String {
        var txObj: [String: String] = [:]
        if let to { txObj["to"] = to }
        if let from { txObj["from"] = from }
        if let value, !value.isEmpty {
            txObj["value"] = value.hasPrefix("0x") ? value : "0x" + String(UInt64(value) ?? 0, radix: 16)
        }
        if let data, !data.isEmpty {
            txObj["data"] = data.hasPrefix("0x") ? data : "0x" + data
        }

        let result = try await rpcCall(method: "eth_estimateGas", params: [txObj], rpcURL: rpcURL)
        guard let hex = result as? String else { throw RPCError.invalidResponse }
        return hex
    }

    static func getGasPrice(rpcURL: URL) async throws -> String {
        let result = try await rpcCall(method: "eth_gasPrice", params: [] as [String], rpcURL: rpcURL)
        guard let hex = result as? String else { throw RPCError.invalidResponse }
        return hex
    }

    static func getMaxPriorityFee(rpcURL: URL) async throws -> String {
        let result = try await rpcCall(method: "eth_maxPriorityFeePerGas", params: [] as [String], rpcURL: rpcURL)
        guard let hex = result as? String else { throw RPCError.invalidResponse }
        return hex
    }

    static func sendRawTransaction(signedTx: String, rpcURL: URL) async throws -> String {
        let tx = signedTx.hasPrefix("0x") ? signedTx : "0x" + signedTx
        let result = try await rpcCall(method: "eth_sendRawTransaction", params: [tx], rpcURL: rpcURL)
        guard let hex = result as? String else { throw RPCError.invalidResponse }
        return hex
    }

    // MARK: - Internal

    private static func rpcCall(method: String, params: Any, rpcURL: URL) async throws -> Any {
        var request = URLRequest(url: rpcURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30

        let body: [String: Any] = [
            "jsonrpc": "2.0",
            "id": 1,
            "method": method,
            "params": params
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
        guard let result = json["result"] else {
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
