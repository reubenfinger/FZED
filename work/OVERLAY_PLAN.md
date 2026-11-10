# FZED overlay plan: design brief for review

Status: proposal, nothing built. Work happens on the `next` branch only. `main` stays the hardware-tested release (v1.0).

The aim is to make FZED modular through disk overlays, in two steps:

1. Move the preset wave generator out of resident memory into an overlay, keeping the seven existing waves bit-identical and adding room for new waves.
2. Use the freed resident space for an "EXT" render-FX slot that loads one effect per disk sector.

Step 1 is the priority. Step 2 is optional and has open questions.

**What I'd like from a reviewer:** check the boundaries and risks below against the code, answer the open questions, and say what's missing. Line numbers refer to the `next` branch.

## 1. Background: how FZED is laid out

- **Assembly and build:** one NASM build from `work/fzed/fzed.asm` (8086/80186, `org 0x6000`). `sh build.sh <base.img>` writes the image; `mkimg.py` places the 33 KB program at disk sectors 17-49 and marks them used in the disk's allocation map (bytes 132-134).
- **Resident code areas and free bytes:**

  | Area | Where | Free |
  |---|---|---|
  | Low | 6000h-7FFFh, `fzed.asm` up to `tools40.asm` | 16 bytes |
  | High | `fxkz.asm` to `capru.asm`, up to the `SIG` word | 10 bytes |
  | `lv` | B800h-BDFFh: `fx4m.asm`, `fx5k.asm`, `capr2z.asm` (BE00h is THT) | 2 bytes |
  | `xt` | DC00h, sectors 38-41 | 3 bytes |

  Free space is the `5A` padding before each area's limit in `fzed.lst`.
- **Overlays:**
  - `OVCALL` (`fx/tools40.asm:24`) loads one 1 KB disk sector into D400h with ROM call BFh (6 bytes of arguments, the sector number in a byte), unless both signature words are already there.
  - The signatures are `dw 0x40nn` (nn = sector) at D400h and D7BEh, so the usable space is D402h-D7BDh (about 956 bytes).
  - A caller stub is `push word ROUTINE / push word 0x40nn / jmp OVCALL` (9 bytes). On a failed load OVCALL shows `TOOLS NOT LOADED` and returns with carry set.
  - OVCALL refuses while capture is on (`CAPON`; the 2-sector capture overlay uses D400h-DBFFh) and calls `LVOFF` first (live FX keep buffers there).
  - The existing tools overlays are sectors 46-49 (`ov2`-`ov5`). How full they are: 46 full, 47 about 500 bytes free, 48 about 45 free, 49 about 30 free.
- **Shared memory around the overlay area:**
  - FZ calls go through `L6004X` (`fx/fx4m.asm:18`), which, with live FX and capture off, moves the stack to DBFEh. The stack grows down towards the overlay's end signature. Existing overlays put code that makes FZ calls low, so a deep stack only reaches data.
  - The Karplus-Strong render clears `KSB` = D400h-DBFFh (`fxkz.asm`, `FXONE`), so it overwrites any loaded overlay.
  - Echo and position (modes 12 and 13) use `DBUF` D400h and `TBUF` D600h (`fx3i.asm`).
  - `LVBUF` (D2F0h-D3EFh) is the live FX buffer, the wave writer's chunk buffer and capture's saved settings (`LVBUF+40h` = CAh marker).
- **Tests:**
  - `work/fzed/tests/` has an emulator of FZED's own code (the ROM calls are stubbed). `original40.py`, `stretch40l.py` and `oneshot40n.py` are good models; run them with `VER=fzed` after copying `fzedflat.bin` and `fzed.map` into `tests/`.
  - `stretch40.py` (1 check) and `tools40.py` (4 checks) already fail on the current build: their expected messages are out of date.
  - Editor tests: `work/fz_browser_editor/test_fakedom/*.cjs` (Node).

## 2. Step 1: preset waves into an overlay

### What the code does today (`fx/fx4m.asm`, the `lv` area)

- **CC111, `WVSEL` (line 47):** `v>>3` gives 0 (off) or 1-15; `WSEL` = band - 1.
- **CC9, `WVCC` (line 55):** below 64 arms; 120+ loads once. `cmp byte [WSEL],7 / jae .r` refuses bands 8-15, so CC111 values 64-127 are unused today.
- **`WVLOAD` (line 70, about 375 bytes):**
  - Refuses with live FX on, in bank mode, with chop slices, while recording, or for a voice under 1800 words.
  - Calls: `LVOFF`, `WVSH` (`tools40.asm`), ROM call 117 (`APIC 117,8`), `INIT`, `PSETUP`, `AFTER`, `LVWR`, `DEC2`, `NMSG`.
  - Writes 1808 words (1800 = 11 cycles + 8) in chunks of 128 words, through `LVBUF`.
  - Sets loop 0 as the sustain and end loop, original key 57, keys 21-93, rate 36k.
