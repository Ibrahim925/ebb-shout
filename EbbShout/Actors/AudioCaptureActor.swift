import AVFoundation

enum AudioCaptureError: Error {
    case microphonePermissionDenied
    case recordingFailed
}

actor AudioCaptureActor {
    private var recorder: AVAudioRecorder?
    private var tempURL: URL?

    func startRecording() async throws -> URL {
        // Ensure microphone permission before touching audio hardware
        let permitted = await withCheckedContinuation { (c: CheckedContinuation<Bool, Never>) in
            AVCaptureDevice.requestAccess(for: .audio) { c.resume(returning: $0) }
        }
        guard permitted else { throw AudioCaptureError.microphonePermissionDenied }

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".wav")
        tempURL = url

        // 16 kHz mono PCM — ideal for SFSpeechRecognizer
        let settings: [String: Any] = [
            AVFormatIDKey:            Int(kAudioFormatLinearPCM),
            AVSampleRateKey:          16000.0,
            AVNumberOfChannelsKey:    1,
            AVLinearPCMBitDepthKey:   16,
            AVLinearPCMIsFloatKey:    false,
            AVLinearPCMIsBigEndianKey: false
        ]

        let rec = try AVAudioRecorder(url: url, settings: settings)
        guard rec.record() else { throw AudioCaptureError.recordingFailed }
        recorder = rec
        return url
    }

    func stopRecording() -> URL? {
        recorder?.stop()
        recorder = nil
        return tempURL
    }

    func deleteRecording(at url: URL) {
        try? FileManager.default.removeItem(at: url)
        if tempURL == url { tempURL = nil }
    }
}
