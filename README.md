# FZED

FZED is new optional software for the **Casio FZ-1** sampler, with a browser editor that works as its other half.

FZED loads from disk like any FZ optional software and puts the whole voice under realtime MIDI control: filter, envelopes, two LFOs, a mod matrix, loop and window. It adds sample chopping with patterns, capture, effects, time-stretch and a bank builder. The editor runs in Chrome or Edge, shows each menu as one page of knobs and switches, and sends exactly what FZED expects, so you can use FZED without learning a single MIDI number.

## Download

| | |
|---|---|
| **FZED disk for an HxC floppy emulator** | [A FZ1_FZED.hfe](https://github.com/reubenfinger/FZED/raw/main/outputs/A%20FZ1_FZED.hfe) |
| **FZED disk image** (raw, for writing a real 3.5" disk or other emulators) | [FZ1_FZED.img](https://github.com/reubenfinger/FZED/raw/main/outputs/FZ1_FZED.img) |
| **Editor and manual** (unzip, then open `FZED/FZED.html`; works offline) | [FZED.zip](https://github.com/reubenfinger/FZED/raw/main/outputs/FZED.zip) |
| **Use the editor online** (nothing to download) | [reubenfinger.github.io/FZED/outputs/FZED.html](https://reubenfinger.github.io/FZED/outputs/FZED.html) |
| **Read the manual online** | [reubenfinger.github.io/FZED/outputs/FZED_MANUAL.html](https://reubenfinger.github.io/FZED/outputs/FZED_MANUAL.html) |

The links always give the current version.

## Getting started

### 1. Put FZED on the FZ: either way

**A. HxC floppy emulator (SD card)**

1. Copy `A FZ1_FZED.hfe` to the HxC's SD card. (A Gotek running HxC or FlashFloppy firmware reads the same `.hfe` from its USB stick.)
2. On the emulator, select `A FZ1_FZED.hfe` as the disk in the drive.
3. On the FZ, load it as optional software. The screen shows **FZED**.

**B. Real 3.5" floppy disk**

1. Use a 3.5" high-density (HD, 2HD) disk.
2. Write `FZ1_FZED.img` to it with a floppy write utility that can write the FZ's disk layout: a raw image of 80 tracks x 2 sides x 8 sectors of 1024 bytes (1,310,720 bytes, MFM, high density). Tools for vintage formats, such as a Greaseweazle, can write it (a Greaseweazle can also write the `.hfe` directly). Ordinary PC tools that only write 1.44 MB disks can't produce this layout.
3. Put the disk in the FZ and load it as optional software. The screen shows **FZED**.

### 2. Connect the editor

1. Connect a MIDI interface between your computer and the FZ.
2. Open the editor in Chrome or Edge (online, or `FZED/FZED.html` from the zip) and press **Connect MIDI**.
3. Choose the FZ's interface under **OUT** and the FZ's MIDI channel under **CH**, then press **Output locked** to enable output.
4. Turn the editor's controls. The small screen beside each page title shows what the FZ's own screen should be showing.

The manual explains every page and control. Its Appendix A lists every MIDI message by menu page, if you'd rather use your own controller or sequencer, and Appendix B says which controls change notes that are already sounding.

## Versions

- `main` is the stable release: the downloads above and the online editor always come from it, and only builds tested on a real FZ-1 reach it.
- Stable versions are tagged (v1.0, v1.1 ...) with a GitHub Release of their disk images and zip, so you can go back to any of them. The [changelog](outputs/FZED/CHANGELOG.md) says what changed.
- New features are tried first on the `next` branch and published as pre-releases (for example v1.1-beta1). They may not be tested on hardware yet: use them if you want to help test, and use each pre-release's own zip for its editor.

## In this repository

- `outputs/` - the released files: the disk images, the single-file editor (`FZED.html`), its manual and `FZED.zip`. `outputs/FZED/` holds the editor's source and docs.
- `work/fzed/` - FZED's source (8086/80186 assembly, NASM). `sh build.sh <base FZ disk image>` assembles it and writes `FZ1_FZED.img`; `work/fz_img_hfe.py` converts between `.img` and `.hfe`. `work/fzed/tests/` holds an emulator of FZED's own code (the FZ's ROM calls are stubbed; no ROM is used) and the checks described in `RXCHECK.md`.
- `work/fz_browser_editor/` - the editor's build, packaging and manual scripts, and its tests (`test_fakedom/`, run with Node).
- `work/remote_sl/` - optional templates for a Novation ReMOTE SL MkI (see `outputs/FZED/FZED_REMOTE_SL.md`; the editor offers them when opened as `FZED.html?remotesl`).

## Notes

- Tested on a Casio FZ-1.
- No Casio ROM, system software, manuals or sound library is included or needed. Casio and FZ-1 are trademarks of Casio Computer Co., Ltd.; this project is independent and not affiliated with or endorsed by Casio.
- Licence: MIT (`LICENSE`), except third-party parts under their own licences: `outputs/FZED/THIRD_PARTY_NOTICES.md` (Airwindows effects, Lucide icons) and `work/remote_sl/README.md` (the ReMOTE SL base template, GPL-3.0).
