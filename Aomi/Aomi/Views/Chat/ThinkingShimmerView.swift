import SwiftUI

struct ThinkingShimmerView: View {
    let label: String
    @State private var shimmerOffset: CGFloat = -1
    @State private var hasAppeared = false

    private let dotCount = 3
    private let dotSize: CGFloat = 5
    private let dotSpacing: CGFloat = 6
    private let waveDuration: Double = 1.8

    var body: some View {
        HStack(spacing: 10) {
            // Breathing wave dots driven by real time so sin() actually animates
            TimelineView(.animation) { context in
                let phase = context.date.timeIntervalSinceReferenceDate * (.pi * 2 / waveDuration)
                HStack(spacing: dotSpacing) {
                    ForEach(0..<dotCount, id: \.self) { index in
                        BreathingDot(
                            phase: phase,
                            index: index,
                            size: dotSize
                        )
                    }
                }
            }

            // Shimmer label
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.tail)
                .overlay(shimmerGradient)
                .mask(
                    Text(label)
                        .font(.caption)
                        .lineLimit(1)
                        .truncationMode(.tail)
                )
                .contentTransition(.numericText())
                .animation(.easeInOut(duration: 0.25), value: label)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .glassEffect(.regular, in: .capsule)
        .opacity(hasAppeared ? 1 : 0)
        .scaleEffect(hasAppeared ? 1 : 0.9)
        .onAppear {
            HapticEngine.thinkingStarted()

            withAnimation(.easeOut(duration: 0.35)) {
                hasAppeared = true
            }

            withAnimation(.linear(duration: 2.5).repeatForever(autoreverses: false)) {
                shimmerOffset = 2
            }
        }
    }

    private var shimmerGradient: some View {
        GeometryReader { geo in
            LinearGradient(
                colors: [.clear, .white.opacity(0.5), .clear],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: geo.size.width * 0.35)
            .offset(x: geo.size.width * shimmerOffset)
        }
    }
}

// MARK: - Breathing Dot

private struct BreathingDot: View {
    let phase: CGFloat
    let index: Int
    let size: CGFloat

    private var phaseOffset: CGFloat {
        CGFloat(index) * (.pi * 2 / 3)
    }

    private var progress: CGFloat {
        (sin(phase + phaseOffset) + 1) / 2 // 0...1
    }

    var body: some View {
        Circle()
            .fill(Color.accentColor.opacity(0.4 + progress * 0.6))
            .frame(width: size, height: size)
            .scaleEffect(0.7 + progress * 0.5)
            .offset(y: -progress * 3)
            .shadow(color: .accentColor.opacity(progress * 0.4), radius: progress * 4)
    }
}
