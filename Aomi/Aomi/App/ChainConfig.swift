import Foundation

struct ChainConfig {
    let chainId: Int
    let name: String
    let rpcURL: URL

    private static let alchemy = AppConfig.alchemyAPIKey

    static let supported: [Int: ChainConfig] = [
        1: ChainConfig(chainId: 1, name: "Ethereum", rpcURL: URL(string: "https://eth-mainnet.g.alchemy.com/v2/\(alchemy)")!),
        42161: ChainConfig(chainId: 42161, name: "Arbitrum", rpcURL: URL(string: "https://arb-mainnet.g.alchemy.com/v2/\(alchemy)")!),
        8453: ChainConfig(chainId: 8453, name: "Base", rpcURL: URL(string: "https://base-mainnet.g.alchemy.com/v2/\(alchemy)")!),
        10: ChainConfig(chainId: 10, name: "Optimism", rpcURL: URL(string: "https://opt-mainnet.g.alchemy.com/v2/\(alchemy)")!),
        137: ChainConfig(chainId: 137, name: "Polygon", rpcURL: URL(string: "https://polygon-mainnet.g.alchemy.com/v2/\(alchemy)")!),
    ]

    static func rpcURL(for chainId: Int) -> URL {
        supported[chainId]?.rpcURL ?? supported[1]!.rpcURL
    }
}
