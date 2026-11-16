# Review of work/OVERLAY_PLAN.md (revision 1)

10 November 2026. This is the first review of the overlay brief, kept for the record. It was
written against revision 1 of `work/OVERLAY_PLAN.md`; revision 2 on `next` (ecb1993) has since
folded it in, so line numbers and wording here refer to the earlier brief. No code was changed.

**Verdict:** Step 1 is sound and the brief's numbers hold, but four things need settling before
it is built. Step 2's resident hook is much bigger than the brief assumes.

## What checks out

- **Build:** a fresh build reproduces the committed `tests/fzedflat.bin` and `fzed.map` byte for byte, and matches `outputs/FZ1_FZED.img`.
- **Free bytes:** 16 / 10 / 2 / 3 resident, and 4 / 498 / 46 / 32 in sectors 46-49.
- **Sizes:** `WVLOAD` 375, `WVF`+`WVT` 88, `SIN` 42, strings 34, so 539 bytes move and 533 are freed in `lv`.
- **Line numbers, signature 4032h, byte 134 bit 2:** all correct. Sector 50 is blank and unallocated in the released image.
- **Tests:** `original40.py` passes 9/9 with `VER=fzed`. The emulator loads overlays from the flat image (`t8g2.py:16`), so sector 50 will load without harness changes.

## Corrections to the brief

- **Sectors:** `xt` is sectors 40-43; `lv` is 38-39. The "38-41" comes from the stale error text at `fzed.asm:2868`.
- **Live FX:** `WVLOAD` releases live FX (`fx4m.asm:75`); it does not refuse. The file's header comment is stale.
- **Refusals:** the length limit is 1808 words, not 1800 (`fx4m.asm:114`). Two refusals are missing from the list: allocation failure on an empty voice (line 94) and end before start (line 112).
- **KSB clear:** `FXONE` zeroes D400h-DBFFh on every non-filter render, not only Karplus-Strong (`fxkz.asm:1479-1486`).
- **Other users of D400h:** the brief omits three.
  - Curve build, D400h-D801h (`fx5k.asm:32`).
  - Filter scratch, map and variables, D400h-DBFDh (`svfi.asm:16-21, 455-465`).
  - Position variables, D7F0h-D7FDh (`fx3i.asm:13-17`).
- **Missing files:** `stretch40l.py`, `oneshot40n.py`, `stretch40.py` and `tools40.py` are not on the branch, so the "already fail" claim could not be checked. `profile.js` and the Gills names are not there either.

## The risks

1. **Eviction: safe.**
   - `WVLOAD`'s call tree makes ROM calls 117, 119, 169 and A2h (print). None of its routines reaches `OVCALL` or BFh.
   - `AFTER`, `ASSIGN` and `VDIRECT` only touch RAM.
   - `PARSE` is called only from the main loop (`fzed.asm:284`), so `WVCC` cannot run while another overlay is executing.
   - The ROM's own behaviour could not be checked from this repo.
2. **Stack depth: the real risk.**
   - `WVSH` -> `WDEL` is ROM call 119, whose frame is 412h bytes (`capru.asm:17-19`). `ov2.asm:3` puts the stack bottom at about D7ECh.
   - That is inside the 64 pad bytes, roughly 30-45 bytes above the end signature, before any interrupt lands on it.
   - Tools overlay code already reaches 117, 119 and 169, so they are not new calls. The depth of 117 and 169 is not recorded anywhere in the repo.
   - Everything in this overlay runs after those calls: the write loop calls `WVF`/`SIN`, and `S_WV` is printed last. So "FZ-calling code first" does not protect it.
   - Keep the top of the sector empty as long as possible. New waves fill upward, so the newest is the first casualty.
   - Compare `[D7BE]` with 4032h after the FZ calls and refuse if it changed.
