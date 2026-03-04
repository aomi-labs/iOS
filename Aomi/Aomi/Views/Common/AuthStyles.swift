import SwiftUI
import UIKit

// MARK: - Aomi Colors

enum AomiColors {
    static let accent = Color.blue
    static let accentGreen = Color(red: 0.2, green: 0.78, blue: 0.35)

    static let labelPrimary = Color(UIColor.label)
    static let labelSecondary = Color(UIColor.secondaryLabel)
    static let labelTertiary = Color(UIColor.tertiaryLabel)

    static let backgroundPrimary = Color(UIColor.systemGroupedBackground)
    static let backgroundSecondary = Color(UIColor.secondarySystemGroupedBackground)

    static let fillTertiary = Color(UIColor.tertiarySystemFill)
    static let separator = Color(UIColor.separator)

    static let red = Color(UIColor.systemRed)
}

// MARK: - Aomi Button Style

struct AomiButtonStyle: ButtonStyle {
    var isEnabled: Bool = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 17, weight: .semibold))
            .foregroundColor(isEnabled ? .white : AomiColors.labelTertiary)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background {
                if isEnabled {
                    RoundedRectangle(cornerRadius: 28)
                        .fill(AomiColors.accent.opacity(0.85))
                } else {
                    RoundedRectangle(cornerRadius: 28)
                        .fill(AomiColors.fillTertiary)
                }
            }
            .glassEffect(
                isEnabled ? .regular.tint(.accentColor) : .regular,
                in: RoundedRectangle(cornerRadius: 28)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 28)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.3),
                                Color.white.opacity(0.08),
                                Color.white.opacity(0.02),
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 0.5
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(.spring(duration: 0.2, bounce: 0.3), value: configuration.isPressed)
    }
}

// MARK: - Aomi Border TextField

struct AomiBorderTextField: View {
    let placeholder: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default
    var textContentType: UITextContentType? = nil
    @FocusState private var isFocused: Bool

    var body: some View {
        TextField(placeholder, text: $text)
            .font(.system(size: 17))
            .foregroundColor(AomiColors.labelPrimary)
            .keyboardType(keyboardType)
            .textContentType(textContentType)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .focused($isFocused)
            .padding(.horizontal, 20)
            .frame(height: 56)
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(
                        isFocused ? AomiColors.accent : Color.clear,
                        lineWidth: isFocused ? 2 : 0
                    )
            )
            .animation(.spring(duration: 0.25, bounce: 0.2), value: isFocused)
    }
}

// MARK: - Auth Segmented Control

struct AuthSegmentedControl: View {
    @Binding var selectedIndex: Int
    let options: [String]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(options.indices, id: \.self) { index in
                Button {
                    HapticEngine.selectionTick()
                    withAnimation(.spring(duration: 0.25, bounce: 0.15)) {
                        selectedIndex = index
                    }
                } label: {
                    Text(options[index])
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(
                            selectedIndex == index
                                ? AomiColors.labelPrimary
                                : AomiColors.labelSecondary
                        )
                        .frame(maxWidth: .infinity)
                        .frame(height: 36)
                        .background {
                            if selectedIndex == index {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(AomiColors.backgroundSecondary)
                            }
                        }
                }
            }
        }
        .padding(4)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - OTP Digit Box

struct OTPDigitBox: View {
    let digit: String
    let isFocused: Bool

    var body: some View {
        Text(digit.isEmpty ? "" : digit)
            .font(.system(size: 24, weight: .semibold, design: .monospaced))
            .foregroundColor(AomiColors.labelPrimary)
            .frame(width: 48, height: 56)
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(
                        isFocused ? AomiColors.accent : Color.clear,
                        lineWidth: isFocused ? 2 : 0
                    )
            )
            .scaleEffect(digit.isEmpty ? 1.0 : 1.05)
            .animation(.spring(duration: 0.2, bounce: 0.3), value: digit)
    }
}

// MARK: - Resend OTP Button

struct ResendOTPButton: View {
    let remainingSeconds: Int
    let action: () -> Void

    var body: some View {
        Button {
            HapticEngine.lightTap()
            action()
        } label: {
            if remainingSeconds > 0 {
                Text("Resend in \(remainingSeconds)s")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(AomiColors.labelTertiary)
            } else {
                Text("Resend code")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(AomiColors.accent)
            }
        }
        .disabled(remainingSeconds > 0)
    }
}
