import SwiftUI
import AVFoundation

struct OnboardingView: View {
    let appState: AppState
    var onComplete: () -> Void

    enum Step: Int, CaseIterable {
        case ollamaCheck, pullModels, microphone, accessibility, done
    }

    @State private var currentStep: Step = .ollamaCheck
    @State private var stepStatus: [Step: Bool] = [:]
    @State private var isWorking = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 32) {
            Text("Welcome to Ebb Shout")
                .font(.system(size: 28, weight: .bold, design: .serif))
            Text("Let's get you set up.")
                .font(.system(.title3, design: .serif))
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 16) {
                stepRow(.ollamaCheck, title: "Ollama is running", subtitle: "Checking localhost:11434")
                stepRow(.pullModels, title: "Models available", subtitle: "whisper + gemma3:4b")
                stepRow(.microphone, title: "Microphone access", subtitle: "Required for recording")
                stepRow(.accessibility, title: "Accessibility access", subtitle: "Required for text injection")
            }

            if let error = errorMessage {
                Text(error).foregroundStyle(.red).font(.system(.callout, design: .serif))
            }

            Button(action: advanceStep) {
                Group {
                    if isWorking { ProgressView() } else { Text(buttonLabel) }
                }
                .frame(width: 180)
            }
            .buttonStyle(.borderedProminent)
            .disabled(isWorking)
        }
        .padding(40)
        .frame(width: 480)
    }

    private func stepRow(_ step: Step, title: String, subtitle: String) -> some View {
        HStack(spacing: 12) {
            Group {
                if stepStatus[step] == true {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                } else if currentStep == step && isWorking {
                    ProgressView().scaleEffect(0.7)
                } else {
                    Image(systemName: "circle").foregroundStyle(.tertiary)
                }
            }
            .frame(width: 20)
            VStack(alignment: .leading) {
                Text(title).font(.system(.body, design: .serif).weight(.medium))
                Text(subtitle).font(.system(.caption, design: .serif)).foregroundStyle(.secondary)
            }
        }
    }

    private var buttonLabel: String {
        switch currentStep {
        case .ollamaCheck:   return "Check Ollama"
        case .pullModels:    return "Pull Models"
        case .microphone:    return "Grant Microphone"
        case .accessibility: return "Open System Settings"
        case .done:          return "Get Started"
        }
    }

    private func advanceStep() {
        errorMessage = nil
        isWorking = true
        Task {
            switch currentStep {
            case .ollamaCheck:
                let ok = await appState.ollamaClient.isReachable()
                stepStatus[.ollamaCheck] = ok
                if ok { currentStep = .pullModels } else { errorMessage = "Ollama not reachable. Start it with `ollama serve`." }

            case .pullModels:
                stepStatus[.pullModels] = true
                currentStep = .microphone

            case .microphone:
                let status = await AVCaptureDevice.requestAccess(for: .audio)
                stepStatus[.microphone] = status
                if status { currentStep = .accessibility } else { errorMessage = "Microphone access denied. Grant it in System Settings." }

            case .accessibility:
                NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
                stepStatus[.accessibility] = true
                currentStep = .done

            case .done:
                UserDefaults.standard.set(true, forKey: "onboardingComplete")
                onComplete()
            }
            isWorking = false
        }
    }
}
