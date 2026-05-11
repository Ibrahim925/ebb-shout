import Speech
import Foundation

enum TranscriptionError: Error {
    case permissionDenied
    case recognizerUnavailable
    case recognitionFailed
}

actor TranscriptionActor {

    /// Transcribes a recorded audio file using macOS SFSpeechRecognizer (fully on-device).
    func transcribe(audioURL: URL, vocabularyHint: String?, model: String = "whisper") async throws -> String {
        // Request speech recognition permission if needed
        let status = await withCheckedContinuation { (continuation: CheckedContinuation<SFSpeechRecognizerAuthorizationStatus, Never>) in
            SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0) }
        }
        guard status == .authorized else { throw TranscriptionError.permissionDenied }

        guard let recognizer = SFSpeechRecognizer(), recognizer.isAvailable else {
            throw TranscriptionError.recognizerUnavailable
        }

        // Inject vocabulary hint as contextual strings if provided
        let request = SFSpeechURLRecognitionRequest(url: audioURL)
        request.shouldReportPartialResults = false
        request.requiresOnDeviceRecognition = false
        if let hint = vocabularyHint, !hint.isEmpty {
            let words = hint.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
            if !words.isEmpty {
                request.contextualStrings = words
            }
        }

        return try await withCheckedThrowingContinuation { continuation in
            recognizer.recognitionTask(with: request) { result, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let result, result.isFinal else { return }
                let text = result.bestTranscription.formattedString
                continuation.resume(returning: text)
            }
        }
    }
}
