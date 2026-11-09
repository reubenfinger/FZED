# FZED

FZED is new optional software for the Casio FZ-1 sampler, with a browser editor that works as its other half. FZED loads from disk like any FZ optional software and adds realtime MIDI control of the voice (filter, envelopes, two LFOs, a mod matrix, loop and window), sample chopping with patterns, capture, effects, time-stretch and a bank builder. The editor (Web MIDI, Chrome or Edge) shows every control on one page per menu and sends what FZED expects.

## Using it

1. Put `outputs/A FZ1_FZED.hfe` on the SD card of an HxC floppy emulator (or write `outputs/FZ1_FZED.img` to a real 3.5" disk) and load it on the FZ as optional software.
2. Open `outputs/FZED.html` in Chrome or Edge (or unzip `outputs/FZED.zip`), connect MIDI and pick the FZ's interface and channel.
3. The manual is `outputs/FZED_MANUAL.html`. Appendix A lists every MIDI message by menu page.

## What is here

- `outputs/` - the released disk images, the single-file editor and its manual; `outputs/FZED/` is the editor's source and docs.
- `work/fzed/` - FZED's source (8086/80186 assembly, NASM). `sh build.sh <base FZ disk image>` assembles it and writes `FZ1_FZED.img`; `work/fz_img_hfe.py` converts between `.img` and `.hfe`. `work/fzed/tests/` holds an emulator of FZED's own code (the FZ's ROM calls are stubbed, no ROM is used) and the receive / screen checks in `RXCHECK.md`.
- `work/fz_browser_editor/` - the editor's build, packaging and manual scripts, and its tests (`test_fakedom/`, run with Node).
- `work/remote_sl/` - optional templates for a Novation ReMOTE SL MkI (`outputs/FZED/FZED_REMOTE_SL.md`; hidden in the editor unless opened as `FZED.html?remotesl`).

## Notes

- Tested on a Casio FZ-1.
- No Casio ROM, system software, manuals or sound library is included or needed. Casio and FZ-1 are trademarks of Casio Computer Co., Ltd.; this project is independent and not affiliated with or endorsed by Casio.
- Licence: MIT (`LICENSE`), except third-party parts under their own licences: `outputs/FZED/THIRD_PARTY_NOTICES.md` (Airwindows effects, Lucide icons) and `work/remote_sl/README.md` (the ReMOTE SL base template, GPL-3.0).
