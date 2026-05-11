import AppKit
import SwiftUI

@MainActor
final class MenuBarController {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private var appState: AppState
    private var metricsWindowController: NSWindowController?

    init(appState: AppState) {
        self.appState = appState
        setupStatusItem()
    }

    private func setupStatusItem() {
        statusItem.button?.image = NSImage(systemSymbolName: "mic", accessibilityDescription: "Ebb Shout")
        statusItem.button?.target = self
        statusItem.button?.action = #selector(statusItemClicked)

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Open Metrics", target: self, action: #selector(openMetrics)))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Settings…", target: self, action: #selector(openSettings)))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit Ebb Shout", target: self, action: #selector(quit)))
        statusItem.menu = menu
    }

    func updateIcon(for stage: PipelineStage) {
        let symbolName: String
        switch stage {
        case .idle:         symbolName = "mic"
        case .recording:    symbolName = "mic.fill"
        case .transcribing: symbolName = "waveform"
        case .enhancing:    symbolName = "sparkles"
        case .done:         symbolName = "checkmark.circle"
        case .error:        symbolName = "exclamationmark.circle"
        }
        statusItem.button?.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: "Ebb Shout")
    }

    @objc private func statusItemClicked() {}
    @objc private func openMetrics() {
        let view = MetricsView(metricsManager: appState.metricsManager,
                               profileManager: appState.profileManager)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 540, height: 600),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Ebb Shout — Metrics"
        window.contentView = NSHostingView(rootView: view)
        window.center()
        window.makeKeyAndOrderFront(nil)
        metricsWindowController = NSWindowController(window: window)
    }
    @objc private func openSettings() { NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil) }
    @objc private func quit() { NSApplication.shared.terminate(nil) }
}

extension NSMenuItem {
    convenience init(title: String, target: AnyObject?, action: Selector?) {
        self.init(title: title, action: action, keyEquivalent: "")
        self.target = target
    }
}
