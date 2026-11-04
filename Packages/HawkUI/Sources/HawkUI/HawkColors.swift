import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

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
/// Restrained, premium, and distraction-free with instant Light/Dark appearance switching.
public enum HawkTheme {

    // MARK: - Core Palette Constants (Exact Hex)
    // Dark Palette (AMOLED-friendly minimal)
    public static let amoledBackgroundHex: UInt32 = 0x08090B
    public static let amoledNavigationHex: UInt32 = 0x101114
    public static let amoledElevatedSurfaceHex: UInt32 = 0x17191D
    public static let amoledSecondarySurfaceHex: UInt32 = 0x1D2025
    public static let amoledTextPrimaryHex: UInt32 = 0xF4F3F0
    public static let amoledTextSecondaryHex: UInt32 = 0xA3A5AA
    public static let amoledTextTertiaryHex: UInt32 = 0x777A82
    public static let amoledAccentHex: UInt32 = 0x8878B5
    public static let amoledDividerHex: UInt32 = 0x292C32

    // Light Palette
    public static let lightBackgroundHex: UInt32 = 0xF7F7F5
    public static let lightNavigationHex: UInt32 = 0xFFFFFF
    public static let lightElevatedSurfaceHex: UInt32 = 0xFFFFFF
    public static let lightSecondarySurfaceHex: UInt32 = 0xF0F0EE
    public static let lightTextPrimaryHex: UInt32 = 0x17181B
    public static let lightTextSecondaryHex: UInt32 = 0x666970
    public static let lightTextTertiaryHex: UInt32 = 0x858890
    public static let lightAccentHex: UInt32 = 0x6F5B9C
    public static let lightDividerHex: UInt32 = 0xE5E5E2

    // MARK: - Dynamic Semantic Colors (Automatically react to system appearance)
    /// Main application canvas: #08090B (Dark) / #F7F7F5 (Light)
    public static let background: Color = dynamicColor(
        light: colorFromHex(lightBackgroundHex),
        dark: colorFromHex(amoledBackgroundHex)
    )

    /// Main bottom navigation surface: #101114 (Dark) / #FFFFFF (Light)
    public static let navigationBackground: Color = dynamicColor(
        light: colorFromHex(lightNavigationHex),
        dark: colorFromHex(amoledNavigationHex)
    )

    /// Elevated surfaces and card containers: #17191D (Dark) / #FFFFFF (Light)
    public static let cardBackground: Color = dynamicColor(
        light: colorFromHex(lightElevatedSurfaceHex),
        dark: colorFromHex(amoledElevatedSurfaceHex)
    )

    /// Secondary surfaces, input backgrounds, chips: #1D2025 (Dark) / #F0F0EE (Light)
    public static let secondarySurface: Color = dynamicColor(
        light: colorFromHex(lightSecondarySurfaceHex),
        dark: colorFromHex(amoledSecondarySurfaceHex)
    )

    /// High contrast, fully readable primary text: #F4F3F0 (Dark) / #17181B (Light)
    public static let textPrimary: Color = dynamicColor(
        light: colorFromHex(lightTextPrimaryHex),
        dark: colorFromHex(amoledTextPrimaryHex)
    )

    /// Reduced emphasis secondary text: #A3A5AA (Dark) / #666970 (Light)
    public static let textSecondary: Color = dynamicColor(
        light: colorFromHex(lightTextSecondaryHex),
        dark: colorFromHex(amoledTextSecondaryHex)
    )

    /// Subtle metadata & captions: #777A82 (Dark) / #858890 (Light)
    public static let textTertiary: Color = dynamicColor(
        light: colorFromHex(lightTextTertiaryHex),
        dark: colorFromHex(amoledTextTertiaryHex)
    )

    /// Key action accent: #8878B5 (Dark) / #6F5B9C (Light)
    public static let primaryAccent: Color = dynamicColor(
        light: colorFromHex(lightAccentHex),
        dark: colorFromHex(amoledAccentHex)
    )

