import Foundation

/// Resolves ENS names to Ethereum addresses using a public Ethereum RPC endpoint.
/// Implements keccak256 and namehash internally to avoid external dependencies.
actor ENSResolver {
    static let shared = ENSResolver()

    private let rpcURL = URL(string: "https://cloudflare-eth.com")!
    private let registryAddress = "0x00000000000C2E074eC69A0dFb2997BA6C7d2e1e"

    // Well-known function selectors
    private let resolverSelector = "0178b8bf" // keccak256("resolver(bytes32)")[:4]
    private let addrSelector = "3b3b57de"     // keccak256("addr(bytes32)")[:4]

    static func looksLikeENS(_ input: String) -> Bool {
        let trimmed = input.trimmingCharacters(in: .whitespaces).lowercased()
        return trimmed.hasSuffix(".eth") && trimmed.count > 4 && !trimmed.contains(" ")
    }

    func resolve(_ name: String) async throws -> String {
        let normalized = name.trimmingCharacters(in: .whitespaces).lowercased()
        guard Self.looksLikeENS(normalized) else { throw ENSError.invalidName }

        let namehash = Self.namehash(normalized)

        // Step 1: Get resolver address from ENS registry
        let resolverCalldata = "0x" + resolverSelector + namehash
        let resolverHex = try await ethCall(to: registryAddress, data: resolverCalldata)

        guard resolverHex.count >= 40 else { throw ENSError.invalidResponse }
        let resolverAddress = "0x" + resolverHex.suffix(40)
        guard resolverAddress != "0x0000000000000000000000000000000000000000" else {
            throw ENSError.noResolver
        }

        // Step 2: Get address from resolver
        let addrCalldata = "0x" + addrSelector + namehash
        let addressHex = try await ethCall(to: resolverAddress, data: addrCalldata)

        guard addressHex.count >= 40 else { throw ENSError.invalidResponse }
        let rawAddress = String(addressHex.suffix(40))
        guard rawAddress != "0000000000000000000000000000000000000000" else {
            throw ENSError.noAddress
        }

        return Self.checksumAddress(rawAddress)
    }

    // MARK: - Namehash (EIP-137)

    static func namehash(_ name: String) -> String {
        var node = [UInt8](repeating: 0, count: 32)
        guard !name.isEmpty else {
            return node.map { String(format: "%02x", $0) }.joined()
        }

        let labels = name.split(separator: ".").reversed()
        for label in labels {
            let labelHash = keccak256(Array(label.utf8))
            node = keccak256(node + labelHash)
        }
        return node.map { String(format: "%02x", $0) }.joined()
    }

    // MARK: - EIP-55 Checksum Address

    static func checksumAddress(_ hex: String) -> String {
        let lower = hex.lowercased()
        let hash = keccak256(Array(lower.utf8))
        var result = "0x"
        for (i, char) in lower.enumerated() {
            if char >= "a" && char <= "f" {
                let hashByte = hash[i / 2]
                let nibble = (i % 2 == 0) ? (hashByte >> 4) : (hashByte & 0x0f)
                result.append(nibble >= 8 ? char.uppercased() : String(char))
            } else {
                result.append(char)
            }
        }
        return result
    }

    // MARK: - Ethereum JSON-RPC

    private func ethCall(to address: String, data: String) async throws -> String {
        var request = URLRequest(url: rpcURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 10

        let body: [String: Any] = [
            "jsonrpc": "2.0",
            "id": 1,
            "method": "eth_call",
            "params": [
                ["to": address, "data": data],
                "latest"
            ]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (responseData, _) = try await URLSession.shared.data(for: request)

        guard let json = try JSONSerialization.jsonObject(with: responseData) as? [String: Any] else {
            throw ENSError.invalidResponse
        }
        if let error = json["error"] as? [String: Any],
           let message = error["message"] as? String {
            throw ENSError.rpcError(message)
        }
        guard let result = json["result"] as? String, result.count > 2 else {
            throw ENSError.invalidResponse
        }
        return String(result.dropFirst(2)) // strip "0x"
    }

    // MARK: - Errors

    enum ENSError: LocalizedError {
        case noResolver
        case noAddress
        case invalidResponse
        case invalidName
        case rpcError(String)

        var errorDescription: String? {
            switch self {
            case .noResolver: return "No ENS resolver found for this name"
            case .noAddress: return "No address set for this ENS name"
            case .invalidResponse: return "Failed to reach Ethereum network"
            case .invalidName: return "Invalid ENS name"
            case .rpcError(let msg): return "RPC error: \(msg)"
            }
        }
    }
}

// MARK: - Keccak-256

/// Ethereum's keccak256 hash function.
/// Uses original Keccak padding (0x01), NOT NIST SHA3 padding (0x06).
func keccak256(_ input: [UInt8]) -> [UInt8] {
    let rate = 136 // 1088 bits / 8
    var state = [UInt64](repeating: 0, count: 25)

    // Pad: append 0x01, pad with zeros to rate boundary, XOR last byte with 0x80
    var message = input
    message.append(0x01)
    while message.count % rate != 0 {
        message.append(0x00)
    }
    message[message.count - 1] ^= 0x80

    // Absorb
    for offset in stride(from: 0, to: message.count, by: rate) {
        for i in 0..<(rate / 8) {
            let base = offset + i * 8
            var word: UInt64 = 0
            for j in 0..<8 {
                word |= UInt64(message[base + j]) << (j * 8)
            }
            state[i] ^= word
        }
        keccakF1600(&state)
    }

    // Squeeze: extract 32 bytes (256 bits)
    var output = [UInt8](repeating: 0, count: 32)
    for i in 0..<4 {
        let word = state[i]
        for j in 0..<8 {
            output[i * 8 + j] = UInt8((word >> (j * 8)) & 0xff)
        }
    }
    return output
}

// MARK: - Keccak-f[1600] Permutation

private let keccakRC: [UInt64] = [
    0x0000000000000001, 0x0000000000008082, 0x800000000000808A, 0x8000000080008000,
    0x000000000000808B, 0x0000000080000001, 0x8000000080008081, 0x8000000000008009,
    0x000000000000008A, 0x0000000000000088, 0x0000000080008009, 0x000000008000000A,
    0x000000008000808B, 0x800000000000008B, 0x8000000000008089, 0x8000000000008003,
    0x8000000000008002, 0x8000000000000080, 0x000000000000800A, 0x800000008000000A,
    0x8000000080008081, 0x8000000000008080, 0x0000000080000001, 0x8000000080008008
]

// Rotation offsets indexed by [x + 5*y]
private let keccakRot: [Int] = [
     0,  1, 62, 28, 27,
    36, 44,  6, 55, 20,
     3, 10, 43, 25, 39,
    41, 45, 15, 21,  8,
    18,  2, 61, 56, 14
]

private func keccakF1600(_ state: inout [UInt64]) {
    for round in 0..<24 {
        // Theta
        var c = [UInt64](repeating: 0, count: 5)
        for x in 0..<5 {
            c[x] = state[x] ^ state[x+5] ^ state[x+10] ^ state[x+15] ^ state[x+20]
        }
        for x in 0..<5 {
            let d = c[(x+4) % 5] ^ rotl64(c[(x+1) % 5], 1)
            for y in stride(from: x, to: 25, by: 5) {
                state[y] ^= d
            }
        }

        // Rho + Pi
        var b = [UInt64](repeating: 0, count: 25)
        for x in 0..<5 {
            for y in 0..<5 {
                let src = x + 5 * y
                let dst = y + 5 * ((2 * x + 3 * y) % 5)
                b[dst] = rotl64(state[src], keccakRot[src])
            }
        }

        // Chi
        for x in 0..<5 {
            for y in 0..<5 {
                let idx = x + 5 * y
                state[idx] = b[idx] ^ (~b[(x+1)%5 + 5*y] & b[(x+2)%5 + 5*y])
            }
        }

        // Iota
        state[0] ^= keccakRC[round]
    }
}

private func rotl64(_ x: UInt64, _ n: Int) -> UInt64 {
    guard n > 0 else { return x }
    return (x << n) | (x >> (64 - n))
}
