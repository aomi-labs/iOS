import Foundation

enum AppConfig {
    #if DEBUG
    static let apiBaseURL = "http://localhost:8080"
    #else
    static let apiBaseURL = "https://aomi.dev"
    #endif

    static let paraEnvironment = "beta"
    static let paraAppScheme = "aomi"
}
