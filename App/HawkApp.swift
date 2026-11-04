import SwiftUI
import HawkCore
import HawkUI
import HawkPlayback

@main
struct HawkApp: App {
    @AppStorage("hawk_appearance_mode") private var appearanceModeRaw: String = AppearanceMode.system.rawValue

    init() {
        // Initialize background audio engine
        _ = HawkAudioEngine.shared
    }

    private var activeColorScheme: ColorScheme? {
        (AppearanceMode(rawValue: appearanceModeRaw) ?? .system).colorScheme
    }

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .preferredColorScheme(activeColorScheme)
        }
    }
}
