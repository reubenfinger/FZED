# FZED (checkpoint)

The FZED optional software for the Casio FZ-1. This is the FZED40N code, named **FZED** on the FZ (title line and disk name); later versions start from this folder.

- `fzed.asm` (with `fx/`): the source. `sh build.sh BASE.img` assembles it and writes `FZ1_FZED.img` over any earlier PERF / FZED disk image (`mkimg.py`). `python3 ../fz_img_hfe.py tohfe FZ1_FZED.img "A FZ1_FZED.hfe" --template <an existing FZ .hfe>` makes the HxC image.
- Released files: `outputs/FZ1_FZED.img`, `outputs/A FZ1_FZED.hfe`, `outputs/FZ1_FZED.asm`.
- Against FZED40N only the name changes: 3 bytes of the program (the title, padded so no address moves) and 3 bytes of the disk name.
- `tests/`: the emulator harness, with the receive checks in `tests/RXCHECK.md`.
- Naming: release files are named after the software only, without a size suffix: `FZ1_FZED.img`, `A FZ1_FZED.hfe`, `FZ1_FZED.asm` (later versions keep this; the old `_33S` meant the program's 33 disk sectors, 17-49).
