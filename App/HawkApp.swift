import SwiftUI
import HawkCore
import HawkUI
import HawkPlayback

@main
struct HawkApp: App {
    init() {
        // Initialize background audio engine
        _ = HawkAudioEngine.shared
    }

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .preferredColorScheme(.dark)
        }
    }
}
