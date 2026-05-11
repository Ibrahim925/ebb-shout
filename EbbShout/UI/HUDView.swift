import SwiftUI
import AppKit

struct HUDContent: View {
    let appState: AppState
    @State private var isHovered = false

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                stageIndicator
                Text(stageLabel)
                    .font(.system(.callout, design: .serif).weight(.medium))
                    .foregroundStyle(.primary)
                if !isHovered {
                    Text(appState.currentMode.displayName)
                        .font(.system(.caption, design: .serif))
                        .foregroundStyle(.tertiary)
                }
            }

            if isHovered && appState.stage == .recording {
                HStack(spacing: 6) {
                    ForEach(RecordingMode.allCases) { mode in
                        Button(mode.displayName) { appState.currentMode = mode }
                            .buttonStyle(ModeChipStyle(isSelected: appState.currentMode == mode))
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: Capsule())
        .onHover { isHovered = $0 }
        .animation(.spring(duration: 0.2), value: isHovered)
    }

    @ViewBuilder private var stageIndicator: some View {
        switch appState.stage {
        case .recording:
            WaveformView()
        case .transcribing:
            ProgressView().scaleEffect(0.7).tint(.yellow)
        case .enhancing:
            ProgressView().scaleEffect(0.7).tint(.purple)
        case .done:
            Image(systemName: "checkmark").foregroundStyle(.green)
        default:
            EmptyView()
        }
    }

    private var stageLabel: String {
        switch appState.stage {
        case .idle:         return ""
        case .recording:    return "Recording"
        case .transcribing: return "Transcribing"
        case .enhancing:    return "Enhancing"
        case .done:         return "Done"
        case .error:        return "Error"
        }
    }
}

struct WaveformView: View {
    @State private var phase = 0.0
    private let bars = 7

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<bars, id: \.self) { i in
                Capsule()
                    .fill(.red)
                    .frame(width: 3, height: 6 + 8 * abs(sin(phase + Double(i) * 0.6)))
            }
        }
        .frame(height: 16)
        .onAppear {
            withAnimation(.linear(duration: 1).repeatForever(autoreverses: false)) {
                phase = .pi * 2
            }
        }
    }
}

struct ModeChipStyle: ButtonStyle {
    let isSelected: Bool
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.caption, design: .serif))
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(isSelected ? AnyShapeStyle(.quaternary) : AnyShapeStyle(Color.clear))
            .overlay(Capsule().stroke(.quaternary, lineWidth: 1))
            .clipShape(Capsule())
            .foregroundStyle(isSelected ? .primary : .tertiary)
    }
}

@MainActor
final class HUDWindowController: NSWindowController {
    convenience init(appState: AppState) {
        let panel = NSPanel(
            contentRect: .zero,
            styleMask: [.nonactivatingPanel, .hudWindow, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.contentView = NSHostingView(rootView: HUDContent(appState: appState))
        panel.contentView?.setFrameSize(NSSize(width: 260, height: 52))

        // Position bottom-centre
        if let screen = NSScreen.main {
            let x = screen.visibleFrame.midX - 130
            let y = screen.visibleFrame.minY + 24
            panel.setFrameOrigin(NSPoint(x: x, y: y))
        }
        self.init(window: panel)
    }

    func show() { window?.orderFront(nil) }
    func hide() { window?.orderOut(nil) }
}
