//
//  main.swift
//  EscapeRemapper
//
//  Created by Daniel Mar on 1/29/22.
//
//  We want to
// Listen for events
// Handle key event
/*
 If capslock is pressed for
 <  1/8 second --> send escape
 >= 1/8 second --> send control
 
 
 */
//
//

import Foundation

print(main())

func main() -> Int32 {
    let eventMask =   (1 << CGEventType.keyDown.rawValue)
                    | (1 << CGEventType.keyUp.rawValue)
                    | (1 << CGEventType.tapDisabledByTimeout.rawValue)
                    | (1 << CGEventType.flagsChanged.rawValue)
    
//    final class ControlEscape {
//        var isControlPressed = false
//    }
//    let state = ControlEscape()
    
    guard let eventTap = CGEvent.tapCreate(
        tap: .cgSessionEventTap,
        place: .headInsertEventTap,
        options: .defaultTap,
        eventsOfInterest: CGEventMask(eventMask),
        callback: eventHandler,
        userInfo: nil //UnsafeMutableRawPointer(Unmanaged.passRetained(state).toOpaque())
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

func getTypeString(type: CGEventType) -> String {
    switch type {
    case .keyUp:
        return "keyUp"
    case .keyDown:
        return "keyDown"
    case .flagsChanged:
        return "flagsChanged"
    case .tapDisabledByTimeout:
        return "tapDisabledByTimeout"
    default:
        return "other"
    }
}

fileprivate func eventHandler(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent,
                              userInfo: UnsafeMutableRawPointer?) -> Unmanaged<CGEvent>? {
    let stmt = """
    type: \(getTypeString(type: type))
    keycode: \(String(format: "%02X", event.getIntegerValueField(.keyboardEventKeycode)))
    autorepeat code: \(String(format: "%02X", event.getIntegerValueField(.keyboardEventAutorepeat)))
    event flags:
        Caps Lock: \(event.flags.contains(.maskAlphaShift))
        Shift: \(event.flags.contains(.maskShift))
        Control: \(event.flags.contains(.maskControl))
        Option: \(event.flags.contains(.maskAlternate))
        Command: \(event.flags.contains(.maskCommand))
    
    """
    print(stmt)
    return Unmanaged.passRetained(event)
//    switch type {
//    case .keyUp, .keyDown:
//        <#code#>
//    case .tapDisabledByTimeout:
//
//    default:
//        return Unmanaged.passRetained(event)
//    }
//    var isCaps = CGEventFlags.maskAlphaShift(cgEvent)
}

func printEventFlags(flags: CGEventFlags) {
    let keys = ["Caps Lock", "Shift", "Control", "Option", "Command"]
    let vals = [CGEventFlags.maskAlphaShift, CGEventFlags.maskShift, CGEventFlags.maskControl, CGEventFlags.maskAlternate, CGEventFlags.maskCommand]
    for (key, value) in zip(keys, vals) {
        print("\t\(key): \(value)")
    }
}
        


