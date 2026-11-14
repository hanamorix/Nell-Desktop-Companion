import AppKit
import Carbon.HIToolbox

/// ⌥⌘N via Carbon: global, and needs no Accessibility permission.
enum Hotkey {
    nonisolated(unsafe) private static var handler: (() -> Void)?
    nonisolated(unsafe) private static var ref: EventHotKeyRef?

    static func register(keyCode: UInt32 = UInt32(kVK_ANSI_N), modifiers: UInt32 = UInt32(optionKey | cmdKey), handler: @escaping () -> Void) {
        Hotkey.handler = handler
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, _, _ in Hotkey.handler?(); return noErr }, 1, &spec, nil, nil)
        RegisterEventHotKey(keyCode, modifiers, EventHotKeyID(signature: OSType(0x4E454C4C), id: 1), GetApplicationEventTarget(), 0, &ref)
    }
}
