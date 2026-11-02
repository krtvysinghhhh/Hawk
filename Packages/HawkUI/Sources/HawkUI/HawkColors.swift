import SwiftUI

/// Original HAWK Design System color palette and visual styling.
public enum HawkTheme {
    public static let primaryAccent = Color(red: 0.95, green: 0.35, blue: 0.25) // Vibrant Hawk Ember
    public static let secondaryAccent = Color(red: 0.85, green: 0.20, blue: 0.40)
    public static let darkBackground = Color(red: 0.06, green: 0.07, blue: 0.09)
    public static let cardBackground = Color(red: 0.12, green: 0.13, blue: 0.16)
    public static let textPrimary = Color.white
    public static let textSecondary = Color(white: 0.70)
    public static let textTertiary = Color(white: 0.45)

    public static let accentGradient = LinearGradient(
        colors: [primaryAccent, secondaryAccent],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    public static let glassMaterial = Material.ultraThinMaterial
}