- **The waves:**
  - `WVF` (line 200, about 88 bytes with the `WVT` table): saw, square, pulse 25%, pulse 12%, triangle, sine, double sine.
  - `SIN` (line 234, about 42 bytes) uses `SINR` (resident, `fxkz.asm:1337`, also used by ring mode).
  - Strings: `S_WV`, `S_WR` (34 bytes).
- **Stays resident in the same file:**
  - `L6004X` (every FZ call, capture included).
  - `NEWVOICE` (CC16; also used by `multi.asm` and `ov3.asm`).
  - `S_MRV` and `S_MSE` (play and loop mode names on the FZ screen).
  - `WVSEL` and `WVCC` (called from `matrixz.asm`).

### Proposal

- **The new overlay (disk sector 50, signature 4032h):**
  - It holds `WVLOAD`, `WVF`/`WVT`, `SIN`, `S_WV` and `S_WR`.
  - Code that makes FZ calls goes first; the wave tables and functions go above it.
  - That uses about 540 of 956 bytes, leaving about 400 for new waves (bands 8-15).
- **Resident change:**
  - `WVCC`'s `jmp WVLOAD` becomes the 9-byte OVCALL stub.
  - The band check becomes `cmp WSEL,<number of waves>`.
  - That frees about 530 bytes in `lv`.
- **Behaviour to keep:**
  - The same refusals and messages.
  - The seven waves bit-identical.
  - One extra failure: `TOOLS NOT LOADED` (disk not in the drive, or capture on). Check whether capture-on is already refused by `WVLOAD`'s own checks.
- **Disk:**
  - `mkimg.py` places sector 50, checks its signatures, and marks it used (byte 134, bit 2).
  - `fzedflat.bin` grows to 34 KB; the size assert changes from 33 KB.
- **Tests:**
  - A new emulator test writes each of the seven waves with the old build and the new, and compares sample memory and voice parameters byte for byte.
  - Then a refusal test for each refusal reason.
  - Then the existing regression tests.
- **Editor and Gills:**
  - No change for the move.
  - New waves need names in `profile.js` (CC111 bands 8-15), the Gills names, and the manual.

### Risks I see (please check)

1. **Eviction:** the overlay must not be replaced while `WVLOAD` runs. I found no `OVCALL` in its call tree (`WVSH`, `WDEL`, `INIT`, `PSETUP`, `AFTER`, `LVWR`, `NMSG`), but `AFTER` → `ASSIGN`/`VDIRECT` and the ROM calls need confirming.
2. **Stack depth:** ROM call 117 and `WDEL` run on the DBFEh stack. Is their depth safely above D7BEh? The tools overlays assume so; the wave path's ROM calls are different ones.
3. **cs-relative jump:** `WVF` uses `jmp [cs:bx+WVT]`. That's fine at D400h (same segment), but the table address must be the overlay's.
4. **Ordering:** `OVCALL` calls `LVOFF`, and so does `WVLOAD`. That's harmless, but check nothing between relies on live FX state.

## 3. Step 2 (optional): EXT render effects, one per sector

### Proposal

- **Selection:** a render-only FX type "EXT". A selector picks a module sector (for example 51 + n).
- **Module format:**
  - The 2 signature words.
  - A 16-character name (shown as the FX name).
  - Entry 1, `init`: reads the FX parameters (FXREZ, FXFREQ, FXIN, FXOUT, FXW).
  - Entry 2, `sample`: ax in, ax out, with the same register contract as `FXSMP` (`fxkz.asm`).
- **Hook:**
  - In `FXSMP`'s mode chain, about 5-8 bytes in the high area.
  - A small loader and dispatcher in the freed `lv` space.
- **Rules:**
  - Render only: never live (its `LPW`/`LPM` entries are 0, no live loop).
  - Not combined with Karplus-Strong, echo or position.
  - The module is loaded before the render starts and checked after it.

### Open questions

1. **How EXT is selected:**
   - CC112 has 15 bands (`FXMOF`: `v*15>>7` through `FXMT`). Adding a 16th band shifts every band's range, which breaks saved presets and settings, the Gills and the manual's tables.
   - Alternatives:
     - (a) Replace a rarely used band.
     - (b) Select EXT with an existing parameter that's unused in some mode.
     - (c) Accept the shift and migrate presets (`build_presets.py`, settings import).

   Which would you choose?
2. **What else renders into D400h-D7BFh:** does anything else write there during a render? For example `SVRONE` (filter mode 8), `NSETUP` or the ROM calls during `LVWR`.
3. **Messages:** does `NMSG`/`FMNAME` during a render ever call `OVCALL`? The FX name for EXT would come from the module.
4. **Speed:** per-sample cost of a near call into D400h, compared with the inline chain. Render speed matters.

## 4. Plan of work

1. Review of this brief.
2. Step 1 on `next`, with emulator tests (bit-identical waves).
3. Review of the diff.
4. Hardware test on an FZ-1.
5. Pre-release v1.1-beta1.
6. Step 2 only after Step 1 is stable on hardware.
