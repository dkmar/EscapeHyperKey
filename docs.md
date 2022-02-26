Option 1
---
if capslock is depressed, we set a capslockFlag to true.

if another key goes down while capslockFlag is set, then we set the event's control modifier flag and propagate it.

if a key goes down/up while capslockFlag is unset, then propagate it

if capslock goes up after capslock went down (aka no keys were pressed in between this), send escape and unset capslockFlag

Option 2
---
if capslock goes down, we set capslockFlag to true and start a timer wherein if capslock isn't released, we send a flagsChanged message with the control event flag set.
- if capslock is released during this time, we send the keydown escape followed by the keyup escape messages and unset the capslockFlag.

if any other keys or modifiers are pressed while capslockFlag is set, we modify the event to include the set control event before passing it on.

My worries:

Let's analyze data hazards.
1. RAW of capslockFlag.

Option 3
---
We use system preferences to map the capslock key to escape because escape is an event that repeats when it's held down. The default Delay Until Repeat is (in my opinion) long enough that anyone pressing "escape" for escape will have released it by then and anyone pressing "escape" for control will still be holding it by the time a repeat of the escape event arrives. 

Therefore upon seeing an escape keyDown event denoted as a repeat, we can consider "control" depressed and send the flagsChanged event with control modifier flag set.

if escape.down and not repeat, don't do anything
if escape.down and repeat, send control down event and set isControlPressed flag
if escape.up and isControlPressed isn't set, we send the escape key down event AND then return the escape key up event from the callback.
if escape.up and isControlPressed is set, we send flagsChanged event with control modifier unset AND unset the isControlPressed flag.

TODO: verify that there's a way to send two events within our callback.


Capslock down:
	type: flagsChanged
	keycode: 39
	autorepeat code: 00
	event flags:
	    Caps Lock: true
	    Shift: false
	    Control: false
	    Option: false
	    Command: false

Capslock up:
	type: flagsChanged
	keycode: 39
	autorepeat code: 00
	event flags:
	    Caps Lock: true
	    Shift: false
	    Control: false
	    Option: false
	    Command: false

Escape down:
	type: keyDown
	keycode: 35
	autorepeat code: 00
	event flags:
	    Caps Lock: false
	    Shift: false
	    Control: false
	    Option: false
	    Command: false

Escape down repeat:
	type: keyDown
	keycode: 35
	autorepeat code: 01
	event flags:
	    Caps Lock: false
	    Shift: false
	    Control: false
	    Option: false
	    Command: false
Escape up:
	type: keyUp
	keycode: 35
	autorepeat code: 00
	event flags:
	    Caps Lock: false
	    Shift: false
	    Control: false
	    Option: false
	    Command: false


