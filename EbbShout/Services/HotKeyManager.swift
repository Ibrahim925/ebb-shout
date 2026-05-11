import Cocoa

enum HotKeyEvent {
    case tap        // short press: toggle recording
    case holdStart  // held > 300ms: begin hold-to-record
    case holdEnd    // key released after holdStart
}

final class HotKeyManager {
    private var eventTap: CFMachPort?
    private var keyDownTime: Date?
    private let holdThreshold: TimeInterval = 0.3
    var onEvent: ((HotKeyEvent) -> Void)?

    // Default: ⌥Space (keyCode 49, flags .maskAlternate)
    var targetKeyCode: CGKeyCode = 49
    var targetFlags: CGEventFlags = .maskAlternate

    func start() {
        let mask: CGEventMask = (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.keyUp.rawValue)
        let selfPtr = Unmanaged.passRetained(self).toOpaque()
        eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: { _, type, event, userInfo in
                guard let userInfo else { return Unmanaged.passRetained(event) }
                let manager = Unmanaged<HotKeyManager>.fromOpaque(userInfo).takeUnretainedValue()
                manager.handle(type: type, event: event)
                return Unmanaged.passRetained(event)
            },
            userInfo: selfPtr
        )
        guard let tap = eventTap else { return }
        let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    func stop() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            eventTap = nil
        }
    }

    private func handle(type: CGEventType, event: CGEvent) {
        let keyCode = CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode))
        let flags = event.flags
        guard keyCode == targetKeyCode, flags.contains(targetFlags) else { return }

        if type == .keyDown, event.getIntegerValueField(.keyboardEventAutorepeat) == 0 {
            keyDownTime = Date()
        } else if type == .keyUp {
            guard let down = keyDownTime else { return }
            keyDownTime = nil
            let duration = Date().timeIntervalSince(down)
            if duration >= holdThreshold {
                onEvent?(.holdEnd)
            } else {
                onEvent?(.tap)
            }
        } else if type == .keyDown, event.getIntegerValueField(.keyboardEventAutorepeat) == 1 {
            if let down = keyDownTime, Date().timeIntervalSince(down) >= holdThreshold {
                keyDownTime = nil
                onEvent?(.holdStart)
            }
        }
    }
}
