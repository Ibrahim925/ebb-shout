import Foundation

@Observable
@MainActor
final class AppState {
    var stage: PipelineStage = .idle
    var currentMode: RecordingMode = .regular
    var isHoldMode: Bool = false
    private var currentAudioURL: URL?

    let audioCapture = AudioCaptureActor()
    let injectionActor = InjectionActor()
    var ollamaClient: OllamaClient
    var transcriptionActor: TranscriptionActor
    var enhancementActor: EnhancementActor
    let profileManager: UserProfileManager
    let metricsManager: MetricsManager

    init() {
        let client = OllamaClient(
            baseURL: URL(string: UserDefaults.standard.string(forKey: "ollamaURL") ?? "http://localhost:11434")!
        )
        ollamaClient = client
        transcriptionActor = TranscriptionActor(ollamaClient: client)
        enhancementActor = EnhancementActor(ollamaClient: client)
        profileManager = UserProfileManager()
        metricsManager = MetricsManager()
        currentMode = RecordingMode(rawValue: UserDefaults.standard.string(forKey: "defaultMode") ?? "") ?? .regular
    }

    func startRecording() {
        guard stage == .idle else { return }
        stage = .recording
        Task {
            do {
                currentAudioURL = try await audioCapture.startRecording()
            } catch {
                stage = .error(error.localizedDescription)
            }
        }
    }

    func stopRecording() {
        guard stage == .recording else { return }
        Task {
            let url = await audioCapture.stopRecording()
            guard let audioURL = url else { stage = .idle; return }
            await runPipeline(audioURL: audioURL)
        }
    }

    func toggleRecording() {
        if stage == .recording { stopRecording() } else { startRecording() }
    }

    private func runPipeline(audioURL: URL) async {
        let startTime = Date()
        let whisperModel = UserDefaults.standard.string(forKey: "whisperModel") ?? "whisper"
        let gemmaModel   = UserDefaults.standard.string(forKey: "gemmaModel")   ?? "gemma4:latest"
        do {
            stage = .transcribing
            let hint = profileManager.profile.vocabularyHint.isEmpty ? nil : profileManager.profile.vocabularyHint
            let transcript = try await transcriptionActor.transcribe(audioURL: audioURL, vocabularyHint: hint, model: whisperModel)
            await audioCapture.deleteRecording(at: audioURL)

            stage = .enhancing
            let styleContext = profileManager.profile.styleContext(for: currentMode)
            let enhanced = try await enhancementActor.enhance(transcript: transcript, mode: currentMode, styleContext: styleContext, model: gemmaModel)

            try await injectionActor.inject(text: enhanced)

            let wordCount = enhanced.split(separator: " ").count
            let seconds = Date().timeIntervalSince(startTime)
            metricsManager.record(words: wordCount, seconds: seconds)
            profileManager.recordRun(transcript: transcript, mode: currentMode, enhancedOutput: enhanced)
            await regenerateStyleIfNeeded()

            stage = .done
            try await Task.sleep(for: .seconds(1.5))
            stage = .idle
        } catch {
            await audioCapture.deleteRecording(at: audioURL)
            stage = .error(error.localizedDescription)
            try? await Task.sleep(for: .seconds(2))
            stage = .idle
        }
    }

    private func regenerateStyleIfNeeded() async {
        guard profileManager.profile.shouldRegenerateStyle(for: currentMode) else { return }
        let outputs = profileManager.recentEnhancedOutputs(for: currentMode)
        let combined = outputs.joined(separator: "\n\n")
        let metaPrompt = "Summarise the writing style of these samples in 2–3 sentences: \n\n\(combined)"
        if let summary = try? await ollamaClient.enhance(transcript: metaPrompt, systemPrompt: "You are a writing style analyst.") {
            profileManager.setStyleContext(summary, for: currentMode)
        }
    }
}
