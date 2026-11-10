# FZED Editor

FZED is optional software for the Casio FZ-1 sampler. This folder is its browser editor and manual: the editor shows each FZED menu as one page of controls and sends FZED the right MIDI messages.

## What's here

- `FZED.html`: the editor, in one file. Open it in Chrome or Edge; it works offline.
- `FZED_MANUAL.html`: the manual. Appendix A lists every MIDI message by page; Appendix B says which controls change notes that are already sounding.
- `USER_FZ.BIN`: the preset bank the editor opens with.
- `index.html`, `editor.js`, `styles.css`, `profile.js`: the same editor as separate files, if you'd rather serve it from a local web server.
- Licence files: `LICENSE_AIRWINDOWS.txt`, `LUCIDE_LICENSE` and `THIRD_PARTY_NOTICES.md` for the parts that come from other projects.

## The FZED disk

The disk itself is a separate download from https://github.com/reubenfinger/FZED: `A FZ1_FZED.hfe` for an HxC floppy emulator, or `FZ1_FZED.img` for a real floppy.

### Put FZED on the FZ: either way

**A. HxC floppy emulator (SD card)**

1. Copy `A FZ1_FZED.hfe` to the HxC's SD card. (A Gotek running HxC or FlashFloppy firmware reads the same `.hfe` from its USB stick.)
2. On the emulator, select `A FZ1_FZED.hfe` as the disk in the drive.
3. On the FZ, load it as optional software. The screen shows **FZED**.

**B. Real 3.5" floppy disk**

1. Use a 3.5" high-density (HD, 2HD) disk.
2. Write `FZ1_FZED.img` to it with a floppy write utility that can write the FZ's disk layout: a raw image of 80 tracks x 2 sides x 8 sectors of 1024 bytes (1,310,720 bytes, MFM, high density). Tools for vintage formats, such as a Greaseweazle, can write it (a Greaseweazle can also write the `.hfe` directly). Ordinary PC tools that only write 1.44 MB disks can't produce this layout.
3. Put the disk in the FZ and load it as optional software. The screen shows **FZED**.

## Using the editor

1. Connect a MIDI interface between the computer and the FZ.
2. Open `FZED.html` in Chrome or Edge and press **Connect MIDI**.
3. Choose the FZ's interface under **OUT** and the FZ's MIDI channel under **CH**.
4. Press **Output locked** to enable output, then turn a control such as cutoff while playing a note.

The small screen beside each page title shows what the FZ's own screen should be showing. Nothing is sent until you enable output, and output locks itself if the MIDI set-up changes.

Not affiliated with or endorsed by Casio.
