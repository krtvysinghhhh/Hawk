import Foundation
import Network
import HawkCore

/// Observable network state monitor reporting connection type and audio quality ceiling.
@MainActor
@Observable
public final class NetworkMonitor {
    public static let shared = NetworkMonitor()

    public private(set) var isConnected: Bool = true
    public private(set) var isCellular: Bool = false
    public private(set) var isWiFi: Bool = true

    private let monitor: NWPathMonitor
    private let queue = DispatchQueue(label: "com.hawk.network.monitor")

    public init() {
        self.monitor = NWPathMonitor()
        self.monitor.pathUpdateHandler = { [weak self] path in
            guard let self = self else { return }
            let connected = path.status == .satisfied
            let cellular = path.isExpensive || path.usesInterfaceType(.cellular)
            let wifi = path.usesInterfaceType(.wifi)

            Task { @MainActor in
                self.isConnected = connected
                self.isCellular = cellular
                self.isWiFi = wifi
            }
        }
        self.monitor.start(queue: queue)
    }

    deinit {
        monitor.cancel()
    }

    /// Determines the suggested audio quality ceiling given the current network interface.
    public func suggestedQualityCeiling() -> AudioQuality {
        if isCellular {
            return .standard // 160 kbps default on metered connections
        } else {
            return .lossless // Max bitrate / Lossless when on Wi-Fi
        }
    }
}
