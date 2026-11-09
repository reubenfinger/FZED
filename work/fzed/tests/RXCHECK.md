# FZED receive checks (emulator)

The emulator runs `fzedflat.bin` with `fzed.map` (copies of `work/fzed` build output).

Run from this folder; results go to `rxout/` (make it first). `rxout/profile_new.json` is the editor profile as JSON:
`node -e 'global.window={};require("../../../outputs/FZED/profile.js");console.log(JSON.stringify(window.FZ_PROFILE))' > rxout/profile_new.json`

- `rxscan.py [groups]`: every editor control's messages, low then high value; RAM diff shows what FZED changes (`CHOP=1` chops 8 slices first, for the Slices page). `rxan.py rxout/rxscan_fzed.json` names the changed addresses.
- `stepscan.py`: every step of each stepped control gives FZED40N a different setting.
- `lcdcmp.py`: what FZED draws on its LCD for sample values of every control. `../../fz_browser_editor/test_fakedom/echocmp.cjs rxout/lcd_*.json` gives the editor's FZ SCREEN for the same messages; `echodiff.py` compares them.
