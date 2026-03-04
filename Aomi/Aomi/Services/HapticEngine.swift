import UIKit

@MainActor
enum HapticEngine {
    // MARK: - Impact

    static func lightTap() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    static func mediumTap() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    static func heavyTap() {
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
    }

    static func softTap() {
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
    }

    static func rigidTap() {
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
    }

    // MARK: - Notification

    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    static func warning() {
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }

    static func error() {
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }

    // MARK: - Selection

    static func selectionTick() {
        UISelectionFeedbackGenerator().selectionChanged()
    }

    // MARK: - Semantic

    static func messageSent() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred(intensity: 0.7)
    }

    static func messageReceived() {
        UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: 0.5)
    }

    static func thinkingStarted() {
        UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: 0.3)
    }

    static func transactionSigned() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    static func transactionRejected() {
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }

    static func sessionCreated() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred(intensity: 0.6)
    }

    static func otpDigitEntered() {
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred(intensity: 0.4)
    }

    static func otpComplete() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    static func buttonTap() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred(intensity: 0.5)
    }

    static func sheetPresented() {
        UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: 0.4)
    }

    static func walletSelected() {
        UISelectionFeedbackGenerator().selectionChanged()
    }
}
