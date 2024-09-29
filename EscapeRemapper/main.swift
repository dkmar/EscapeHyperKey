//
//  main.swift
//  EscapeRemapper
//
//  Created by Daniel Mar on 1/29/22.
//
//
//

import CoreGraphics

enum KeyCodes {
    static let kVK_ESCAPE: Int64 = 53
    static let kVK_CONTROL: Int64 = 59
    static let kVK_OPTION: Int64 = 58
    static let kVK_COMMAND: Int64 = 55
    static let kVK_SHIFT: Int64 = 57
}

enum KeyStatus {
    case Pressed, Held
}

private let HyperFlags = CGEventFlags([
    .maskCommand, .maskControl, .maskAlternate, .maskShift,
])

// status of the escape key
private var keyStatus: KeyStatus? = .none

func main() -> Int32 {
    let eventMask =
        (1 << CGEventType.keyDown.rawValue)
        | (1 << CGEventType.keyUp.rawValue)
        | (1 << CGEventType.tapDisabledByTimeout.rawValue)
        | (1 << CGEventType.flagsChanged.rawValue)

    guard
        let eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: eventHandler,
            userInfo: nil
        )
    else {
        print("failed to create event tap")
        return EXIT_FAILURE
    }

    let runLoopSource = CFMachPortCreateRunLoopSource(
        kCFAllocatorDefault, eventTap, 0)
    CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
    CGEvent.tapEnable(tap: eventTap, enable: true)
    CFRunLoopRun()

    return EXIT_SUCCESS
}


let eventHandler: CGEventTapCallBack = { proxy, type, event, _ -> Unmanaged<CGEvent>? in
    switch type {
    // modifiers added
    case .flagsChanged:
        // apply hyper if escape has already been pressed
        if keyStatus != nil {
            event.flags.formUnion(HyperFlags)
        }
        return Unmanaged.passUnretained(event)
        
    // key press
    case .keyDown:
        let (keycode, isRepeat) = (
            event.getIntegerValueField(.keyboardEventKeycode),
            event.getIntegerValueField(.keyboardEventAutorepeat)
        )
        
        switch (keycode, isRepeat) {
        // first depression of escape
        case (KeyCodes.kVK_ESCAPE, 0):
            // we don't know if this is escape or hyper yet.
            keyStatus = .Pressed
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                if keyStatus == .Pressed {
                    keyStatus = .Held
                }
            }
            // drop it
            return nil
            
        // repeat press of escape
        case (KeyCodes.kVK_ESCAPE, 1):
            // mark as held
            keyStatus = .Held
            
            // we know user wants hyper behavior.
            event.setIntegerValueField(.keyboardEventKeycode, value: KeyCodes.kVK_CONTROL)
            event.flags.formUnion(HyperFlags)
            
        // pressing some other key
        default:
            // apply hyper if escape has already been pressed
            if keyStatus != nil {
                event.flags.formUnion(HyperFlags)
                keyStatus = .Held
            }
        }
        return Unmanaged.passUnretained(event)
        
    // key released
    case .keyUp:
        let keycode = event.getIntegerValueField(.keyboardEventKeycode)
        switch (keycode, keyStatus) {
        // escape pressed and immediately released
        case (KeyCodes.kVK_ESCAPE, .Pressed):
            // we know user wants escape behavior
            // unset flag for subsequent key events
            keyStatus = .none
            // send escape down
            let escapeDown = CGEvent(
                keyboardEventSource: CGEventSource(event: event),
                virtualKey: CGKeyCode(KeyCodes.kVK_ESCAPE),
                keyDown: true
            )
            escapeDown?.tapPostEvent(proxy)
            // we keep event to do escape up (thereby completing the "escape" behavior)
            
        case (KeyCodes.kVK_ESCAPE, .Held):
            // user wants control behavior
            // unset flag for subsequent key events
            keyStatus = .none
            // send control up
            event.setIntegerValueField(.keyboardEventKeycode, value: KeyCodes.kVK_CONTROL)
            
        default:
            // apply hyper if escape has already been pressed
            if keyStatus != nil {
                event.flags.formUnion(HyperFlags)
            }
        }
        return Unmanaged.passUnretained(event)
    
    // other event like mouse movements
    default:
        // TODO: should we apply hyper if escape has already been pressed?
        // TODO: do we need to handle the event tap disabled events? aka enable again
        return Unmanaged.passUnretained(event)
    }
}

print(main())
