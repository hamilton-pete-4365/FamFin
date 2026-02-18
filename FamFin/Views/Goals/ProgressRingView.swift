import SwiftUI

/// A reusable circular progress ring that animates its fill on appear.
/// Respects `accessibilityReduceMotion` to skip animations when needed.
struct ProgressRingView: View {
    /// Progress value from 0.0 to 1.0
    let progress: Double
    /// The color of the filled portion of the ring
    var color: Color = .accentColor
    /// Line width of the ring stroke
    var lineWidth: CGFloat = 8

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var animatedProgress: Double = 0

    var body: some View {
        ZStack {
            // Background ring (track)
            Circle()
                .stroke(color.opacity(0.15), lineWidth: lineWidth)

            // Foreground ring (progress)
            Circle()
                .trim(from: 0, to: animatedProgress)
                .stroke(
                    color,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
        }
        .onAppear {
            if reduceMotion {
                animatedProgress = progress
            } else {
                withAnimation(.easeOut(duration: 0.8)) {
                    animatedProgress = progress
                }
            }
        }
        .onChange(of: progress) { _, newValue in
            if reduceMotion {
                animatedProgress = newValue
            } else {
                withAnimation(.easeOut(duration: 0.4)) {
                    animatedProgress = newValue
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityValue(Text("\(Int(progress * 100)) percent"))
        .accessibilityLabel("Progress")
    }
}

#Preview {
    VStack(spacing: 40) {
        ProgressRingView(progress: 0.75, color: .blue)
            .frame(width: 100, height: 100)

        ProgressRingView(progress: 0.33, color: .orange, lineWidth: 12)
            .frame(width: 60, height: 60)

        ProgressRingView(progress: 1.0, color: .green)
            .frame(width: 40, height: 40)
    }
    .padding()
}
