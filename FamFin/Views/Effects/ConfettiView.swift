import SwiftUI

/// A reusable confetti particle effect overlay for celebrating milestones.
///
/// Uses `Canvas` + `TimelineView` for performant rendering.
/// Respects `accessibilityReduceMotion` by skipping the animation entirely.
/// Auto-dismisses after approximately 3 seconds.
///
/// Usage:
/// ```swift
/// .overlay {
///     if showConfetti {
///         ConfettiView { showConfetti = false }
///     }
/// }
/// ```
struct ConfettiView: View {
    /// Called when the animation completes so the parent can remove the overlay.
    var onComplete: (() -> Void)?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var particles: [ConfettiParticle] = []
    @State private var startTime: Date = .now

    /// Total animation duration in seconds.
    private let duration: TimeInterval = 3.0
    /// Number of confetti particles to generate.
    private let particleCount = 60

    var body: some View {
        if reduceMotion {
            // Accessibility: skip animation and auto-dismiss
            Color.clear
                .task {
                    try? await Task.sleep(for: .seconds(0.5))
                    onComplete?()
                }
        } else {
            TimelineView(.animation) { (timeline: TimelineViewDefaultContext) in
                let elapsed = timeline.date.timeIntervalSince(startTime)
                let progress = min(elapsed / duration, 1.0)

                Canvas { context, size in
                    for particle in particles {
                        let state = particle.position(at: progress, in: size)
                        guard state.opacity > 0 else { continue }

                        context.opacity = state.opacity
                        context.translateBy(x: state.x, y: state.y)
                        context.rotate(by: .degrees(state.rotation))
                        context.scaleBy(x: state.scaleX, y: 1.0)

                        let rect = CGRect(
                            x: -particle.size / 2,
                            y: -particle.size / 2,
                            width: particle.size,
                            height: particle.size
                        )

                        switch particle.shape {
                        case .circle:
                            context.fill(
                                Circle().path(in: rect),
                                with: .color(particle.color)
                            )
                        case .square:
                            context.fill(
                                Rectangle().path(in: rect),
                                with: .color(particle.color)
                            )
                        case .triangle:
                            let path = trianglePath(in: rect)
                            context.fill(path, with: .color(particle.color))
                        case .strip:
                            let stripRect = CGRect(
                                x: -particle.size / 4,
                                y: -particle.size / 2,
                                width: particle.size / 2,
                                height: particle.size
                            )
                            context.fill(
                                Rectangle().path(in: stripRect),
                                with: .color(particle.color)
                            )
                        }

                        // Reset transform for next particle
                        context.scaleBy(x: 1.0 / state.scaleX, y: 1.0)
                        context.rotate(by: .degrees(-state.rotation))
                        context.translateBy(x: -state.x, y: -state.y)
                        context.opacity = 1.0
                    }
                }
                .allowsHitTesting(false)
                .onChange(of: progress >= 1.0) { _, finished in
                    if finished {
                        onComplete?()
                    }
                }
            }
            .onAppear {
                startTime = .now
                particles = (0..<particleCount).map { _ in ConfettiParticle.random() }
            }
            .ignoresSafeArea()
        }
    }

    /// Creates a triangle path centered in the given rect.
    private func trianglePath(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

// MARK: - Particle Model

/// Represents a single confetti particle with randomised properties.
private struct ConfettiParticle {
    enum Shape: CaseIterable {
        case circle, square, triangle, strip
    }

    let color: Color
    let shape: Shape
    let size: CGFloat

    /// Normalised horizontal start position (0...1).
    let startX: CGFloat
    /// Horizontal drift factor.
    let driftX: CGFloat
    /// Base rotation speed in degrees per progress unit.
    let rotationSpeed: Double
    /// Initial rotation offset.
    let rotationOffset: Double
    /// Horizontal wobble amplitude.
    let wobbleAmplitude: CGFloat
    /// Wobble frequency multiplier.
    let wobbleFrequency: CGFloat
    /// Initial upward burst velocity (normalised).
    let burstVelocity: CGFloat
    /// Random 3D tumble factor for scaleX oscillation.
    let tumbleSpeed: Double

    struct ParticleState {
        let x: CGFloat
        let y: CGFloat
        let rotation: Double
        let opacity: Double
        let scaleX: CGFloat
    }

    /// Calculate the particle's visual state at a given progress (0...1).
    func position(at progress: Double, in size: CGSize) -> ParticleState {
        let t = CGFloat(progress)

        // Vertical: burst upward then fall with gravity
        let gravity: CGFloat = 2.5
        let yNorm = -burstVelocity * t + gravity * t * t
        let y = yNorm * size.height

        // Horizontal: start position + drift + sinusoidal wobble
        let wobble = wobbleAmplitude * sin(t * .pi * 2 * wobbleFrequency)
        let x = startX * size.width + driftX * t * size.width * 0.3 + wobble * size.width * 0.05

        let rotation = rotationOffset + rotationSpeed * progress
        let opacity: Double = progress < 0.7 ? 1.0 : max(0, 1.0 - (progress - 0.7) / 0.3)
        let scaleX = max(0.3, CGFloat(abs(cos(tumbleSpeed * progress * .pi * 2))))

        return ParticleState(x: x, y: y, rotation: rotation, opacity: opacity, scaleX: scaleX)
    }

    static func random() -> ConfettiParticle {
        let colors: [Color] = [.red, .orange, .yellow, .green, .blue, .purple, .pink, .mint, .cyan, .indigo]
        return ConfettiParticle(
            color: colors.randomElement() ?? .red,
            shape: Shape.allCases.randomElement() ?? .circle,
            size: CGFloat.random(in: 6...14),
            startX: CGFloat.random(in: 0.1...0.9),
            driftX: CGFloat.random(in: -1.0...1.0),
            rotationSpeed: Double.random(in: 180...720),
            rotationOffset: Double.random(in: 0...360),
            wobbleAmplitude: CGFloat.random(in: 0.5...2.0),
            wobbleFrequency: CGFloat.random(in: 1.0...3.0),
            burstVelocity: CGFloat.random(in: 0.6...1.2),
            tumbleSpeed: Double.random(in: 1.0...3.0)
        )
    }
}

#Preview {
    ZStack {
        Color(.systemBackground)
        Text("Milestone Reached!")
            .font(.largeTitle.bold())
        ConfettiView()
    }
}
