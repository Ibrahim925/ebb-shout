import AppKit
import ApplicationServices

enum InjectionError: Error {
    case noFocusedElement
    case accessibilityDenied
    case injectionFailed
}

actor InjectionActor {
    func inject(text: String) throws {
        let systemWide = AXUIElementCreateSystemWide()
        var focusedElement: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(systemWide,
                                                    kAXFocusedUIElementAttribute as CFString,
                                                    &focusedElement)

        guard result == .success, let element = focusedElement else {
            if result == .apiDisabled { throw InjectionError.accessibilityDenied }
            throw InjectionError.noFocusedElement
        }

        let axElement = element as! AXUIElement // safe: AXUIElement is a CFTypeRef bridged type

        // Try setting value directly (works for most editable text fields)
        var currentValue: CFTypeRef?
        AXUIElementCopyAttributeValue(axElement, kAXValueAttribute as CFString, &currentValue)
        let existing = (currentValue as? String) ?? ""
        let newValue = existing + text

        if AXUIElementSetAttributeValue(axElement, kAXValueAttribute as CFString, newValue as CFTypeRef) == .success {
            return
        }

        // Fallback: simulate keystrokes character by character
        guard let source = CGEventSource(stateID: .hidSystemState) else {
            throw InjectionError.injectionFailed
        }
        for char in text {
            guard let scalar = char.unicodeScalars.first else { continue }
            let utf16 = [UInt16(scalar.value & 0xFFFF)]
            if let down = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true) {
                down.keyboardSetUnicodeString(stringLength: utf16.count, unicodeString: utf16)
                down.post(tap: .cghidEventTap)
            }
            if let up = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false) {
                up.post(tap: .cghidEventTap)
            }
        }
    }
}
