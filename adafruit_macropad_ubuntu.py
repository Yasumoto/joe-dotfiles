from adafruit_hid.keycode import Keycode

# https://learn.adafruit.com/macropad-hotkeys/overview

# Only for testing!
#class Keycode:
#    PAGE_UP = 0
#    HOME = 0
#    PAGE_DOWN = 0
#    CONTROL = 0
#    SHIFT = 0
#    SUPER = 0

RED = 0x400000
GREEN = 0x004000
YELLOW = 0x202000
BLUE = 0x000040
YELLOW = 0x303000
WHITE = 0x101010

app = {
    'name': 'Ubuntu',
    'macros': [
        # Color, Label, Key Sequence
        (RED, 'PgUp', [Keycode.PAGE_UP]),
        (RED, 'Home', [Keycode.HOME]),
        (RED, 'PgDown', [Keycode.PAGE_DOWN]),

        (BLUE, 'apt', ['sudo apt update; and sudo apt upgrade\n']),
        (BLUE, 'dotfiles', ['/home/joe/workspace/github.com/Yasumoto/joe-dotfiles/']),
        (BLUE, '', ['\n']),

        (YELLOW, 'joy', [Keycode.SHIFT, Keycode.CONTROL, "u", -Keycode.COMMAND, "1F602", -Keycode.COMMAND, " "]),
        (YELLOW, 'bow', [Keycode.SHIFT, Keycode.CONTROL, "u", -Keycode.COMMAND, "1F647", -Keycode.COMMAND, " "]),
        (YELLOW, 'tada', [Keycode.SHIFT, Keycode.CONTROL, "u", -Keycode.COMMAND, "1F389", -Keycode.COMMAND, " "]),

        (GREEN, '<', [Keycode.CONTROL, Keycode.PAGE_UP] ),
        (GREEN, 'TermNew', [Keycode.SHIFT, Keycode.CONTROL, 't']),
        (GREEN, '>', [Keycode.CONTROL, Keycode.PAGE_DOWN]),

        # Encoder press
        (0x000000, '', [Keycode.COMMAND, 'l']) # Lock
    ]
}
