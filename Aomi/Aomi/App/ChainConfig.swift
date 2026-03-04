import Foundation

struct ChainConfig {
    let chainId: Int
    let name: String
    let rpcURL: URL

    static let supported: [Int: ChainConfig] = [
        1: ChainConfig(chainId: 1, name: "Ethereum", rpcURL: URL(string: "https://cloudflare-eth.com")!),
        42161: ChainConfig(chainId: 42161, name: "Arbitrum", rpcURL: URL(string: "https://arb1.arbitrum.io/rpc")!),
        8453: ChainConfig(chainId: 8453, name: "Base", rpcURL: URL(string: "https://mainnet.base.org")!),
        10: ChainConfig(chainId: 10, name: "Optimism", rpcURL: URL(string: "https://mainnet.optimism.io")!),
        137: ChainConfig(chainId: 137, name: "Polygon", rpcURL: URL(string: "https://polygon-rpc.com")!),
    ]

    static func rpcURL(for chainId: Int) -> URL {
        supported[chainId]?.rpcURL ?? supported[1]!.rpcURL
    }
}
