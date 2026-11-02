# PROJECT HAWK — ANDROID TO IOS ARCHITECTURAL MAPPING

**Document ID:** HAWK-MAP-001  
**Project:** HAWK (Native iOS Music Application)  

---

## 1. Architectural Patterns Mapping

| Domain / Concept | BitChord Android Pattern | HAWK Native iOS Replacement |
|---|---|---|
| **App Entry Point** | `Application` + `MainActivity` (Compose `setContent`) | `@main struct HawkApp: App` with `WindowGroup` |
| **State Management** | Kotlin Coroutines `StateFlow` + ViewModel | Swift `@Observable class` + `@Environment` |
| **Concurrency / Threading**| Kotlin `Dispatchers.IO`, `Dispatchers.Main` | Swift Concurrency (`Task`, `async`/`await`, `actor`) |
| **Component Separation** | Android Service + Binder IPC (`PlayerConnection`) | Swift Actor (`HawkAudioEngine`) injected in environment |
| **UI Framework** | Jetpack Compose (Material 3) | **SwiftUI** (Apple Human Interface Guidelines) |
| **Icons & Imagery** | Android Vector Drawables + Jetpack SF Symbols port| Native **Apple SF Symbols** (`Image(systemName:)`) |
| **Translucent Glass / Blur**| Chris Banes' `Haze` library | SwiftUI `.ultraThinMaterial` / `.background(.bar)` |
| **Image Loading** | Coil 3 (`AsyncImage` in Compose) | SwiftUI `AsyncImage` + custom memory `NSCache` |
| **Audio Playback** | Media3 / ExoPlayer | **AVFoundation (`AVPlayer`, `AVQueuePlayer`)** |
| **Audio Routing / Focus** | `AudioManager` audio focus change listener | `AVAudioSession` interruption & route notifications |
| **Lock Screen Controls** | `MediaSessionCompat` + Notification builder | `MPNowPlayingInfoCenter` + `MPRemoteCommandCenter` |
| **Background Playback** | Android Foreground Service + WakeLock | `UIBackgroundModes` -> `audio` in `Info.plist` |
| **Equalizer** | Android `AudioEffect` / C++ SVF filter | `AVAudioUnitEQ` 10-band parametric audio unit |
| **AirPlay / Casting** | Google Play Services Cast Framework | Native **Apple AirPlay (`AVRoutePickerView`)** |
| **Local File Access** | Android `MediaStore` + ContentResolver | iOS `UIDocumentPickerViewController` + Security-scoped URLs |
| **Credentials Storage** | Android `EncryptedSharedPreferences` | **Apple Keychain Services (`Security.framework`)** |
| **Settings Storage** | Android `SharedPreferences` | Apple `UserDefaults` |
| **Domain Storage** | Custom JSON serialization in SharedPreferences | Atomic `Data.write(to:options: .atomic)` of Swift `Codable` JSON |
| **Network Client** | Ktor HTTP Client with OkHttp engine | Native **Foundation `URLSession`** |
| **WebSockets** | Ktor WebSocket Plugin | `URLSessionWebSocketTask` |
| **OAuth Web Sign-in** | Embedded Android `WebView` | **`ASWebAuthenticationSession`** (AuthenticationServices) |
| **Home Screen Widgets** | Android `AppWidgetProvider` (RemoteViews) | **Apple `WidgetKit`** (`TimelineProvider` + SwiftUI) |
| **Audio Time-Stretching** | C++ Signalsmith Stretch | `AVAudioUnitTimePitch` |
| **QR Code Generation** | ZXing Core | `CoreImage` `CIQRCodeGenerator` filter |
| **Artwork Palette** | Android Palette library | `CoreImage` `CIAreaAverage` + Swift K-Means extraction |

---

## 2. Core Domain Models Comparison

### Track Model (`Song`)
- **BitChord:**
  ```kotlin
  data class Song(
      val videoId: String,
      val title: String,
      val artist: String,
      val thumbnailUrl: String?,
      val durationText: String? = null,
      val queueTier: QueueTier = QueueTier.CONTEXT,
      val queueEntryId: String? = null,
      val localUri: String? = null,
      val sourceQuality: String? = null
  )
  ```
- **HAWK (Swift):**
  ```swift
  public struct Song: Identifiable, Codable, Sendable, Hashable {
      public let id: String // videoId or unique identifier
      public let title: String
      public let artist: String
      public let artists: [ArtistRef]
      public let albumTitle: String?
      public let albumId: String?
      public let duration: TimeInterval
      public let artworkURL: URL?
      public let queueTier: QueueTier
      public let queueEntryId: UUID
      public let localFileURL: URL?
      public let sourceQuality: SourceQuality?
      public let isVideo: Bool

      public init(...) { ... }
  }
  ```

### Queue Model (`QueueTier`)
- **BitChord:**
  `enum class QueueTier { USER_QUEUE, CONTEXT, AUTOPLAY }`
- **HAWK (Swift):**
  ```swift
  public enum QueueTier: String, Codable, Sendable {
      case userQueue = "USER_QUEUE"
      case context = "CONTEXT"
      case autoplay = "AUTOPLAY"
  }
  ```
