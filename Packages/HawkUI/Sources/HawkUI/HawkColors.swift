import SwiftUI

/// Original HAWK Design System color palette and visual styling.
public enum HawkTheme {
    public static let primaryAccent = Color(red: 1.0, green: 0.22, blue: 0.37) // HAWK Vibrant Coral
    public static let secondaryAccent = Color(red: 0.95, green: 0.35, blue: 0.25) // Ember warmth
    public static let darkBackground = Color(red: 0.05, green: 0.05, blue: 0.07) // Deep OLED Charcoal
    public static let cardBackground = Color(red: 0.11, green: 0.12, blue: 0.15)
    public static let textPrimary = Color.white
    public static let textSecondary = Color(white: 0.72)
    public static let textTertiary = Color(white: 0.48)

    public static let accentGradient = LinearGradient(
        colors: [primaryAccent, secondaryAccent],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    public static let glassMaterial = Material.ultraThinMaterial
}

/// Native Apple-grade Liquid Glass surface modifier with natural lighting and accessibility fallbacks.
public struct HawkLiquidGlassModifier: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) var reduceTransparency
    public var cornerRadius: CGFloat = 16
    public var strokeOpacity: Double = 0.20
    public var interactive: Bool = false

    public func body(content: Content) -> some View {
        content
            .background(
                Group {
                    if reduceTransparency {
                        HawkTheme.cardBackground
                    } else {
                        Rectangle()
                            .fill(.ultraThinMaterial)
                    }
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(strokeOpacity),
                                Color.white.opacity(strokeOpacity * 0.4),
                                Color.clear,
                                Color.white.opacity(strokeOpacity * 0.15)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.8
                    )
            )
            .shadow(color: Color.black.opacity(0.30), radius: 14, x: 0, y: 6)
    }
}

/// Spring interactive card press feedback.
public struct HawkInteractivePressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.97 : 1.0)
            .opacity(configuration.isPressed ? 0.92 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.75), value: configuration.isPressed)
    }
}

public extension View {
    func hawkLiquidGlass(cornerRadius: CGFloat = 16, strokeOpacity: Double = 0.20) -> some View {
        self.modifier(HawkLiquidGlassModifier(cornerRadius: cornerRadius, strokeOpacity: strokeOpacity))
    }

    func hawkPressEffect() -> some View {
        self.buttonStyle(HawkInteractivePressStyle())
    }
}
