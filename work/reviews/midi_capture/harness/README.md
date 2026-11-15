# MIDI review harness

Runs a build of `work/fzed` in the repo's emulator through the live FX harness (`../../live_fx/harness/lvh.py`).
Build a scratch copy first (`cp -r work/fzed /tmp/b && sh /tmp/b/build.sh`), then:

- `python3 -I t1.py BUILD out.json`: data-sheet clocks per MIDI message type, by main-loop stage.
- `python3 -I t3.py BUILD -1,0,12`: one main-loop pass, idle (-1) or with a live FX band on: data-sheet clocks
  and the bus-limited estimate (`bus.py`).
- `SHARE=0.29 python3 -I t2.py BUILD BAND KNOBS RATE SECONDS`: KNOBS controllers at RATE messages a second each
  against the build; SHARE is the part of 8 MHz data-sheet time FZED gets (0.29 measured on the FZ).
- `python3 -I eqmidi.py OLD NEW`: the same random MIDI streams (running status, realtime bytes inside messages,
  bursts) into two builds; compares the CCs applied, the clock count and the LCD.

All clock figures are emulator counts with data-sheet timings. ROM calls are stubbed and cost nothing here.
