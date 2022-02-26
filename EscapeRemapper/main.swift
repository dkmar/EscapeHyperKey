//
//  main.swift
//  EscapeRemapper
//
//  Created by Daniel Mar on 1/29/22.
//
//
//

import Foundation

print(main())



final class ControlEscape {
    enum EscapeStatus {
        case Unpressed, Pressed, Held
    }
    var escapeStatus: EscapeStatus = .Unpressed
//    var isControlPressed = false
}

func main() -> Int32 {
    let eventMask =   (1 << CGEventType.keyDown.rawValue)
                    | (1 << CGEventType.keyUp.rawValue)
                    | (1 << CGEventType.tapDisabledByTimeout.rawValue)
                    | (1 << CGEventType.flagsChanged.rawValue)
    
    let state = ControlEscape()
    
    guard let eventTap = CGEvent.tapCreate(
        tap: .cgSessionEventTap,
        place: .headInsertEventTap,
        options: .defaultTap,
        eventsOfInterest: CGEventMask(eventMask),
        callback: eventHandler,
        userInfo: UnsafeMutableRawPointer(Unmanaged.passRetained(state).toOpaque())
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
    // Decimal value of 0x35, the virtual key code for "escape"
    let kVK_ESCAPE = Int("35", radix: 16)!
    // Decimal value of 0x3B, the virtual key code for "control"
    let kVK_CONTROL = Int("3B", radix: 16)!
    let state = Unmanaged<ControlEscape>.fromOpaque(refcon!).takeUnretainedValue()
    
    switch type {
    case .flagsChanged:
        // edit event to include control modifier if pressed
        if state.escapeStatus != .Unpressed {
            event.flags.insert(.maskControl)
        }
        return Unmanaged.passRetained(event)
    case .keyDown:
        let (keycode, isRepeat) = (Int(event.getIntegerValueField(.keyboardEventKeycode)), Int(event.getIntegerValueField(.keyboardEventAutorepeat)))
        switch (keycode, isRepeat) {
        case (kVK_ESCAPE, 0):
            // we don't know if this is escape or control yet.
            state.escapeStatus = .Pressed
            // drop it
            return nil
        case (kVK_ESCAPE, 1):
            // we know user wants control behavior.
            // post control down event
            let controlDown = CGEvent(keyboardEventSource: nil, virtualKey: CGKeyCode(kVK_CONTROL), keyDown: true)
            controlDown?.tapPostEvent(proxy)
            // set control flag for subsequent key events
            state.escapeStatus = .Held
//            state.isControlPressed = true
            return nil
        default:
            // edit event to include control modifier if pressed
            if state.escapeStatus != .Unpressed {
                event.flags.insert(.maskControl)
                state.escapeStatus = .Held
            }
            return Unmanaged.passRetained(event)
        }
    case .keyUp:
        let keycode = Int(event.getIntegerValueField(.keyboardEventKeycode))
        switch (keycode, state.escapeStatus) {
        case (kVK_ESCAPE, .Pressed):
            // we know user wants escape behavior
            // send escape down
            let escapeDown = CGEvent(keyboardEventSource: nil, virtualKey: CGKeyCode(kVK_ESCAPE), keyDown: true)
            escapeDown?.tapPostEvent(proxy)
            // return escape up (thereby completing the "escape" behavior)
            event.setIntegerValueField(.keyboardEventKeycode, value: Int64(kVK_ESCAPE))
            state.escapeStatus = .Unpressed
            return Unmanaged.passRetained(event)
        case (kVK_ESCAPE, .Held):
            // user wants control behavior
            // send control up
            let controlUp = CGEvent(keyboardEventSource: nil, virtualKey: CGKeyCode(kVK_CONTROL), keyDown: false)
            controlUp?.tapPostEvent(proxy)
            // unset control flag for subsequent key events
            state.escapeStatus = .Unpressed
//            state.isControlPressed = false
            return nil
        default:
            // edit event to include control modifier if pressed
            if state.escapeStatus != .Unpressed {
                event.flags.insert(.maskControl)
                state.escapeStatus = .Held
            }
            return Unmanaged.passRetained(event)
        }
//    case .tapDisabledByTimeout:
//        // TODO
//        print("tap disabled by timeout")
    default:
        return Unmanaged.passRetained(event)
    }
}




