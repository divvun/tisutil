import Carbon
import Foundation
import TISKitTestSupport
import Testing

@testable import TISKit

// [spec:tis:req:watch.stream/test]
@Test func watcherObservesTheTISNotifications() {
    #expect(
        InputSourceEventKind.selectionChanged.notificationName.rawValue
            == kTISNotifySelectedKeyboardInputSourceChanged as String
    )
    #expect(
        InputSourceEventKind.enabledSourcesChanged.notificationName.rawValue
            == kTISNotifyEnabledKeyboardInputSourcesChanged as String
    )
}

// [spec:tis:req:watch.stream/test]
@Test @MainActor func watcherReportsOneEventPerNotification() {
    let center = NotificationCenter()
    let watcher = InputSourceWatcher(center: center)
    let received = Received()
    watcher.start(queue: nil) { received.kinds.append($0) }

    center.post(name: InputSourceEventKind.enabledSourcesChanged.notificationName, object: nil)
    center.post(name: InputSourceEventKind.selectionChanged.notificationName, object: nil)
    center.post(name: Notification.Name("SomethingElse"), object: nil)
    #expect(received.kinds == [.enabledSourcesChanged, .selectionChanged])

    watcher.stop()
    center.post(name: InputSourceEventKind.selectionChanged.notificationName, object: nil)
    #expect(received.kinds.count == 2)
}

// [spec:tis:req:watch.stream/test]
@Test @MainActor func eventsCarryTheSelectedOrEnabledSources() throws {
    let abc = InputSource(id: "com.apple.keylayout.ABC", isEnabled: true, isSelected: true)
    let irish = InputSource(id: "com.apple.keylayout.Irish", isEnabled: false)
    let sources = FixedInputSources(installed: [abc, irish], current: [.keyboard: abc])

    #expect(try sources.event(for: .selectionChanged) == .selected(abc))
    #expect(try sources.event(for: .enabledSourcesChanged) == .enabled([abc]))
}

@MainActor
private final class Received {
    var kinds: [InputSourceEventKind] = []
}
