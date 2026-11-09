# FZED

FZED is new optional software for the **Casio FZ-1** sampler, with a browser editor that works as its other half.

FZED loads from disk like any FZ optional software and puts the whole voice under realtime MIDI control: filter, envelopes, two LFOs, a mod matrix, loop and window. It adds sample chopping with patterns, capture, effects, time-stretch and a bank builder. The editor runs in Chrome or Edge, shows each menu as one page of knobs and switches, and sends exactly what FZED expects, so you can use FZED without learning a single MIDI number.

## Download

| | |
|---|---|
| **FZED disk for an HxC floppy emulator** | [FZ1_FZED.hfe](https://github.com/reubenfinger/FZED/releases/latest/download/FZ1_FZED.hfe) |
| **FZED disk image** (raw, for writing a real 3.5" disk or other emulators) | [FZ1_FZED.img](https://github.com/reubenfinger/FZED/releases/latest/download/FZ1_FZED.img) |
| **Editor** (one file, works offline) | [FZED.html](https://github.com/reubenfinger/FZED/releases/latest/download/FZED.html) |
| **Manual** | [FZED_MANUAL.html](https://github.com/reubenfinger/FZED/releases/latest/download/FZED_MANUAL.html) |
| Editor as separate files, with licences | [FZED.zip](https://github.com/reubenfinger/FZED/releases/latest/download/FZED.zip) |

These links always fetch the latest release. Older versions are on the [Releases](https://github.com/reubenfinger/FZED/releases) page.

## Getting started

1. Copy `FZ1_FZED.hfe` to your HxC's SD card, select it and load it on the FZ as optional software. The FZ's screen shows **FZED**.
2. Connect a MIDI interface between your computer and the FZ.
3. Open `FZED.html` in Chrome or Edge, press **Connect MIDI**, choose the FZ's interface under **OUT** and the FZ's MIDI channel under **CH**, then press **Output locked** to enable output.
4. Turn the editor's controls. The small screen beside each page title shows what the FZ's own screen should be showing.

Keep `FZED_MANUAL.html` next to `FZED.html`: the manual explains every page and control, and its Appendix A lists every MIDI message by menu page if you'd rather use your own controller or sequencer.

## In this repository

- `outputs/` - the released files: the disk images (`A FZ1_FZED.hfe` is the same disk as the download), the single-file editor, its manual and `FZED.zip`. `outputs/FZED/` holds the editor's source and docs.
- `work/fzed/` - FZED's source (8086/80186 assembly, NASM). `sh build.sh <base FZ disk image>` assembles it and writes `FZ1_FZED.img`; `work/fz_img_hfe.py` converts between `.img` and `.hfe`. `work/fzed/tests/` holds an emulator of FZED's own code (the FZ's ROM calls are stubbed; no ROM is used) and the checks described in `RXCHECK.md`.
- `work/fz_browser_editor/` - the editor's build, packaging and manual scripts, and its tests (`test_fakedom/`, run with Node).
- `work/remote_sl/` - optional templates for a Novation ReMOTE SL MkI (see `outputs/FZED/FZED_REMOTE_SL.md`; the editor offers them when opened as `FZED.html?remotesl`).

## Notes

- Tested on a Casio FZ-1.
- No Casio ROM, system software, manuals or sound library is included or needed. Casio and FZ-1 are trademarks of Casio Computer Co., Ltd.; this project is independent and not affiliated with or endorsed by Casio.
- Licence: MIT (`LICENSE`), except third-party parts under their own licences: `outputs/FZED/THIRD_PARTY_NOTICES.md` (Airwindows effects, Lucide icons) and `work/remote_sl/README.md` (the ReMOTE SL base template, GPL-3.0).
