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

/// Digital Biquad IIR Filter Stage for Real Audio Equalization (Robert Bristow-Johnson Audio EQ Cookbook).
public struct BiquadFilter: Sendable {
    public var b0: Float = 1.0
    public var b1: Float = 0.0
    public var b2: Float = 0.0
    public var a1: Float = 0.0
    public var a2: Float = 0.0

    // Direct Form II Transposed state registers
    public var z1: Float = 0.0
    public var z2: Float = 0.0

    public init() {}

    /// Configures a parametric peaking equalizer filter.
    public mutating func configurePeaking(frequency: Float, sampleRate: Float, gainDb: Float, q: Float = 1.414) {
        if abs(gainDb) < 0.01 {
            // Bypass filter if 0 dB gain
            b0 = 1.0; b1 = 0.0; b2 = 0.0
            a1 = 0.0; a2 = 0.0
            return
        }

        let a = pow(10.0, gainDb / 40.0)
        let w0 = 2.0 * Float.pi * frequency / sampleRate
        let cosw0 = cos(w0)
        let sinw0 = sin(w0)
        let alpha = sinw0 / (2.0 * q)

        let a0 = 1.0 + alpha / a
        b0 = (1.0 + alpha * a) / a0
        b1 = (-2.0 * cosw0) / a0
        b2 = (1.0 - alpha * a) / a0
        a1 = (-2.0 * cosw0) / a0
        a2 = (1.0 - alpha / a) / a0
    }

    /// Processes a single audio sample through this biquad stage.
    public mutating func process(sample: Float) -> Float {
        let out = b0 * sample + z1
        z1 = b1 * sample - a1 * out + z2
        z2 = b2 * sample - a2 * out
        return out
    }
}

/// High-performance 10-band audio equalizer managing presets, persistence, and real DSP processing.
@MainActor
@Observable
public final class EqualizerManager {
    public static let shared = EqualizerManager()

    public static let bandFrequencies: [Float] = [
        32.0, 64.0, 125.0, 250.0, 500.0, 1000.0, 2000.0, 4000.0, 8000.0, 16000.0
    ]

    public var isEnabled: Bool = false {
        didSet {
            UserDefaults.standard.set(isEnabled, forKey: "hawk_eq_enabled")
        }
    }

    public var currentPreset: EqualizerPreset = .flat {
        didSet {
            UserDefaults.standard.set(currentPreset.name, forKey: "hawk_eq_preset")
        }
    }

    public var customGains: [Float] = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0] {
        didSet {
            UserDefaults.standard.set(customGains, forKey: "hawk_eq_gains")
            rebuildFilters()
        }
    }

    private var filters: [BiquadFilter] = Array(repeating: BiquadFilter(), count: 10)
    private var lastSampleRate: Float = 44100.0

    public init() {
        let savedEnabled = UserDefaults.standard.bool(forKey: "hawk_eq_enabled")
        self.isEnabled = savedEnabled

        if let savedGains = UserDefaults.standard.array(forKey: "hawk_eq_gains") as? [Float], savedGains.count == 10 {
            self.customGains = savedGains
        }

        if let savedPresetName = UserDefaults.standard.string(forKey: "hawk_eq_preset"),
           let preset = EqualizerPreset.allPresets.first(where: { $0.name == savedPresetName }) {
            self.currentPreset = preset
        }

        rebuildFilters()
    }

    public func applyPreset(_ preset: EqualizerPreset) {
        self.currentPreset = preset
        self.customGains = preset.bandGains
        rebuildFilters()
    }

    public func setBandGain(index: Int, gain: Float) {
        guard index >= 0 && index < customGains.count else { return }
        customGains[index] = max(-12.0, min(12.0, gain))
        rebuildFilters()
    }

    public func reset() {
        applyPreset(.flat)
    }

    private func rebuildFilters(sampleRate: Float = 44100.0) {
        self.lastSampleRate = sampleRate
        for i in 0..<10 {
            filters[i].configurePeaking(
                frequency: Self.bandFrequencies[i],
                sampleRate: sampleRate,
                gainDb: customGains[i]
            )
        }
    }

    /// Processes an in-memory buffer of PCM float samples with the active 10-band equalizer settings.
    public func process(buffer: inout [Float], sampleRate: Float = 44100.0) {
        guard isEnabled else { return }

        if abs(sampleRate - lastSampleRate) > 1.0 {
            rebuildFilters(sampleRate: sampleRate)
        }

        for i in 0..<buffer.count {
            var sample = buffer[i]
            for bandIdx in 0..<filters.count {
                sample = filters[bandIdx].process(sample: sample)
            }
            // Soft clipping to prevent digital harshness
            buffer[i] = max(-1.0, min(1.0, sample))
        }
    }
}
