# FZED space audit, 17 November 2026

This audit looks for room for three planned features: chop improvements, capture re-strike and the modular (EXT) effects. It was made on v1.1 (`main` = `next`, commit `b01419e`).

**Status, 18 November 2026:** items 3.1 and 3.4 are built on `next` (not yet tested on hardware). Results: low area 349 bytes free, high 247, `lv` 18, `xt` 56; the start-up overlay uses 627 bytes of sector 51. Of the 52 `inc/dec` candidates, only 23 could be proven carry-safe once the routines' callers were followed (the rest return straight after the `add`, and a caller could read the carry), so 3.4 gave about 57 bytes, not 100. The capture-overlay helper in 3.4 is left for the capture work (3.2). Items 3.2 and 3.3 are not started.

## 1. Where things stand

| Area | Where | Size | Free |
|---|---|---|---|
| Low | 6000h-7FFFh | 8 KB | 0 |
| High | 8400h-B7FDh | 13 KB | 2 |
| `lv` | B800h-BDFFh | 1.5 KB | 13 |
| `xt` | DC00h-EBFFh | 4 KB | 0 |
| Capture overlay | sectors 44-45, D400h-DBC3h (variables DBC4h-DBFDh) | 2 KB | 0 |
| Tools overlay 46 (`ov2`) | D400h-D7BDh | 1 KB | 3 |
| Tools overlay 47 (`ov3`) | | 1 KB | 497 |
| Tools overlay 48 (`ov4`) | | 1 KB | 45 |
| Tools overlay 49 (`ov5`) | | 1 KB | 31 |
| Wave overlay 50 (`ov6`) | | 1 KB | 420 (fill upward, keep the top empty) |

**Disk is not the limit.** The FZED disk uses sectors 0-50; sectors 51-1279 (about 1.2 MB) are empty. A new overlay sector costs a 9-byte stub in resident code.

**There is no spare RAM for code.** Checked:
- 8000h-83FFh: variables.
- BE00h-C201h: the curve table.
- C210h-C35Fh: `MISC`.
- C360h-C3FFh: filter, glide and FX variables.
- C400h-D0A7h: the per-voice contexts.
- D0C0h-D2EFh: LFO, pattern and matrix data.
- D2F0h-D3FFh: `LVBUF` and `FMBUF`.
- D400h-DBFFh: the shared window.
- EC00h-EFFFh: the stack.

The gaps are 14 bytes at C202h and 24 bytes at D0A8h, too small to matter.

**The code is already tight.** Earlier sessions squeezed it hard (the "(room)" comments):
- Only one unreferenced item was found: the string `S_VI`.
- A full peephole scan of the resident code found about 70 bytes.

## 2. What each feature needs

- **Chop improvements.**
  - All chop code is resident in the low area: `CHOP` 591, `CHPT` 141, `CHOPCC` 142, `WCOPY` 96, `CHLOOP` 93, `CHMIN` 89, `CHPROP` 65, `ZCNEAR` 48.
  - Changes to these routines (for example a block copy in `WCOPY`) need low-area bytes.
  - New offline chop actions can go in an overlay sector: 497 bytes free in sector 47, or a new sector. They then cost 9 resident bytes each.
- **Capture re-strike.**
  - The logic can be resident: the capture overlay can call resident code. It is roughly 40-80 bytes, plus a hook of a few bytes in the capture overlay.
  - Alternatively, all of it goes in the overlay once item 3.2 frees room there.
- **EXT modules.**
  - The hook is about 30-60 bytes in `lv` or the high area (Overlay Plan section 5).
  - The modules themselves go in sectors 51 and up.

## 3. Findings, largest first

### 3.1 Start-up code into a one-time overlay: about 620 bytes (recommended)

Code that runs once at start-up is resident all the time:

| Code | Area | Bytes |
|---|---|---|
| `MAIN` up to `MAIN.lp` (60CCh-61DCh), less about 20 bytes that stay resident | low | about 250 |
| `PBGET` | low | 50 |
| `FX5INIT` | low | 38 |
| `S_E`, `S_TITLE` (used only at start-up) | low | 21 |
| `MINIT` | high | 69 |
| `MXINIT` | high | 91 |
| `FXINIT` | high | 68 |
| `CAPINIT` | high | 10 |
| `PINIT`, `SVINIT` (called only from `MXINIT`) | `xt` | 27 |

Each of these is called only from `MAIN`'s start-up section or from each other (call graph checked).

**Proposal:**
- `MAIN0` already loads sectors 18-43 itself. It would also load sector 51 into D400h and call it once.
- At that moment the window is free: live FX and capture are off.
- After it returns, the resident code calls `CHFINDO`, because that loads another overlay over D400h, and goes into the main loop.

**Frees:** about 360 bytes low, 240 high, 27 `xt`.

**Risks:**
- Start-up reads one more sector (the disk is in the drive then).
- FZ calls made from the overlay go through `L6004X`, whose stack starts at DBFEh. That is fine at start-up: the calls are small (`PRT`, voice set-up), not the 412h-byte frames.
- `mkimg.py` must mark sector 51 used.

