import Carbon.HIToolbox
import Foundation

final class GlobalHotKeyController: @unchecked Sendable {
    private static let signature: OSType = 0x4350_484B
    private static let identifier: UInt32 = 1

    private let action: @Sendable () -> Void
    private var eventHandler: EventHandlerRef?
    private var hotKey: EventHotKeyRef?

    init(action: @escaping @Sendable () -> Void) {
        self.action = action
        installEventHandler()
    }

    deinit {
        if let hotKey {
            UnregisterEventHotKey(hotKey)
        }
        if let eventHandler {
            RemoveEventHandler(eventHandler)
        }
    }

    func register(_ choice: HotKeyChoice) {
        if let hotKey {
            UnregisterEventHotKey(hotKey)
            self.hotKey = nil
        }

        let mapping = keyMapping(for: choice)
        let identifier = EventHotKeyID(
            signature: Self.signature,
            id: Self.identifier
        )
        RegisterEventHotKey(
            mapping.keyCode,
            mapping.modifiers,
            identifier,
            GetApplicationEventTarget(),
            0,
            &hotKey
        )
    }

    private func installEventHandler() {
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        let context = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, context in
                guard let event, let context else {
                    return OSStatus(eventNotHandledErr)
                }
                var identifier = EventHotKeyID()
                let result = GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &identifier
                )
                guard result == noErr,
                      identifier.signature == GlobalHotKeyController.signature,
                      identifier.id == GlobalHotKeyController.identifier else {
                    return OSStatus(eventNotHandledErr)
                }
                let controller = Unmanaged<GlobalHotKeyController>
                    .fromOpaque(context)
                    .takeUnretainedValue()
                controller.action()
                return noErr
            },
            1,
            &eventType,
            context,
            &eventHandler
        )
    }

    private func keyMapping(
        for choice: HotKeyChoice
    ) -> (keyCode: UInt32, modifiers: UInt32) {
        switch choice {
        case .commandOptionA:
            (UInt32(kVK_ANSI_A), UInt32(cmdKey | optionKey))
        case .commandShiftA:
            (UInt32(kVK_ANSI_A), UInt32(cmdKey | shiftKey))
        case .controlOptionA:
            (UInt32(kVK_ANSI_A), UInt32(controlKey | optionKey))
        case .commandOptionSpace:
            (UInt32(kVK_Space), UInt32(cmdKey | optionKey))
        }
    }
}
