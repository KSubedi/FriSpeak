//
//  NetworkMonitor.swift
//  FriSpeak
//

import Combine
import Network

final class NetworkMonitor: ObservableObject {
    static let shared = NetworkMonitor()

    @Published private(set) var isOnline: Bool

    /// Synchronous point-in-time check, always fresh.
    var isCurrentlyReachable: Bool {
        monitor.currentPath.status == .satisfied
    }

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "frispeak.network-monitor")

    init() {
        // Read the monitor's current path before starting for an accurate initial value.
        self.isOnline = monitor.currentPath.status == .satisfied

        monitor.pathUpdateHandler = { [weak self] path in
            let satisfied = path.status == .satisfied
            DispatchQueue.main.async {
                self?.isOnline = satisfied
            }
        }
        monitor.start(queue: queue)
    }

    deinit {
        monitor.cancel()
    }
}
