import SwiftUI

@main
struct EbbShoutApp: App {
    @State private var appState: AppState
    private let hotKeyManager = HotKeyManager()
    @State private var menuBarController: MenuBarController?
    @State private var hudController: HUDWindowController?
    @AppStorage("onboardingComplete") private var onboardingComplete = false

    var body: some Scene {
        Settings {
            SettingsView(appState: appState)
        }

        Window("Welcome", id: "onboarding") {
            if !onboardingComplete {
                OnboardingView(appState: appState) { onboardingComplete = true }
            }
        }
        .defaultSize(width: 480, height: 500)
        .windowResizability(.contentSize)
    }

    init() {
        let state = AppState()
        _appState = State(initialValue: state)
        MainActor.assumeIsolated {
            setup(state)
        }
    }

    @MainActor
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

        if !UserDefaults.standard.bool(forKey: "onboardingComplete") {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 480, height: 500),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            window.title = "Welcome to Ebb Shout"
            window.contentView = NSHostingView(rootView: OnboardingView(appState: state) {
                UserDefaults.standard.set(true, forKey: "onboardingComplete")
                window.close()
            })
            window.center()
            window.makeKeyAndOrderFront(nil)
        }

        observeStage(state: state, menu: menu, hud: hud)
    }

    @MainActor
    private func observeStage(state: AppState, menu: MenuBarController, hud: HUDWindowController) {
        withObservationTracking {
            _ = state.stage
        } onChange: {
            Task { @MainActor in
                menu.updateIcon(for: state.stage)
                if state.stage == .idle { hud.hide() } else { hud.show() }
                // Re-arm the observation for next change
                observeStage(state: state, menu: menu, hud: hud)
            }
        }
    }
}
