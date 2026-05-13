import Foundation

enum TranscriptionError: LocalizedError, Equatable {
    case missingExecutable
    case missingModelPath
    case modelNotFound(String)
    case processFailed(Int32, String)
    case emptyTranscript

    var errorDescription: String? {
        switch self {
        case .missingExecutable:
            return "Missing whisper.cpp executable. Set whisper-cli in Settings > Models."
        case .missingModelPath:
            return "Missing whisper.cpp GGML model path. Set it in Settings > Models."
        case .modelNotFound(let path):
            return "whisper.cpp model not found at \(path)."
        case .processFailed(let status, let output):
            let detail = output.trimmingCharacters(in: .whitespacesAndNewlines)
            if detail.isEmpty {
                return "whisper.cpp failed with exit code \(status)."
            }
            return "whisper.cpp failed with exit code \(status): \(detail)"
        case .emptyTranscript:
            return "whisper.cpp returned an empty transcript."
        }
    }
}

actor TranscriptionActor {
    /// Transcribes a recorded audio file using ggml-org/whisper.cpp's `whisper-cli`.
    func transcribe(
        audioURL: URL,
        vocabularyHint: String?,
        executablePath: String,
        modelPath: String,
        language: String = "auto"
    ) async throws -> String {
        let executable = executablePath.trimmingCharacters(in: .preferenceNoise)
        guard !executable.isEmpty else { throw TranscriptionError.missingExecutable }

        let model = modelPath.trimmingCharacters(in: .preferenceNoise)
        guard !model.isEmpty else { throw TranscriptionError.missingModelPath }
        guard FileManager.default.fileExists(atPath: model) else {
            throw TranscriptionError.modelNotFound(model)
        }

        let result = try await runWhisper(
            executablePath: executable,
            arguments: arguments(
                audioURL: audioURL,
                modelPath: model,
                vocabularyHint: vocabularyHint,
                language: language
            )
        )

        guard result.status == 0 else {
            throw TranscriptionError.processFailed(result.status, result.output)
        }

        let transcript = Self.extractTranscript(from: result.transcriptOutput)
        guard !transcript.isEmpty else { throw TranscriptionError.emptyTranscript }
        return transcript
    }

    private func arguments(
        audioURL: URL,
        modelPath: String,
        vocabularyHint: String?,
        language: String
    ) -> [String] {
        var args = [
            "-m", modelPath,
            "-f", audioURL.path,
            "--no-timestamps",
            "--no-prints",
            "--no-gpu"
        ]

        let trimmedLanguage = language.trimmingCharacters(in: .preferenceNoise)
        if !trimmedLanguage.isEmpty {
            args += ["--language", trimmedLanguage]
        }

        if let hint = vocabularyHint?.trimmingCharacters(in: .preferenceNoise), !hint.isEmpty {
            args += ["--prompt", hint]
        }

        return args
    }

    private func runWhisper(executablePath: String, arguments: [String]) async throws -> (status: Int32, transcriptOutput: String, output: String) {
        try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            var finalArguments = arguments

            if executablePath.contains("/") {
                process.executableURL = URL(fileURLWithPath: executablePath)
            } else {
                process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
                finalArguments.insert(executablePath, at: 0)
            }

            process.arguments = finalArguments

            let stdout = Pipe()
            let stderr = Pipe()
            process.standardOutput = stdout
            process.standardError = stderr

            process.terminationHandler = { process in
                let stdoutText = String(data: stdout.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
                let stderrText = String(data: stderr.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
                continuation.resume(returning: (process.terminationStatus, stdoutText, stdoutText + "\n" + stderrText))
            }

            do {
                try process.run()
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    static func extractTranscript(from output: String) -> String {
        output
            .split(separator: "\n")
            .map(String.init)
            .filter { line in
                let trimmed = line.trimmingCharacters(in: .preferenceNoise)
                guard !trimmed.isEmpty else { return false }
                guard !trimmed.hasPrefix("whisper_"),
                      !trimmed.hasPrefix("main:"),
                      !trimmed.hasPrefix("system_info:"),
                      !trimmed.hasPrefix("ggml_") else {
                    return false
                }
                return true
            }

            .joined(separator: " ")
            .trimmingCharacters(in: .preferenceNoise)
    }
}

private extension CharacterSet {
    static let preferenceNoise = CharacterSet.whitespacesAndNewlines.union(.controlCharacters)
}
