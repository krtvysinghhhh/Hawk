# PROJECT HAWK — DEPENDENCY AUDIT

**Document ID:** HAWK-DOC-M1-003  
**Project:** HAWK (Native iOS Music Application)  
**Reference Codebase:** BitChord Android Client (`app/build.gradle.kts`, `build.gradle.kts`)  

---

## 1. Reference Repository Dependency Manifest & iOS Strategy

The reference application relies heavily on Android-specific frameworks and third-party JVM/C++ libraries. The table below details every key dependency, its licensing model, purpose, and the chosen native Apple replacement for HAWK.

| Dependency in Reference | Version | License | Purpose in Reference | HAWK iOS Equivalent | Strategy / Action |
|---|---|---|---|---|---|
| `androidx.compose.*` | 2024.12.01 (1.10.0) | Apache-2.0 | Android declarative UI toolkit | **SwiftUI** | Native Apple framework; zero 3rd-party bloat |
| `androidx.media3:media3-exoplayer` | 1.11.0 | Apache-2.0 | Audio playback engine | **AVFoundation / AVPlayer / AVAudioEngine** | Native Apple playback framework |
| `androidx.media3:media3-session` | 1.11.0 | Apache-2.0 | System media session & notification | **MediaPlayer (`MPNowPlayingInfoCenter`, `MPRemoteCommandCenter`)** | Native Apple framework |
| `androidx.media3:media3-exoplayer-hls` | 1.11.0 | Apache-2.0 | HLS stream playback | **AVPlayer (native HLS support)** | Built-in Apple HLS player |
| `androidx.media3:media3-exoplayer-dash`| 1.11.0 | Apache-2.0 | DASH manifest playback | **AVPlayer / Progressive streams** | Fallback to direct progressive or HLS |
| `io.ktor:ktor-client-*` | 3.5.2 | Apache-2.0 | Asynchronous HTTP & WebSocket client | **Foundation (`URLSession`, `URLSessionWebSocketTask`)** | Native Swift async/await networking |
| `org.jetbrains.kotlinx:kotlinx-serialization-json`| 1.11.0 | Apache-2.0 | JSON encoding / decoding | **Swift standard library (`Codable`, `JSONDecoder`, `JSONEncoder`)** | Native Swift serialization |
| `org.schabi.newpipe:NewPipeExtractor` | 0.26.3 | GPL-3.0-or-later| YouTube scraping & JS deciphering | **Custom Swift Innertube Resolver / Mobile Context** | Independent Swift implementation; no GPL code copied |
| `innertubex-android` | 0.7.0 | GPL-3.0 / LGPL | YouTube client catalog & token provider| **HAWK Native YouTube Source** | Independent Swift URLSession protocol implementation |
| `org.mozilla:rhino` | 1.8.1 | MPL-2.0 | JavaScript engine for YouTube cipher | **JavaScriptCore (`JSContext`)** | Native Apple framework if JS deciphering required |
| `io.github.dokar3:quickjs-kt-android` | 1.0.14 | MIT | Embedded JS engine for module sources| **JavaScriptCore (`JSContext`)** | Native Apple framework; zero external binary size |
| `io.coil-kt.coil3:coil-compose` | 3.0.4 | Apache-2.0 | Image loading and caching | **SwiftUI `AsyncImage` / Native Image Cache** | Native Swift caching using `NSCache` and `URLCache` |
| `androidx.palette:palette-ktx` | 1.0.0 | Apache-2.0 | Dominant color extraction from artwork| **CoreImage (`CIAreaAverage`, `CIRankPreserving`) / Swift color clustering** | Native Apple CoreImage processing |
| `dev.chrisbanes.haze:haze` | 1.3.1 | Apache-2.0 | Frosted glass / blur backdrop | **SwiftUI `.ultraThinMaterial` / `UIVisualEffectView`** | Native Apple system blur effect |
| `androidx.security:security-crypto` | 1.1.0-alpha06 | Apache-2.0 | Encrypted SharedPreferences | **Apple Keychain Services (`Security.framework`) + CryptoKit** | Native Apple hardware-backed secure enclave |
| `com.hierynomus:smbj` | 0.15.0 | Apache-2.0 | Pure Java SMB2/3 client | Deferred / Optional Swift SMB | High memory on 8GB host; out of core music scope |
| `com.microsoft.onnxruntime:onnxruntime-android`| 1.28.0 | MIT | Automix on-device ML model execution | **Apple CoreML / Accelerate Framework** | Native Apple neural engine acceleration |
| `com.google.android.gms:play-services-cast-framework`| 22.2.0 | Proprietary | Google Chromecast sender | **Apple AirPlay (`AVRoutePickerView`)** | First-class native Apple AirPlay |
| `signalsmith-stretch` / `linear` | 1.3.2 | MIT | C++ audio time-stretching | **AVAudioUnitTimePitch / Accelerate vDSP** | Native Apple hardware-accelerated audio processing |
| `com.google.zxing:core` | 3.5.3 | Apache-2.0 | QR code generation for party invite | **CoreImage (`CIQRCodeGenerator`)** | Native Apple framework |
| `com.github.MuntashirAkon:libadb-android`| 3.1.1 | GPL-3.0 / Apache | Sideloading apps to Wear OS watches | **Not applicable on iOS** | Dropped; Android-specific |
| `org.conscrypt:conscrypt-android` | 2.5.3 | Apache-2.0 | TLS engine for Android | **Network.framework / Security.framework** | Native Apple TLS 1.3 |

---

## 2. Dependency Philosophy for HAWK

In alignment with Rule 11 (*"Never use paid dependencies or paid infrastructure without explicit approval"*) and host optimization guidelines (*"Avoid heavyweight dependencies, prefer native Apple build tools"*):

1. **Zero External Heavy Runtimes:** HAWK will rely on Apple's standard SDKs (`SwiftUI`, `AVFoundation`, `MediaPlayer`, `CoreImage`, `CryptoKit`, `Security`, `JavaScriptCore`, `WidgetKit`).
2. **Swift Concurrency Native:** No external reactive frameworks (RxSwift or Combine); pure modern Swift async/await, actors, and `@Observable`.
3. **Storage:** No third-party databases (Realm, SQLite.swift); native Swift `Codable` writing atomic JSON files for playlists and history, and system `UserDefaults` / `Keychain` for preferences and credentials.
4. **Binary Footprint:** By avoiding bloated third-party SDKs, HAWK's compiled binary footprint will be under 15 MB, facilitating rapid sideloading via AltStore Classic and preserving the 8 GB host's memory budget.
