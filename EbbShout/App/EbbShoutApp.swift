import SwiftUI

@main
struct EbbShoutApp: App {
    @State private var appState = AppState()
    private let hotKeyManager = HotKeyManager()
    @State private var menuBarController: MenuBarController?
    @State private var hudController: HUDWindowController?

    var body: some Scene {
        MenuBarExtra { } label: { }   // placeholder — real bar managed by MenuBarController

        Settings {
            Text("Settings coming soon")
        }
    }

    init() {
        let state = AppState()
        _appState = State(initialValue: state)
        setup(state)
    }

    private func setup(_ state: AppState) {
        let menu = MenuBarController(appState: state)
        menuBarController = menu

        let hud = HUDWindowController(appState: state)
        hudController = hud

        hotKeyManager.onEvent = { event in
            Task { @MainActor in
                switch event {
                case .tap:
                    state.toggleRecording()
                case .holdStart:
                    state.isHoldMode = true
                    state.startRecording()
                case .holdEnd:
                    state.isHoldMode = false
                    state.stopRecording()
                }
            }
        }
        hotKeyManager.start()

        // Observe stage changes to update menu icon and HUD visibility
        Task { @MainActor in
            var lastStage: PipelineStage = .idle
            while true {
                if state.stage != lastStage {
                    lastStage = state.stage
                    menu.updateIcon(for: state.stage)
                    if state.stage == .idle { hud.hide() } else { hud.show() }
                }
                try? await Task.sleep(for: .milliseconds(100))
            }
        }
    }
}
