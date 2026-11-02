import SwiftUI
import HawkCore
import HawkPlayback

/// Translucent floating mini player docked above the bottom navigation tabs.
public struct MiniPlayerView: View {
    public let song: Song
    public let isPlaying: Bool
    public let isBuffering: Bool
    public let onPlayPause: () -> Void
    public let onNext: () -> Void
    public let onTap: () -> Void

    public init(
        song: Song,
        isPlaying: Bool,
        isBuffering: Bool = false,
        onPlayPause: @escaping () -> Void,
        onNext: @escaping () -> Void,
        onTap: @escaping () -> Void
    ) {
        self.song = song
        self.isPlaying = isPlaying
        self.isBuffering = isBuffering
        self.onPlayPause = onPlayPause
        self.onNext = onNext
        self.onTap = onTap
    }

    public var body: some View {
        HStack(spacing: 12) {
            // Artwork
            AsyncImage(url: song.artworkURL) { phase in
                if let image = phase.image {
                    image.resizable().scaledToFill()
                } else {
                    Rectangle().fill(HawkTheme.cardBackground)
                        .overlay(Image(systemName: "music.note").foregroundColor(.white.opacity(0.6)))
                }
            }
            .frame(width: 44, height: 44)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .shadow(color: .black.opacity(0.4), radius: 6, x: 0, y: 3)

            // Song Info
            VStack(alignment: .leading, spacing: 2) {
                Text(song.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(HawkTheme.textPrimary)
                    .lineLimit(1)

                Text(song.artist)
                    .font(.system(size: 12))
                    .foregroundColor(HawkTheme.textSecondary)
                    .lineLimit(1)
            }

            Spacer()

            // Controls
            HStack(spacing: 16) {
                Button(action: onPlayPause) {
                    ZStack {
                        if isBuffering {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: HawkTheme.primaryAccent))
                                .frame(width: 20, height: 20)
                        } else {
                            Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                                .font(.system(size: 20, weight: .medium))
                                .foregroundColor(isPlaying ? HawkTheme.primaryAccent : HawkTheme.textPrimary)
                                .contentTransition(.symbolEffect(.replace))
                        }
                    }
                    .frame(width: 32, height: 32)
                }
                .hawkPressEffect()
                .accessibilityLabel(isPlaying ? "Pause" : "Play")

                Button(action: onNext) {
                    Image(systemName: "forward.fill")
                        .font(.system(size: 18))
                        .foregroundColor(HawkTheme.textSecondary)
                        .frame(width: 32, height: 32)
                }
                .hawkPressEffect()
                .accessibilityLabel("Next Track")
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .hawkLiquidGlass(cornerRadius: 16, strokeOpacity: 0.22)
        .padding(.horizontal, 12)
        .onTapGesture(perform: onTap)
    }
}
