import Foundation
import OSLog

@Observable
@MainActor
final class AppState {
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "EbbShout", category: "Pipeline")

    var stage: PipelineStage = .idle
    var currentMode: RecordingMode = .regular
    var isHoldMode: Bool = false
    private var currentAudioURL: URL?
    
    let audioCapture = AudioCaptureActor()
    let injectionActor = InjectionActor()
    let transcriptionActor = TranscriptionActor()
    var ollamaClient: OllamaClient
    var enhancementActor: EnhancementActor
    let profileManager: UserProfileManager
    let metricsManager: MetricsManager
    
    init() {
        let client = OllamaClient(
            baseURL: URL(string: UserDefaults.standard.string(forKey: "ollamaURL") ?? "http://localhost:11434")!
        )
        ollamaClient = client
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
        let gemmaModel = UserDefaults.standard.cleanString(forKey: "gemmaModel", defaultValue: "gemma4:latest")
        let ollamaURL = UserDefaults.standard.cleanString(forKey: "ollamaURL", defaultValue: "http://localhost:11434")
        let whisperExecutable = UserDefaults.standard.cleanString(forKey: "whisperExecutable", defaultValue: "whisper-cli")
        let whisperModelPath = UserDefaults.standard.cleanString(forKey: "whisperModelPath", defaultValue: "")
        let whisperLanguage = UserDefaults.standard.cleanString(forKey: "whisperLanguage", defaultValue: "auto")
        let client = OllamaClient(baseURL: URL(string: ollamaURL) ?? .ollamaDefault)
        ollamaClient = client
        enhancementActor = EnhancementActor(ollamaClient: client)

        do {
            stage = .transcribing
            logger.info("Starting whisper.cpp transcription. executable=\(whisperExecutable, privacy: .public) model=\(whisperModelPath, privacy: .public) language=\(whisperLanguage, privacy: .public)")
            let hint = profileManager.profile.vocabularyHint.isEmpty ? nil : profileManager.profile.vocabularyHint
            let transcript = try await transcriptionActor.transcribe(
                audioURL: audioURL,
                vocabularyHint: hint,
                executablePath: whisperExecutable,
                modelPath: whisperModelPath,
                language: whisperLanguage
            )
            await audioCapture.deleteRecording(at: audioURL)
            logger.info("Whisper transcription completed. characters=\(transcript.count, privacy: .public)")
            
            stage = .enhancing
            let styleContext = profileManager.profile.styleContext(for: currentMode)
            let enhanced: String
            do {
                logger.info("Sending transcript to Ollama. url=\(client.baseURL.absoluteString, privacy: .public) model=\(gemmaModel, privacy: .public)")
                enhanced = try await enhancementActor.enhance(transcript: transcript, mode: currentMode, styleContext: styleContext, model: gemmaModel)
                logger.info("Ollama enhancement completed. characters=\(enhanced.count, privacy: .public)")
            } catch {
                logger.error("Ollama enhancement failed; falling back to raw transcript. error=\(error.localizedDescription, privacy: .public)")
                enhanced = transcript
            }
            
            logger.info("Injecting text. characters=\(enhanced.count, privacy: .public)")
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
            logger.error("Pipeline failed. error=\(error.localizedDescription, privacy: .public)")
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

private extension UserDefaults {
    func cleanString(forKey key: String, defaultValue: String) -> String {
        (string(forKey: key) ?? defaultValue).trimmingCharacters(in: .preferenceNoise)
    }
}

private extension CharacterSet {
    static let preferenceNoise = CharacterSet.whitespacesAndNewlines.union(.controlCharacters)
}

