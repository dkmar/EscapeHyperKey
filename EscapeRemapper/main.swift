//
//  main.swift
//  EscapeRemapper
//
//  Created by Daniel Mar on 1/29/22.
//
//
//

import CoreGraphics
import Foundation

print(main())

enum KeyCodes {
    static let kVK_ESCAPE = Int("35", radix: 16)!
    static let kVK_CONTROL = Int("3B", radix: 16)!
}
enum KeyStatus {
    case Pressed, Held
}

// status of the escape key
fileprivate var keyStatus: KeyStatus? = .none

func main() -> Int32 {
    let eventMask =   (1 << CGEventType.keyDown.rawValue)
                    | (1 << CGEventType.keyUp.rawValue)
                    | (1 << CGEventType.tapDisabledByTimeout.rawValue)
                    | (1 << CGEventType.flagsChanged.rawValue)

    guard let eventTap = CGEvent.tapCreate(
        tap: .cgSessionEventTap,
        place: .headInsertEventTap,
        options: .defaultTap,
        eventsOfInterest: CGEventMask(eventMask),
        callback: eventHandler,
        userInfo: nil
    ) else {
        print("failed to create event tap")
        return EXIT_FAILURE
    }
    
    let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
    CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
    CGEvent.tapEnable(tap: eventTap, enable: true)
    CFRunLoopRun()
    
    return EXIT_SUCCESS
}

fileprivate func eventHandler(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent,
                              refcon: UnsafeMutableRawPointer?) -> Unmanaged<CGEvent>? {
    switch type {
    case .flagsChanged:
        // edit event to include control modifier if pressed
        if keyStatus != nil {
            event.flags.insert(.maskControl)
        }
        return Unmanaged.passRetained(event)
    case .keyDown:
        let (keycode, isRepeat) = (Int(event.getIntegerValueField(.keyboardEventKeycode)), Int(event.getIntegerValueField(.keyboardEventAutorepeat)))
        switch (keycode, isRepeat) {
        case (KeyCodes.kVK_ESCAPE, 0):
            // we don't know if this is escape or control yet.
            keyStatus = .Pressed
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                if keyStatus == .Pressed {
                    keyStatus = .Held
                }
            }
            // drop it
            return nil
        case (KeyCodes.kVK_ESCAPE, 1):
            if keyStatus == .Held {
                return nil
            }
            
            // we know user wants control behavior.
            guard let controlDown = CGEvent(keyboardEventSource: CGEventSource(event: event), virtualKey: CGKeyCode(KeyCodes.kVK_CONTROL), keyDown: true) else {
                return nil
            }

            // set control flag for subsequent key events
            keyStatus = .Held
            // post control down
            return Unmanaged.passRetained(controlDown)
        default:
            // edit event to include control modifier if pressed
            if keyStatus != nil {
                event.flags.insert(.maskControl)
                if keyStatus == .Pressed {
                    keyStatus = .Held
                }
            }
            return Unmanaged.passRetained(event)
        }
    case .keyUp:
        let keycode = Int(event.getIntegerValueField(.keyboardEventKeycode))
        switch (keycode, keyStatus) {
        case (KeyCodes.kVK_ESCAPE, .Pressed):
            // we know user wants escape behavior
            keyStatus = .none
            // send escape down
            let escapeDown = CGEvent(keyboardEventSource: CGEventSource(event: event), virtualKey: CGKeyCode(KeyCodes.kVK_ESCAPE), keyDown: true)
            escapeDown?.tapPostEvent(proxy)
            // return escape up (thereby completing the "escape" behavior)
            event.setIntegerValueField(.keyboardEventKeycode, value: Int64(KeyCodes.kVK_ESCAPE))
            return Unmanaged.passRetained(event)
        case (KeyCodes.kVK_ESCAPE, .Held):
            // user wants control behavior
            // unset control flag for subsequent key events
            keyStatus = .none
            // send control up
            guard let controlUp = CGEvent(keyboardEventSource: CGEventSource(event: event), virtualKey: CGKeyCode(KeyCodes.kVK_CONTROL), keyDown: false) else {
                return nil
            }

            return Unmanaged.passRetained(controlUp)
        default:
            // edit event to include control modifier if pressed
            if keyStatus != nil {
                event.flags.insert(.maskControl)
            }
            return Unmanaged.passRetained(event)
        }
    case .tapDisabledByTimeout:
        // TODO
        print("tap disabled by timeout")
        return Unmanaged.passRetained(event)
    default:
        return Unmanaged.passRetained(event)
    }
}