**Check:** the emulator runs start-up on the old and new builds and compares FZED's RAM (8000h-83FFh, BE00h-D3FFh) byte for byte. Then the usual regression tests.

### 3.2 Capture variables into `LVBUF`: about 70 bytes in the capture overlay

The capture overlay's 58 bytes of variables sit at the top of its own window (DBC4h-DBFDh). On re-entry for a new allocation:
1. `CAPRE` copies them out to `LVBUF`.
2. `CAPSTART` copies them back, because the FZ's delete call uses that part of the window as stack.

`LVBUF` (D2F0h-D3EFh) is otherwise unused while capture runs:
- Live FX are released on entry.
- Render, waves, chop and copy are refused.

Keeping the variables in `LVBUF` permanently would:
- free their 58 bytes in the window for code;
- remove the copy code in both places: about 8 bytes in the overlay and 15 in `lv`.

**Risk:** this must be confirmed by test, not just by reading. Nothing that capture can reach may write `LVBUF`. A static call-graph walk can't prove it, because capture dispatches CCs back through `DISPATCH`.

**Check:**
- An emulator capture run that also sends every CC, with a watch on writes to D2F0h-D32Dh.
- The capture tests, with the same takes and settings as before.

Do this when the re-strike is built.

### 3.3 Split `NEW VOICE` into tools overlay 47: about 95 bytes in `lv`

`NEWVOICE` (`lv`, 131 bytes) runs on every CC16 message, but only its edge check has to.

**Proposal:**
- Keep the edge check, the bank and busy refusals and the capture refusal resident: about 30 bytes, plus a 9-byte stub.
- Move the voice scan and set-up into sector 47, beside `COPYV`, which already calls `NEWVOICE`.

**Behaviour:**
- Unchanged except that NEW VOICE then needs the FZED disk in the drive, as preset waves already do.
- It already releases live FX itself.

This matters if the EXT hook goes in `lv`.

### 3.4 Small savings: about 100 bytes, same behaviour

| Change | Low | High | `lv` | `xt` | Capture overlay |
|---|---|---|---|---|---|
| `add/sub r16,1` or `2` to `inc/dec` where carry isn't used next (52 places; 7 others use carry and stay) | 12 | 21 | 7 | 12 | |
| Remove unused `S_VI` ('VOICE INIT', `fx2h.asm`) | | | | 17 | |
| Trailing spaces in `NMSG` messages (`NPAD` blanks the line first): `S_CB`, `S_CV`, `S_WR`, `S_PN`, `S_RD` | 3 | | 3 | 4 | |
| `call X / ret` to `jmp X` (`svfi.asm` twice, `portai.asm` once) | | | | 3 | |
| `jmp` to a `ret` (`fxkz.asm` 89F3h) and `cmp dx,0` (`portai.asm`) | | 2 | | 1 | |
| One helper for "voice pointer, then ROM call" (3 places) | | | | | about 15 |
| **Total** | **15** | **23** | **10** | **37** | **15** |

Each `inc/dec` change needs a check that the next instructions don't read carry or flags beyond what `inc` sets. The scan stops at the first instruction that sets carry, so the 52 places are candidates, not certainties.

## 4. Checked and not recommended

- **Regenerating the lookup tables** (`FREQT`, `KSPT`, `SVFT`, `STAB`, `LOGT`, `DEXT`, `SQN2`: 2.4 KB resident).
  - None follows an exact formula: the best exponential fits miss 30 (`FREQT`) to 83 (`SVFT`) entries.
  - So rebuilding them, or halving their resolution, changes values. TapeHack, Tube2, the ring frequency and the filter cutoff would no longer match today's output.
- **Factoring the live FX inner loops.** There are two 51-byte copies (wet and mixed) and many repeated multiply steps. They are duplicated for speed, and calls inside them would slow live FX.
- **A 32-bit shift helper.** There are 57 copies of `shl ax,1 / rcl dx,1`. It saves 1 byte each and is slower.
- **Moving `CHOP` itself into an overlay.** It calls two other overlays (`MKBNDO`, `CHBSELO`), which would load over it. It needs restructuring first.
- **Render code into an overlay.** Every non-filter render clears D400h-DBFFh. That is the open design point of Overlay Plan Step 2, not a quick move.
- **`BKADD` (244 bytes) into an overlay.** Adding a voice to a bank would then always release live FX: a behaviour change.
- **Packing the start-up variable writes into a table.** It saves about 25 bytes, and item 3.1 removes them from resident code altogether.

## 5. Suggested order

1. **Small savings (3.4).** Same behaviour; the emulator regression and live FX comparisons should give identical results.
2. **Start-up overlay (3.1).** Proven by the RAM comparison, then one hardware start-up test.
3. **Capture variables (3.2),** together with the re-strike.
4. **`NEW VOICE` split (3.3),** if `lv` needs the room for EXT.

Each step goes on `next` with emulator checks, then a hardware test before `main`.

Together, items 1-2 give about 700 resident bytes (low about 375, high about 260, `lv` 10, `xt` about 65), and item 3 gives about 70 in the capture overlay.
