import SwiftUI
import HawkCore
import HawkPlayback
import HawkSources

// MARK: - HAWK Design System Tokens

/// Strict typography scale based on Apple SF Pro.
public enum HawkTypography {
    public static let largeTitle = Font.system(size: 34, weight: .bold, design: .default)
    public static let title1 = Font.system(size: 28, weight: .bold, design: .default)
    public static let title2 = Font.system(size: 22, weight: .bold, design: .default)
    public static let title3 = Font.system(size: 20, weight: .semibold, design: .default)
    public static let headline = Font.system(size: 17, weight: .semibold, design: .default)
    public static let body = Font.system(size: 17, weight: .regular, design: .default)
    public static let callout = Font.system(size: 16, weight: .regular, design: .default)
    public static let subheadline = Font.system(size: 15, weight: .regular, design: .default)
    public static let footnote = Font.system(size: 13, weight: .regular, design: .default)
    public static let caption1 = Font.system(size: 12, weight: .regular, design: .default)
    public static let caption2 = Font.system(size: 11, weight: .regular, design: .default)
}

/// Spacing scale (4pt baseline grid).
public enum HawkSpacing {
    public static let xxs: CGFloat = 4
    public static let xs: CGFloat = 8
    public static let sm: CGFloat = 12
    public static let md: CGFloat = 16
    public static let lg: CGFloat = 20
    public static let xl: CGFloat = 24
    public static let xxl: CGFloat = 32
    public static let huge: CGFloat = 40
}

/// Border and corner radius scale.
public enum HawkRadius {
    public static let xs: CGFloat = 4
    public static let sm: CGFloat = 8
    public static let md: CGFloat = 12
    public static let lg: CGFloat = 16
    public static let xl: CGFloat = 20
    public static let pill: CGFloat = 9999
}

// MARK: - Reusable Functional SwiftUI Components

// 1. HawkButton
public struct HawkButton: View {
    public enum Style: Sendable {
        case primary
        case secondary
        case ghost
        case destructive
    }

    public enum Size: Sendable {
        case small
        case medium
        case large

        var verticalPadding: CGFloat {
            switch self {
            case .small: return 8
            case .medium: return 12
            case .large: return 16
            }
        }

        var horizontalPadding: CGFloat {
            switch self {
            case .small: return 12
            case .medium: return 20
            case .large: return 24
            }
        }

        var font: Font {
            switch self {
            case .small: return HawkTypography.footnote.weight(.semibold)
            case .medium: return HawkTypography.subheadline.weight(.semibold)
            case .large: return HawkTypography.headline
            }
        }

        var cornerRadius: CGFloat {
            switch self {
            case .small: return HawkRadius.sm
            case .medium: return HawkRadius.md
            case .large: return HawkRadius.lg
            }
        }
    }

    private let title: String
    private let icon: String?
    private let style: Style
    private let size: Size
    private let isLoading: Bool
    private let isFullWidth: Bool
    private let action: () -> Void

    public init(
        _ title: String,
        icon: String? = nil,
        style: Style = .primary,
        size: Size = .medium,
        isLoading: Bool = false,
        isFullWidth: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.style = style
        self.size = size
        self.isLoading = isLoading
        self.isFullWidth = isFullWidth
        self.action = action
    }

    private var backgroundColor: Color {
        switch style {
        case .primary:
            return HawkTheme.primaryAccent
        case .secondary:
            return HawkTheme.cardBackground
        case .ghost:
            return Color.clear
        case .destructive:
            return Color.red.opacity(0.85)
        }
    }

    private var foregroundColor: Color {
        switch style {
        case .primary:
            return Color.white
        case .secondary:
            return HawkTheme.textPrimary
        case .ghost:
            return HawkTheme.textPrimary
        case .destructive:
            return Color.white
        }
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: HawkSpacing.xs) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: foregroundColor))
                        .scaleEffect(0.8)
                } else if let icon {
                    Image(systemName: icon)
                        .font(size.font)
                }

                Text(title)
                    .font(size.font)
            }
            .foregroundColor(foregroundColor)
            .padding(.vertical, size.verticalPadding)
            .padding(.horizontal, size.horizontalPadding)
            .frame(maxWidth: isFullWidth ? .infinity : nil)
            .background(backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: size.cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: size.cornerRadius, style: .continuous)
                    .stroke(
                        style == .secondary ? HawkTheme.dividerColor : Color.clear,
                        lineWidth: 1
                    )
            )
        }
        .disabled(isLoading)
        .hawkPressEffect()
    }
}

// 2. HawkIconButton
public struct HawkIconButton: View {
    public enum Size: Sendable {
        case small    // 32x32
        case medium   // 40x40
        case large    // 48x48

