import Foundation

enum AppConfig {
    #if DEBUG
    static let apiBaseURL = "http://localhost:8080"
    #else
    static let apiBaseURL = "https://api.aomi.io"
    #endif

    static let paraEnvironment = "beta"
    static let paraAPIKey = "" // Set via KeychainService or replace with your Para API key
    static let paraAppScheme = "aomi"
}
