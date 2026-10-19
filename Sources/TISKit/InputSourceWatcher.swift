import Carbon
import Foundation

public enum InputSourceEventKind: Sendable, CaseIterable {
    case selectionChanged
    case enabledSourcesChanged

    // [spec:tis:req:watch.stream]
    public var notificationName: Notification.Name {
        switch self {
        case .selectionChanged:
            Notification.Name(kTISNotifySelectedKeyboardInputSourceChanged as String)
        case .enabledSourcesChanged:
            Notification.Name(kTISNotifyEnabledKeyboardInputSourcesChanged as String)
        }
    }
}

public enum InputSourceEvent: Equatable, Sendable {
    case selected(InputSource)
    case enabled([InputSource])
}

extension InputSourceProvider {
    // [spec:tis:req:watch.stream]
    public func event(for kind: InputSourceEventKind) throws -> InputSourceEvent {
        switch kind {
        case .selectionChanged: .selected(try current(.keyboard))
        case .enabledSourcesChanged: .enabled(try list(includeAllInstalled: false))
        }
    }
}

/// Reports the TIS notifications for selection and enablement changes. TIS
/// posts them on the distributed notification center.
// [spec:tis:req:watch.stream]
@MainActor
public final class InputSourceWatcher {
    private let center: NotificationCenter
    private var observers: [any NSObjectProtocol] = []

    public init(center: NotificationCenter = DistributedNotificationCenter.default()) {
        self.center = center
    }

    /// `queue` must run on the main thread, or be `nil` for a center whose
    /// notifications are posted on the main thread.
    public func start(
        queue: OperationQueue? = .main,
        handler: @escaping @MainActor @Sendable (InputSourceEventKind) -> Void
    ) {
        for kind in InputSourceEventKind.allCases {
            observers.append(
                center.addObserver(forName: kind.notificationName, object: nil, queue: queue) { _ in
                    MainActor.assumeIsolated { handler(kind) }
                }
            )
        }
    }

    public func stop() {
        for observer in observers {
            center.removeObserver(observer)
        }
        observers = []
    }
}