        var dimension: CGFloat {
            switch self {
            case .small: return 32
            case .medium: return 40
            case .large: return 48
            }
        }

        var iconSize: CGFloat {
            switch self {
            case .small: return 14
            case .medium: return 18
            case .large: return 22
            }
        }
    }

    public enum Variant: Sendable {
        case plain
        case filled
        case tinted
    }

    private let icon: String
    private let size: Size
    private let variant: Variant
    private let tint: Color?
    private let action: () -> Void

    public init(
        icon: String,
        size: Size = .medium,
        variant: Variant = .plain,
        tint: Color? = nil,
        action: @escaping () -> Void
    ) {
        self.icon = icon
        self.size = size
        self.variant = variant
        self.tint = tint
        self.action = action
    }

    private var effectiveTint: Color {
        tint ?? HawkTheme.textPrimary
    }

    public var body: some View {
        Button(action: action) {
            ZStack {
                switch variant {
                case .plain:
                    Color.clear
                case .filled:
                    HawkTheme.cardBackground
                case .tinted:
                    effectiveTint.opacity(0.15)
                }

                Image(systemName: icon)
                    .font(.system(size: size.iconSize, weight: .semibold))
                    .foregroundColor(effectiveTint)
            }
            .frame(width: size.dimension, height: size.dimension)
            .clipShape(Circle())
            .overlay(
                Circle()
                    .stroke(variant == .filled ? HawkTheme.dividerColor : Color.clear, lineWidth: 0.8)
            )
        }
        .hawkPressEffect()
    }
}

// 3. HawkCard
public struct HawkCard<Content: View>: View {
    private let cornerRadius: CGFloat
    private let padding: CGFloat
    private let content: Content

    public init(
        cornerRadius: CGFloat = HawkRadius.lg,
        padding: CGFloat = HawkSpacing.md,
        @ViewBuilder content: () -> Content
    ) {
        self.cornerRadius = cornerRadius
        self.padding = padding
        self.content = content()
    }

    public var body: some View {
        content
            .padding(padding)
            .background(HawkTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(HawkTheme.dividerColor, lineWidth: 0.8)
            )
    }
}

// 4. HawkArtwork
public struct HawkArtwork: View {
    private let url: URL?
    private let size: CGFloat
    private let cornerRadius: CGFloat

    public init(
        url: URL?,
        size: CGFloat = 52,
        cornerRadius: CGFloat = HawkRadius.md
    ) {
        self.url = url
        self.size = size
        self.cornerRadius = cornerRadius
    }

    public var body: some View {
        AsyncImage(url: url) { phase in
            switch phase {
            case .empty:
                placeholderView
            case .success(let image):
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: size, height: size)
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            case .failure:
                placeholderView
            @unknown default:
                placeholderView
            }
        }
        .frame(width: size, height: size)
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
        )
    }

    private var placeholderView: some View {
        ZStack {
            HawkTheme.secondarySurface
            Image(systemName: "music.note")
                .font(.system(size: size * 0.4, weight: .light))
                .foregroundColor(HawkTheme.textTertiary)
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}

// 5. HawkListRow
public struct HawkListRow<Leading: View, Trailing: View>: View {
    private let leading: Leading
    private let title: String
    private let subtitle: String?
    private let trailing: Trailing
    private let isSelected: Bool
    private let isSelectionMode: Bool
    private let onSelect: (() -> Void)?

    public init(
        title: String,
        subtitle: String? = nil,
        isSelected: Bool = false,
        isSelectionMode: Bool = false,
        onSelect: (() -> Void)? = nil,
        @ViewBuilder leading: () -> Leading,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.title = title
        self.subtitle = subtitle
        self.isSelected = isSelected
        self.isSelectionMode = isSelectionMode
        self.onSelect = onSelect
        self.leading = leading()
        self.trailing = trailing()
    }

    public var body: some View {
        HStack(spacing: HawkSpacing.md) {
            if isSelectionMode {
                Button {
                    onSelect?()
                } label: {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(isSelected ? HawkTheme.primaryAccent : HawkTheme.textTertiary)
                        .font(.system(size: 20))
                }
                .buttonStyle(.plain)
            }

            leading

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(HawkTypography.body.weight(.medium))
                    .foregroundColor(HawkTheme.textPrimary)
                    .lineLimit(1)

                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(HawkTypography.subheadline)
                        .foregroundColor(HawkTheme.textSecondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: HawkSpacing.sm)

            trailing
        }
        .padding(.vertical, HawkSpacing.xs)
        .contentShape(Rectangle())
    }
}

// 6. HawkSectionHeader
public struct HawkSectionHeader: View {
    private let title: String
    private let subtitle: String?
    private let actionTitle: String?
    private let action: (() -> Void)?

    public init(
        title: String,
        subtitle: String? = nil,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.title = title
        self.subtitle = subtitle
        self.actionTitle = actionTitle
        self.action = action
    }

    public var body: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(HawkTypography.title2)
                    .foregroundColor(HawkTheme.textPrimary)

                if let subtitle {
                    Text(subtitle)
                        .font(HawkTypography.subheadline)
                        .foregroundColor(HawkTheme.textSecondary)
                }
            }

            Spacer()

            if let actionTitle, let action {
                Button(action: action) {
                    Text(actionTitle)
                        .font(HawkTypography.subheadline.weight(.medium))
                        .foregroundColor(HawkTheme.primaryAccent)
                }
                .hawkPressEffect()
            }
        }
        .padding(.horizontal, HawkSpacing.lg)
        .padding(.vertical, HawkSpacing.xs)
    }
}

