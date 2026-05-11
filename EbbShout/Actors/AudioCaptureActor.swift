import AVFoundation

enum AudioCaptureError: Error {
    case engineStartFailed
    case noInputAvailable
    case microphonePermissionDenied
}

actor AudioCaptureActor {
    private let engine = AVAudioEngine()
    private var outputFile: AVAudioFile?
    private var tempURL: URL?

    func startRecording() async throws -> URL {
        // Check microphone permission first — AVAudioEngine gives cryptic -10877 if denied
        let permitted = await withCheckedContinuation { continuation in
            AVCaptureDevice.requestAccess(for: .audio) { continuation.resume(returning: $0) }
        }
        guard permitted else { throw AudioCaptureError.microphonePermissionDenied }

        let input = engine.inputNode
        guard input.inputFormat(forBus: 0).channelCount > 0 else {
            throw AudioCaptureError.noInputAvailable
        }
        let format = input.outputFormat(forBus: 0)
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".wav")
        tempURL = url
        outputFile = try AVAudioFile(forWriting: url, settings: format.settings)

        input.installTap(onBus: 0, bufferSize: 4096, format: format) { [weak self] buffer, _ in
            Task { await self?.write(buffer: buffer) }
        }

        do {
            try engine.start()
        } catch {
            throw AudioCaptureError.engineStartFailed
        }
        return url
    }

    func stopRecording() -> URL? {
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        outputFile = nil
        return tempURL
    }

    func deleteRecording(at url: URL) {
        try? FileManager.default.removeItem(at: url)
        if tempURL == url { tempURL = nil }
    }

    private func write(buffer: AVAudioPCMBuffer) {
        try? outputFile?.write(from: buffer)
    }
}
