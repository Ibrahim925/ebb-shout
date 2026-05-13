import AppKit
import ApplicationServices

enum InjectionError: LocalizedError {
    case accessibilityDenied
    case noFocusedElement
    case injectionFailed

    var errorDescription: String? {
        switch self {
        case .accessibilityDenied:
            return "Accessibility permission is required to type into the focused app."
        case .noFocusedElement:
            return "No focused text field was found."
        case .injectionFailed:
            return "Could not type into the focused app."
        }
    }
}

actor InjectionActor {
    func inject(text: String) throws {
        let trimmed = text.trimmingCharacters(in: .preferenceNoise)
        guard !trimmed.isEmpty else { return }
        guard AXIsProcessTrusted() else { throw InjectionError.accessibilityDenied }
        guard hasFocusedElement() else { throw InjectionError.noFocusedElement }

        try type(text: trimmed)
    }

    private func hasFocusedElement() -> Bool {
        let systemWide = AXUIElementCreateSystemWide()
        var focusedElement: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(
            systemWide,
            kAXFocusedUIElementAttribute as CFString,
            &focusedElement
        )
        return result == .success && focusedElement != nil
    }

    private func type(text: String) throws {
        guard let source = CGEventSource(stateID: .hidSystemState) else {
            throw InjectionError.injectionFailed
        }

        let utf16 = Array(text.utf16)
        var index = 0
        while index < utf16.count {
            let chunkEnd = min(index + 20, utf16.count)
            var chunk = Array(utf16[index..<chunkEnd])

            guard let down = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true),
                  let up = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false) else {
                throw InjectionError.injectionFailed
            }

            down.keyboardSetUnicodeString(stringLength: chunk.count, unicodeString: &chunk)
            down.post(tap: .cghidEventTap)
            up.post(tap: .cghidEventTap)

            index = chunkEnd
        }
    }
}

private extension CharacterSet {
    static let preferenceNoise = CharacterSet.whitespacesAndNewlines.union(.controlCharacters)
}
