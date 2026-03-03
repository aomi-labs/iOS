import Foundation

enum AppConfig {
    #if DEBUG
    static let apiBaseURL = "http://localhost:8080"
    #else
    static let apiBaseURL = "https://api.aomi.io"
    #endif

    static let paraEnvironment = "beta"
    static let paraAppScheme = "aomi"
}
