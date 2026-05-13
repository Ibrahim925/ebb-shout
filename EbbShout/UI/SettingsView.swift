import SwiftUI
import AppKit

struct SettingsView: View {
    let appState: AppState
    @AppStorage("ollamaURL") private var ollamaURL = "http://localhost:11434"
    @AppStorage("whisperExecutable") private var whisperExecutable = "whisper-cli"
    @AppStorage("whisperModelPath") private var whisperModelPath = ""
    @AppStorage("whisperLanguage") private var whisperLanguage = "auto"
    @AppStorage("gemmaModel") private var gemmaModel = "gemma4:latest"
    @AppStorage("defaultMode") private var defaultMode = RecordingMode.regular.rawValue
    @AppStorage("launchAtLogin") private var launchAtLogin = false
    @AppStorage("hotkeyDisplay") private var hotkeyDisplay = "⌥Space"
    @State private var newWord = ""

    var body: some View {
        TabView {
            generalTab.tabItem { Label("General", systemImage: "gear") }
            hotkeyTab.tabItem { Label("Hotkey", systemImage: "keyboard") }
            modelsTab.tabItem { Label("Models", systemImage: "cpu") }
            dictionaryTab.tabItem { Label("Dictionary", systemImage: "text.book.closed") }
            privacyTab.tabItem { Label("Privacy", systemImage: "lock.shield") }
        }
        .font(.system(.body, design: .serif))
        .frame(width: 560, height: 420)
    }

    private var generalTab: some View {
        Form {
            Toggle("Launch at login", isOn: $launchAtLogin)
            Picker("Default mode", selection: $defaultMode) {
                ForEach(RecordingMode.allCases) { mode in
                    Text(mode.displayName).tag(mode.rawValue)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    private var hotkeyTab: some View {
        Form {
            Section("Dictation Shortcut") {
                LabeledContent("Shortcut") {
                    HotKeyRecorderButton(display: $hotkeyDisplay)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    private var modelsTab: some View {
        Form {
            Section("whisper.cpp") {
                LabeledContent("whisper-cli") {
                    TextField("/path/to/whisper.cpp/build/bin/whisper-cli", text: $whisperExecutable)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 300)
                }
                LabeledContent("GGML model") {
                    TextField("/path/to/whisper.cpp/models/ggml-base.en.bin", text: $whisperModelPath)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 300)
                }
                LabeledContent("Language") {
                    TextField("auto", text: $whisperLanguage)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 120)
                }
            }
            Section("Ollama") {
                LabeledContent("Server URL") {
                    TextField("http://localhost:11434", text: $ollamaURL)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 240)
                }
            }
            Section("Enhancement Model") {
                LabeledContent("Gemma model") {
                    TextField("gemma4:latest", text: $gemmaModel)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 180)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    private var dictionaryTab: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Custom vocabulary — these words are recognised more accurately.")
                .font(.system(.callout, design: .serif))
                .foregroundStyle(.secondary)
            HStack {
                TextField("Add word…", text: $newWord)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { addWord() }
                Button("Add", action: addWord)
            }
            List(appState.profileManager.profile.customVocabulary, id: \.self) { word in
                HStack {
                    Text(word).font(.system(.body, design: .serif))
                    Spacer()
                    Button { appState.profileManager.removeCustomWord(word) } label: {
                        Image(systemName: "minus.circle.fill").foregroundStyle(.red)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding()
    }

    private var privacyTab: some View {
        VStack(spacing: 16) {
            Text("Audio transcription uses whisper.cpp on this Mac. Enhancement, profile data, and metrics also stay local. No external API key is required.")
                .font(.system(.callout, design: .serif))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Erase Profile & Metrics", role: .destructive) {
                appState.profileManager.reset()
                appState.metricsManager.reset()
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func addWord() {
        let trimmed = newWord.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        appState.profileManager.addCustomWord(trimmed)
        newWord = ""
    }
}

struct HotKeyRecorderButton: View {
    @Binding var display: String
    @State private var isRecording = false
    @State private var monitor: Any?

    var body: some View {
        Button(isRecording ? "Press shortcut..." : display) {
            beginRecording()
        }
        .frame(width: 150)
        .onDisappear { stopRecording() }
    }

    private func beginRecording() {
        stopRecording()
        isRecording = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            capture(event)
            return nil
        }
    }

    private func stopRecording() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
        isRecording = false
    }

    private func capture(_ event: NSEvent) {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        guard !flags.isEmpty, let cgFlags = event.cgEvent?.flags.intersection(HotKeyManager.modifierMask) else {
            NSSound.beep()
            return
        }

        let keyCode = CGKeyCode(event.keyCode)
        let label = Self.displayString(for: event, flags: flags)
        display = label
        HotKeyManager.saveShortcut(keyCode: keyCode, flags: cgFlags, display: label)
        stopRecording()
    }

    private static func displayString(for event: NSEvent, flags: NSEvent.ModifierFlags) -> String {
        var result = ""
        if flags.contains(.control) { result += "⌃" }
        if flags.contains(.option) { result += "⌥" }
        if flags.contains(.shift) { result += "⇧" }
        if flags.contains(.command) { result += "⌘" }
        result += keyName(for: event)
        return result
    }

    private static func keyName(for event: NSEvent) -> String {
        switch event.keyCode {
        case 36: return "Return"
        case 48: return "Tab"
        case 49: return "Space"
        case 51: return "Delete"
        case 53: return "Esc"
        case 123: return "←"
        case 124: return "→"
        case 125: return "↓"
        case 126: return "↑"
        default:
            return event.charactersIgnoringModifiers?.uppercased() ?? "Key \(event.keyCode)"
        }
    }
}
