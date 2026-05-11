import SwiftUI

struct SettingsView: View {
    let appState: AppState
    @AppStorage("ollamaURL") private var ollamaURL = "http://localhost:11434"
    @AppStorage("whisperModel") private var whisperModel = "whisper"
    @AppStorage("gemmaModel") private var gemmaModel = "gemma3:4b"
    @AppStorage("defaultMode") private var defaultMode = RecordingMode.regular.rawValue
    @AppStorage("launchAtLogin") private var launchAtLogin = false
    @State private var newWord = ""

    var body: some View {
        TabView {
            generalTab.tabItem { Label("General", systemImage: "gear") }
            modelsTab.tabItem { Label("Models", systemImage: "cpu") }
            dictionaryTab.tabItem { Label("Dictionary", systemImage: "text.book.closed") }
            privacyTab.tabItem { Label("Privacy", systemImage: "lock.shield") }
        }
        .font(.system(.body, design: .serif))
        .frame(width: 480, height: 340)
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

    private var modelsTab: some View {
        Form {
            Section("Ollama") {
                LabeledContent("Server URL") {
                    TextField("http://localhost:11434", text: $ollamaURL)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 240)
                }
            }
            Section("Models") {
                LabeledContent("Whisper model") {
                    TextField("whisper", text: $whisperModel)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 180)
                }
                LabeledContent("Gemma model") {
                    TextField("gemma3:4b", text: $gemmaModel)
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
            Text("All data is stored locally on your Mac and never transmitted anywhere.")
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