// 7. HawkSearchField
public struct HawkSearchField: View {
    @Binding private var text: String
    private let placeholder: String
    private let onClear: (() -> Void)?

    public init(
        text: Binding<String>,
        placeholder: String = "Search songs, artists, playlists...",
        onClear: (() -> Void)? = nil
    ) {
        self._text = text
        self.placeholder = placeholder
        self.onClear = onClear
    }

    public var body: some View {
        HStack(spacing: HawkSpacing.xs) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(HawkTheme.textTertiary)
                .font(.system(size: 16, weight: .medium))

            TextField(placeholder, text: $text)
                .font(HawkTypography.body)
                .foregroundColor(HawkTheme.textPrimary)
                .autocorrectionDisabled()

            if !text.isEmpty {
                Button {
                    text = ""
                    onClear?()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(HawkTheme.textTertiary)
                        .font(.system(size: 16))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 14)
        .background(HawkTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: HawkRadius.md, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: HawkRadius.md, style: .continuous)
                .stroke(HawkTheme.dividerColor, lineWidth: 0.8)
        )
    }
}

// 8. HawkContextMenu
public struct HawkContextMenuModifier: ViewModifier {
    let song: Song
    let playlistStore = PlaylistStore.shared
    let queueManager = QueueManager.shared
    let coordinator = PlaybackCoordinator.shared

    public func body(content: Content) -> some View {
        content.contextMenu {
            Button {
                coordinator.play(song: song)
            } label: {
                Label("Play Now", systemImage: "play")
            }

            Button {
                Task {
                    await queueManager.playNext(song: song)
                }
            } label: {
                Label("Play Next", systemImage: "text.line.first.and.arrowtriangle.forward")
            }

            Button {
                Task {
                    await queueManager.addToQueue(song: song)
                }
            } label: {
                Label("Add to Queue", systemImage: "text.badge.plus")
            }

            Divider()

            Button {
                Task {
                    let isFav = await playlistStore.isFavorite(songId: song.id)
                    if isFav {
                        await playlistStore.removeSong(from: Playlist.favoritesId, songId: song.id)
                    } else {
                        _ = await playlistStore.addSong(to: Playlist.favoritesId, song: song)
                    }
                }
            } label: {
                Label("Favorite", systemImage: "heart")
            }

            Divider()

            Button {
                Task {
                    try? await DownloadManager.shared.download(song: song)
                }
            } label: {
                Label("Download", systemImage: "arrow.down.circle")
            }
        }
    }
}

public extension View {
    func hawkSongContextMenu(song: Song) -> some View {
        self.modifier(HawkContextMenuModifier(song: song))
    }
}

// 9. HawkEmptyState
public struct HawkEmptyState: View {
    private let icon: String
    private let title: String
    private let message: String
    private let buttonTitle: String?
    private let buttonAction: (() -> Void)?

    public init(
        icon: String = "music.note.slash",
        title: String,
        message: String,
        buttonTitle: String? = nil,
        buttonAction: (() -> Void)? = nil
    ) {
        self.icon = icon
        self.title = title
        self.message = message
        self.buttonTitle = buttonTitle
        self.buttonAction = buttonAction
    }

