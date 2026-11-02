import Foundation
import HawkCore

public struct EqualizerPreset: Identifiable, Sendable, Hashable {
    public var id: String { name }
    public let name: String
    /// Gains in dB for 10 bands: [32Hz, 64Hz, 125Hz, 250Hz, 500Hz, 1kHz, 2kHz, 4kHz, 8kHz, 16kHz]
    public let bandGains: [Float]

    public init(name: String, bandGains: [Float]) {
        self.name = name
        self.bandGains = bandGains
    }

    public static let flat = EqualizerPreset(name: "Flat", bandGains: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0])
    public static let bassBooster = EqualizerPreset(name: "Bass Booster", bandGains: [6, 5, 4, 2, 0, 0, 0, 0, 0, 0])
    public static let electronic = EqualizerPreset(name: "Electronic", bandGains: [4, 3, 1, 0, -2, 2, 1, 2, 4, 4])
    public static let vocalBooster = EqualizerPreset(name: "Vocal Booster", bandGains: [-2, -2, -1, 1, 3, 4, 3, 1, 0, -1])
    public static let rock = EqualizerPreset(name: "Rock", bandGains: [5, 4, 2, 0, -1, 0, 2, 3, 4, 5])
    public static let acoustic = EqualizerPreset(name: "Acoustic", bandGains: [4, 3, 2, 1, 2, 2, 3, 3, 3, 2])

    public static let allPresets: [EqualizerPreset] = [
        .flat, .bassBooster, .electronic, .vocalBooster, .rock, .acoustic
    ]
}

@MainActor
@Observable
public final class EqualizerManager {
    public static let shared = EqualizerManager()

    public var isEnabled: Bool = false
    public var currentPreset: EqualizerPreset = .flat
    public var customGains: [Float] = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0]

    public init() {}

    public func applyPreset(_ preset: EqualizerPreset) {
        self.currentPreset = preset
        self.customGains = preset.bandGains
    }

    public func setBandGain(index: Int, gain: Float) {
        guard index >= 0 && index < customGains.count else { return }
        customGains[index] = max(-12.0, min(12.0, gain))
    }
}