    /// Secondary accent highlight
    public static let secondaryAccent: Color = dynamicColor(
        light: colorFromHex(lightTextSecondaryHex),
        dark: colorFromHex(amoledTextSecondaryHex)
    )

    /// Surface separators and hairline dividers: #292C32 (Dark) / #E5E5E2 (Light)
    public static let dividerColor: Color = dynamicColor(
        light: colorFromHex(lightDividerHex),
        dark: colorFromHex(amoledDividerHex)
    )

    // MARK: - Backwards Compatibility Aliases
    public static let darkBackground = background
    public static let lightBackground = colorFromHex(lightBackgroundHex)
    public static let cardBackgroundLight = colorFromHex(lightSecondarySurfaceHex)
    public static let logoColor = textPrimary
    public static let glassMaterial = Material.ultraThinMaterial

    public static let accentGradient = LinearGradient(
        colors: [primaryAccent, primaryAccent.opacity(0.85)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    // MARK: - Color Utilities
    public static func colorFromHex(_ hex: UInt32, alpha: Double = 1.0) -> Color {
        let r = Double((hex >> 16) & 0xff) / 255.0
        let g = Double((hex >> 8) & 0xff) / 255.0
        let b = Double(hex & 0xff) / 255.0
        return Color(red: r, green: g, blue: b, opacity: alpha)
    }

    private static func dynamicColor(light: Color, dark: Color) -> Color {
        #if canImport(UIKit)
        return Color(uiColor: UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light)
        })
        #else
        return dark
        #endif
    }

    // MARK: - Explicit Theme Adapters
    public static func adaptiveBackground(for scheme: ColorScheme) -> Color {
        scheme == .light ? colorFromHex(lightBackgroundHex) : colorFromHex(amoledBackgroundHex)
    }

    public static func adaptiveCardBackground(for scheme: ColorScheme) -> Color {
        scheme == .light ? colorFromHex(lightElevatedSurfaceHex) : colorFromHex(amoledElevatedSurfaceHex)
    }

    public static func adaptiveTextPrimary(for scheme: ColorScheme) -> Color {
        scheme == .light ? colorFromHex(lightTextPrimaryHex) : colorFromHex(amoledTextPrimaryHex)
    }

    public static func adaptiveDivider(for scheme: ColorScheme) -> Color {
        scheme == .light ? colorFromHex(lightDividerHex) : colorFromHex(amoledDividerHex)
    }

    // MARK: - Native iOS System Bar Styling
    public static func configureSystemAppearance() {
        #if canImport(UIKit)
        // Configure Native UITabBar
        let tabAppearance = UITabBarAppearance()
        tabAppearance.configureWithOpaqueBackground()
        tabAppearance.backgroundColor = UIColor { tc in
            tc.userInterfaceStyle == .dark
                ? UIColor(red: 16/255.0, green: 17/255.0, blue: 20/255.0, alpha: 1.0)
                : UIColor.white
        }

        let normalColor = UIColor { tc in
            tc.userInterfaceStyle == .dark
                ? UIColor(red: 163/255.0, green: 165/255.0, blue: 170/255.0, alpha: 1.0)
                : UIColor(red: 102/255.0, green: 105/255.0, blue: 112/255.0, alpha: 1.0)
        }
        let selectedColor = UIColor { tc in
            tc.userInterfaceStyle == .dark
                ? UIColor(red: 136/255.0, green: 120/255.0, blue: 181/255.0, alpha: 1.0)
                : UIColor(red: 111/255.0, green: 91/255.0, blue: 156/255.0, alpha: 1.0)
        }

        for layout in [tabAppearance.stackedLayoutAppearance, tabAppearance.inlineLayoutAppearance, tabAppearance.compactInlineLayoutAppearance] {
            layout.normal.iconColor = normalColor
            layout.normal.titleTextAttributes = [.foregroundColor: normalColor]
            layout.selected.iconColor = selectedColor
            layout.selected.titleTextAttributes = [.foregroundColor: selectedColor]
        }

        UITabBar.appearance().standardAppearance = tabAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabAppearance

        // Configure Native UINavigationBar
        let navAppearance = UINavigationBarAppearance()
        navAppearance.configureWithTransparentBackground()
        navAppearance.largeTitleTextAttributes = [
            .foregroundColor: UIColor { tc in
                tc.userInterfaceStyle == .dark
                    ? UIColor(red: 244/255.0, green: 243/255.0, blue: 240/255.0, alpha: 1.0)
                    : UIColor(red: 23/255.0, green: 24/255.0, blue: 27/255.0, alpha: 1.0)
            }
        ]
        navAppearance.titleTextAttributes = [
            .foregroundColor: UIColor { tc in
                tc.userInterfaceStyle == .dark
                    ? UIColor(red: 244/255.0, green: 243/255.0, blue: 240/255.0, alpha: 1.0)
                    : UIColor(red: 23/255.0, green: 24/255.0, blue: 27/255.0, alpha: 1.0)
            }
        ]
        UINavigationBar.appearance().standardAppearance = navAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navAppearance
        #endif
    }
}

