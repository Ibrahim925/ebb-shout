import Cocoa

extension Notification.Name {
    static let ebbShoutHotKeyDidChange = Notification.Name("EbbShoutHotKeyDidChange")
}

enum HotKeyEvent {
    case tap        // short press: toggle recording
    case holdStart  // held > 300ms: begin hold-to-record
    case holdEnd    // key released after holdStart
}

final class HotKeyManager {
    private enum DefaultsKey {
        static let keyCode = "hotkeyKeyCode"
        static let modifierFlags = "hotkeyModifierFlags"
        static let display = "hotkeyDisplay"
    }

    private var eventTap: CFMachPort?
    private var keyDownTime: Date?
    private let holdThreshold: TimeInterval = 0.3
    private var hotKeyObserver: NSObjectProtocol?
    var onEvent: ((HotKeyEvent) -> Void)?
    static let modifierMask: CGEventFlags = [.maskControl, .maskAlternate, .maskShift, .maskCommand]

    // Default: ⌥Space (keyCode 49, flags .maskAlternate)
    var targetKeyCode: CGKeyCode = 49
    var targetFlags: CGEventFlags = .maskAlternate

    init() {
        loadFromUserDefaults()
        hotKeyObserver = NotificationCenter.default.addObserver(
            forName: .ebbShoutHotKeyDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.loadFromUserDefaults()
        }
    }

    deinit {
        if let hotKeyObserver {
            NotificationCenter.default.removeObserver(hotKeyObserver)
        }
        stop()
    }

    private func loadFromUserDefaults() {
        let defaults = UserDefaults.standard
        let savedKeyCode = defaults.object(forKey: DefaultsKey.keyCode) as? Int
        let savedFlags = defaults.object(forKey: DefaultsKey.modifierFlags) as? UInt64

        targetKeyCode = CGKeyCode(savedKeyCode ?? 49)
        targetFlags = CGEventFlags(rawValue: savedFlags ?? CGEventFlags.maskAlternate.rawValue)
    }

    static func saveShortcut(keyCode: CGKeyCode, flags: CGEventFlags, display: String) {
        let defaults = UserDefaults.standard
        defaults.set(Int(keyCode), forKey: DefaultsKey.keyCode)
        defaults.set(flags.rawValue, forKey: DefaultsKey.modifierFlags)
        defaults.set(display, forKey: DefaultsKey.display)
        NotificationCenter.default.post(name: .ebbShoutHotKeyDidChange, object: nil)
    }

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
        let flags = event.flags.intersection(Self.modifierMask)
        guard keyCode == targetKeyCode, flags == targetFlags else { return }

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
