import SwiftUI

/// Supported user appearance preferences with automatic system following.
public enum AppearanceMode: String, CaseIterable, Identifiable, Codable, Sendable {
    case system = "System"
    case light = "Light"
    case dark = "Dark"

    public var id: String { rawValue }

    public var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

/// Official HAWK Minimalist Design System palette.
/// Restrained, premium, and distraction-free.
public enum HawkTheme {
    /// Official Muted Violet Accent (#7867A8) — used selectively for key states & indicators.
    public static let primaryAccent = Color(red: 120/255.0, green: 103/255.0, blue: 168/255.0)
    
    /// Secondary accent / subtle highlight
    public static let secondaryAccent = Color(red: 150/255.0, green: 150/255.0, blue: 157/255.0)

    /// Primary background: Near-black #0B0B0D
    public static let darkBackground = Color(red: 11/255.0, green: 11/255.0, blue: 13/255.0)

    /// Secondary background / card surfaces: #151518
    public static let cardBackground = Color(red: 21/255.0, green: 21/255.0, blue: 24/255.0)

    /// Light appearance warm white: #F7F7F5
    public static let lightBackground = Color(red: 247/255.0, green: 247/255.0, blue: 245/255.0)

    /// Light card surface
    public static let cardBackgroundLight = Color(red: 238/255.0, green: 238/255.0, blue: 235/255.0)

    /// Primary logo & primary text: Soft ivory #F2F0EB
    public static let logoColor = Color(red: 242/255.0, green: 240/255.0, blue: 235/255.0)
    public static let textPrimary = Color(red: 242/255.0, green: 240/255.0, blue: 235/255.0)

    /// Secondary text: #96969D
    public static let textSecondary = Color(red: 150/255.0, green: 150/255.0, blue: 157/255.0)

    /// Tertiary text: subtle captions
    public static let textTertiary = Color(red: 110/255.0, green: 110/255.0, blue: 119/255.0)

    /// Dividers: #29292F
    public static let dividerColor = Color(red: 41/255.0, green: 41/255.0, blue: 47/255.0)

    public static let accentGradient = LinearGradient(
        colors: [primaryAccent, primaryAccent.opacity(0.85)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    public static let glassMaterial = Material.ultraThinMaterial

    // MARK: - Dynamic Theme Adapters
    public static func adaptiveBackground(for scheme: ColorScheme) -> Color {
        scheme == .light ? lightBackground : darkBackground
    }

    public static func adaptiveCardBackground(for scheme: ColorScheme) -> Color {
        scheme == .light ? cardBackgroundLight : cardBackground
    }

    public static func adaptiveTextPrimary(for scheme: ColorScheme) -> Color {
        scheme == .light ? Color(red: 11/255.0, green: 11/255.0, blue: 13/255.0) : textPrimary
    }

    public static func adaptiveDivider(for scheme: ColorScheme) -> Color {
        scheme == .light ? Color.black.opacity(0.12) : dividerColor
    }
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