// MARK: - Native Apple-grade Liquid Glass surface modifier
public struct HawkLiquidGlassModifier: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) var reduceTransparency
    @Environment(\.colorScheme) var colorScheme
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
                            .fill(HawkTheme.cardBackground.opacity(colorScheme == .dark ? 0.80 : 0.90))
                            .background(.ultraThinMaterial)
                    }
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: colorScheme == .dark ? [
                                Color.white.opacity(strokeOpacity),
                                Color.white.opacity(strokeOpacity * 0.4),
                                Color.clear,
                                Color.white.opacity(strokeOpacity * 0.15)
                            ] : [
                                Color.black.opacity(strokeOpacity * 0.3),
                                Color.black.opacity(strokeOpacity * 0.15),
                                Color.clear,
                                Color.black.opacity(strokeOpacity * 0.08)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.8
                    )
            )
            .shadow(
                color: colorScheme == .dark ? Color.black.opacity(0.30) : Color.black.opacity(0.06),
                radius: 12,
                x: 0,
                y: 5
            )
    }
}

// MARK: - Interactive Spring Press Feedback
public struct HawkInteractivePressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.97 : 1.0)
            .opacity(configuration.isPressed ? 0.90 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.75), value: configuration.isPressed)
    }
}

// MARK: - View Extensions
public extension View {
    func hawkLiquidGlass(cornerRadius: CGFloat = 16, strokeOpacity: Double = 0.20) -> some View {
        self.modifier(HawkLiquidGlassModifier(cornerRadius: cornerRadius, strokeOpacity: strokeOpacity))
    }

    func hawkPressEffect() -> some View {
        self.buttonStyle(HawkInteractivePressStyle())
    }

    // MARK: - SF Pro Typography Hierarchy
    func hawkTitle() -> some View {
        self.font(.system(size: 28, weight: .bold, design: .default))
            .foregroundColor(HawkTheme.textPrimary)
    }

    func hawkSectionHeader() -> some View {
        self.font(.system(size: 20, weight: .semibold, design: .default))
            .foregroundColor(HawkTheme.textPrimary)
    }

    func hawkCardTitle() -> some View {
        self.font(.system(size: 16, weight: .medium, design: .default))
            .foregroundColor(HawkTheme.textPrimary)
    }

    func hawkSubtitle() -> some View {
        self.font(.system(size: 14, weight: .regular, design: .default))
            .foregroundColor(HawkTheme.textSecondary)
    }

    func hawkCaption() -> some View {
        self.font(.system(size: 12, weight: .regular, design: .default))
            .foregroundColor(HawkTheme.textTertiary)
    }
}
