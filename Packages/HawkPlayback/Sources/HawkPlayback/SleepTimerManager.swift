import Foundation
import SwiftUI
import HawkCore

/// Manages sleep timer countdown and automatic playback pause/fadeout.
@MainActor
@Observable
public final class SleepTimerManager {
    public static let shared = SleepTimerManager()

    public enum Option: Int, CaseIterable, Identifiable, Sendable {
        case off = 0
        case min15 = 15
        case min30 = 30
        case min45 = 45
        case min60 = 60
        case endOfTrack = -1

        public var id: Int { rawValue }

        public var title: String {
            switch self {
            case .off: return "Off"
            case .min15: return "15 Minutes"
            case .min30: return "30 Minutes"
            case .min45: return "45 Minutes"
            case .min60: return "1 Hour"
            case .endOfTrack: return "End of Track"
            }
        }
    }

    public private(set) var activeOption: Option = .off
    public private(set) var remainingSeconds: TimeInterval = 0
    public var isActive: Bool { activeOption != .off }

    public var formattedRemainingTime: String {
        guard isActive else { return "" }
        if activeOption == .endOfTrack {
            return "End of Track"
        }
        let minutes = Int(remainingSeconds) / 60
        let seconds = Int(remainingSeconds) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    private var timerTask: Task<Void, Never>?

    public init() {}

    public func setTimer(_ option: Option) {
        timerTask?.cancel()
        activeOption = option

        guard option != .off else {
            remainingSeconds = 0
            return
        }

        if option == .endOfTrack {
            remainingSeconds = 0
            return
        }

        let seconds = TimeInterval(option.rawValue * 60)
        remainingSeconds = seconds

        timerTask = Task {
            var left = seconds
            while left > 0 {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                if Task.isCancelled { return }
                left -= 1
                self.remainingSeconds = left
            }
            await HawkAudioEngine.shared.pause()
            self.activeOption = .off
            self.remainingSeconds = 0
        }
    }

    public func cancel() {
        setTimer(.off)
    }

    public func onTrackFinished() {
        if activeOption == .endOfTrack {
            Task {
                await HawkAudioEngine.shared.pause()
                self.activeOption = .off
                self.remainingSeconds = 0
            }
        }
    }
}