    public var body: some View {
        VStack(spacing: HawkSpacing.md) {
            Image(systemName: icon)
                .font(.system(size: 48, weight: .light))
                .foregroundColor(HawkTheme.textTertiary)

            VStack(spacing: HawkSpacing.xxs) {
                Text(title)
                    .font(HawkTypography.headline)
                    .foregroundColor(HawkTheme.textPrimary)

                Text(message)
                    .font(HawkTypography.subheadline)
                    .foregroundColor(HawkTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, HawkSpacing.xxl)
            }

            if let buttonTitle, let buttonAction {
                HawkButton(buttonTitle, style: .secondary, size: .small, action: buttonAction)
                    .padding(.top, HawkSpacing.xs)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(HawkSpacing.xl)
    }
}

// 10. HawkLoadingState
public struct HawkLoadingState: View {
    private let message: String?

    public init(message: String? = nil) {
        self.message = message
    }

    public var body: some View {
        VStack(spacing: HawkSpacing.md) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: HawkTheme.primaryAccent))
                .scaleEffect(1.2)

            if let message {
                Text(message)
                    .font(HawkTypography.subheadline)
                    .foregroundColor(HawkTheme.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(HawkSpacing.xl)
    }
}

// 11. HawkErrorState
public struct HawkErrorState: View {
    private let title: String
    private let message: String
    private let retryAction: (() -> Void)?

    public init(
        title: String = "Something Went Wrong",
        message: String,
        retryAction: (() -> Void)? = nil
    ) {
        self.title = title
        self.message = message
        self.retryAction = retryAction
    }

    public var body: some View {
        VStack(spacing: HawkSpacing.md) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 44, weight: .light))
                .foregroundColor(.red.opacity(0.85))

            VStack(spacing: HawkSpacing.xxs) {
                Text(title)
                    .font(HawkTypography.headline)
                    .foregroundColor(HawkTheme.textPrimary)

                Text(message)
                    .font(HawkTypography.subheadline)
                    .foregroundColor(HawkTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, HawkSpacing.xxl)
            }

            if let retryAction {
                HawkButton("Try Again", icon: "arrow.clockwise", style: .secondary, size: .small, action: retryAction)
                    .padding(.top, HawkSpacing.xs)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(HawkSpacing.xl)
    }
}

// 12. HawkBottomSheet
public struct HawkBottomSheet<Content: View>: View {
    @Binding private var isPresented: Bool
    private let title: String?
    private let content: Content

    public init(
        isPresented: Binding<Bool>,
        title: String? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self._isPresented = isPresented
        self.title = title
        self.content = content()
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Drag Indicator
            Capsule()
                .fill(HawkTheme.textTertiary.opacity(0.4))
                .frame(width: 36, height: 5)
                .padding(.top, 10)
                .padding(.bottom, 16)

            if let title {
                HStack {
                    Text(title)
                        .font(HawkTypography.headline)
                        .foregroundColor(HawkTheme.textPrimary)
                    Spacer()
                    Button {
                        isPresented = false
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(HawkTheme.textTertiary)
                            .font(.system(size: 20))
                    }
                }
                .padding(.horizontal, HawkSpacing.lg)
                .padding(.bottom, HawkSpacing.md)
            }

            content
        }
        .background(HawkTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: HawkRadius.xl, style: .continuous))
    }
}

// 13. HawkMiniPlayer & HawkTabBar
public typealias HawkMiniPlayer = MiniPlayerView

public struct HawkTabBarItem: Identifiable, Sendable {
    public let id: String
    public let title: String
    public let icon: String
    public let selectedIcon: String?

    public init(id: String, title: String, icon: String, selectedIcon: String? = nil) {
        self.id = id
        self.title = title
        self.icon = icon
        self.selectedIcon = selectedIcon
    }
}

public struct HawkTabBar: View {
    @Binding private var selectedTab: String
    private let items: [HawkTabBarItem]

    public init(selectedTab: Binding<String>, items: [HawkTabBarItem]) {
        self._selectedTab = selectedTab
        self.items = items
    }

    public var body: some View {
        HStack {
            ForEach(items) { item in
                let isSelected = selectedTab == item.id
                Button {
                    selectedTab = item.id
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: isSelected ? (item.selectedIcon ?? item.icon) : item.icon)
                            .font(.system(size: 20, weight: isSelected ? .bold : .medium))
                            .foregroundColor(isSelected ? HawkTheme.primaryAccent : HawkTheme.textSecondary)
                        Text(item.title)
                            .font(HawkTypography.caption2.weight(isSelected ? .semibold : .regular))
                            .foregroundColor(isSelected ? HawkTheme.primaryAccent : HawkTheme.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.top, HawkSpacing.xs)
        .padding(.bottom, HawkSpacing.sm)
        .background(HawkTheme.navigationBackground)
        .overlay(
            Rectangle()
                .fill(HawkTheme.dividerColor)
                .frame(height: 0.8),
            alignment: .top
        )
    }
}

// MARK: - Dedicated Monochromatic Library Category Styling
public enum HawkLibraryStyle {
    public static let iconTint: Color = HawkTheme.textPrimary
    public static let iconBackground: Color = HawkTheme.secondarySurface
    public static let iconActiveTint: Color = HawkTheme.primaryAccent
    public static let rowBackground: Color = HawkTheme.cardBackground
}