3. **cs-relative jump: fine.** With `vstart=0xD400`, NASM resolves `WVT` to the overlay address. `ov2.asm:284` already reads `cs:` tables from an overlay.
4. **Ordering: keep `WVLOAD`'s own `LVOFF`.** `OVCALL` calls `LVOFF` only on the load path. With the overlay resident and a live effect that does not use D400h, `WVLOAD`'s call is the only one. Nothing in between depends on live state.

## Behaviour changes the move introduces

- **Capture on:** `WVLOAD` does refuse it today (line 71), but `OVCALL` gets there first. The message becomes `TOOLS NOT LOADED` instead of `WAVE: REFUSED`.
- **Bank mode with live FX on:** today it refuses and leaves live FX alone. After the move `OVCALL` releases live FX, then `WVLOAD` refuses.
- **Disk out:** every case shows `TOOLS NOT LOADED`, after live FX has been released.

Testing `CAPON` and `BKON` in `WVCC` before the stub fixes the first two for about 14 bytes.

## Open questions (Step 2)

1. **Selection: a variant of (b).** Leave CC112's 15 bands alone and add a separate selector (0 = off, n = module) that overrides the type inside `FXMOF`.
   - Option (c) moves 8 of the 15 types for presets built by `build_presets.py:38`.
   - Option (a) silently changes old presets that use the replaced band.
   - `FXMOF` sits in `xt` with 3 bytes free, so the override needs a jump into `lv`.
2. **Writes to D400h during a render:** only `FXONE`'s clear, once per voice and once per chop slice. It would erase the module, so EXT must skip it. `NSETUP` writes nothing there, and `LVWR` makes no ROM calls.
3. **Messages:** `NMSG` and `FMNAME` never reach `OVCALL`. `FMNAME` runs on CC112 changes and reads the resident `S_FMN` table. Show a resident "EXT" at selection and the module's name at render start. Loading a module on a knob sweep would hit the disk and release live FX.
4. **Speed:** negligible. D400h is the same segment, so it is one near call per sample beside the two multiplies in the mix. Better still, give the module a chunk entry in the `FXLP` form; `FXONE` already calls that once per 256 words.

## What the brief misses

- **Step 2 hook size:** a new mode number needs more than 5-8 bytes in `FXSMP`.
  - `FXRUN` sends any mode of 12 or more to the live-engine render (`fxkz.asm:258`).
  - It sends any mode of 9 or more to the fast loop (`fxkz.asm:297`).
  - `LPW`/`LPM` have 14 entries, so mode 14 or 15 reads past them into code.
  - The high area has 10 bytes free, so most of this needs jumps into `lv`.
- **Version check:** the signature encodes only the sector. A v1.1 program with a later disk in the drive would jump to wrong addresses. EXT modules need an ABI version field and fixed entry points for the same reason.
- **Emulator blind spot:** ROM calls are stubbed, so no emulator test can catch a stack clobber. A stub that scribbles 412h bytes below `sp` on calls 117, 119 and 169 would.
- **Test fixture:** the capture-test fixture gives `WAVE: REFUSED` for every wave, so the bit-identical test needs a clean voice-mode setup.
- **`mkimg.py`:** the "holds something on the base disk" guard must cover sector 50, not only the signature check.
- **Stale copies:** the committed `tests/fzedflat.bin` and `fzed.map`, `outputs/`, and the "33 sectors" / "32 KB" comments all need updating.
- **Other band tables:** `remote_sl/build_sl_templates.py` (lines 102, 130) and `make_cc_appendix.py` also carry the CC111/CC112 names.
- **Disk dependency:** a wave load will need the FZED disk after every render, capture, tool use or buffer-using live effect. Today it never does.
- **Stale signature (low, existing):** echo and position overwrite D400h but leave D7BEh, as far as I can see. A sample word equal to the signature there would pass `OVCALL`'s check.

The call-tree claims above were checked with `work/reviews/callgraph.py` (run from `work/fzed`:
`python3 ../reviews/callgraph.py WVLOAD OVCALL`).
