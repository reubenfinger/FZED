# FZED overlay plan: design brief for review

Status: proposal, nothing built. Revision 2: corrected after the first review (section 5). Work happens on the `next` branch only. `main` stays the hardware-tested release (v1.0).

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
  | `lv` | B800h-BDFFh, sectors 38-39: `fx4m.asm`, `fx5k.asm`, `capr2z.asm` (BE00h is THT) | 2 bytes |
  | `xt` | DC00h, sectors 40-43 | 3 bytes |

  Free space is the `5A` padding before each area's limit in `fzed.lst`.
- **Overlays:**
  - `OVCALL` (`fx/tools40.asm:24`) loads one 1 KB disk sector into D400h with ROM call BFh (6 bytes of arguments, the sector number in a byte), unless both signature words are already there.
  - The signatures are `dw 0x40nn` (nn = sector) at D400h and D7BEh, so the usable space is D402h-D7BDh (about 956 bytes).
  - A caller stub is `push word ROUTINE / push word 0x40nn / jmp OVCALL` (9 bytes). On a failed load OVCALL shows `TOOLS NOT LOADED` and returns with carry set.
  - OVCALL refuses while capture is on (`CAPON`; the 2-sector capture overlay uses D400h-DBFFh) and calls `LVOFF` first (live FX keep buffers there).
  - The existing tools overlays are sectors 46-49 (`ov2`-`ov5`). How full they are: 46 full, 47 about 500 bytes free, 48 about 45 free, 49 about 30 free.
- **Shared memory around the overlay area:**
  - FZ calls go through `L6004X` (`fx/fx4m.asm:18`), which, with live FX and capture off, moves the stack to DBFEh. The stack grows down towards the overlay's end signature. Existing overlays put code that makes FZ calls low, so a deep stack only reaches data.
  - Every non-filter render clears `KSB` = D400h-DBFFh (`FXONE`, `fxkz.asm:1479-1486`), once per voice and per chop slice, so it overwrites any loaded overlay.
  - The curve build uses D400h-D801h (`fx5k.asm:32`). The filter's scratch, map and variables use D400h-DBFDh (`svfi.asm:16-21, 455-465`). Position's variables are at D7F0h-D7FDh (`fx3i.asm:13-17`).
  - Echo and position (modes 12 and 13) use `DBUF` D400h and `TBUF` D600h (`fx3i.asm`).
  - `LVBUF` (D2F0h-D3EFh) is the live FX buffer, the wave writer's chunk buffer and capture's saved settings (`LVBUF+40h` = CAh marker).
- **Tests:**
  - `work/fzed/tests/` has an emulator of FZED's own code (the ROM calls are stubbed). `original40.py`, `stretch40l.py` and `oneshot40n.py` are good models; run them with `VER=fzed` after copying `fzedflat.bin` and `fzed.map` into `tests/`.
  - `stretch40l.py`, `oneshot40n.py`, `stretch40.py` and `tools40.py` are in FZED-private only. There, `stretch40.py` (1 check) and `tools40.py` (4 checks) already fail on the current build: their expected messages are out of date.
  - Editor tests: `work/fz_browser_editor/test_fakedom/*.cjs` (Node).

## 2. Step 1: preset waves into an overlay

### What the code does today (`fx/fx4m.asm`, the `lv` area)

- **CC111, `WVSEL` (line 47):** `v>>3` gives 0 (off) or 1-15; `WSEL` = band - 1.
- **CC9, `WVCC` (line 55):** below 64 arms; 120+ loads once. `cmp byte [WSEL],7 / jae .r` refuses bands 8-15, so CC111 values 64-127 are unused today.
- **`WVLOAD` (line 70, about 375 bytes):**
  - Refuses with capture on (line 71) or in bank mode, before releasing live FX (line 75). After that it refuses with chop slices, while recording, if a new voice can't be allocated (line 94), if the end is before the start (line 112), or for a voice under 1808 words (line 114).
  - Calls: `LVOFF`, `WVSH` (`tools40.asm`), `INIT`, `PSETUP`, `AFTER`, `LVWR`, `DEC2`, `NMSG`. ROM calls in the tree: 117, 119 (delete, 412h-byte frame), 169 and A2h (print).
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

## 5. Review 1 and decisions

The first review (Fable, 10 Nov) confirmed the build, sizes, line numbers, sector-50 layout and that the emulator loads overlays from the flat image (`t8g2.py:16`). Corrections are folded into sections 1-2 above. These change the plan.

### Step 1 changes

- **Stack margin is the real risk, not eviction.**
  - Eviction is safe: nothing in `WVLOAD`'s tree reaches `OVCALL` or ROM call BFh, and `PARSE` only runs from the main loop.
  - But ROM call 119's frame takes the stack from DBFEh down to about D7ECh, only 30-45 bytes above the end signature before an interrupt lands. The wave functions and `S_WV` run after the FZ calls, so "FZ-calling code first" doesn't protect them.
  - Plan:
    - Keep the top of the sector empty: new waves fill upward, so the newest is the first casualty.
    - After the FZ calls, check `[D7BEh] == 4032h` and refuse (`WAVE: REFUSED`) if it changed.
    - Add an emulator stub that scribbles 412h bytes below sp on ROM calls 117, 119 and 169, so tests can catch a clobber.
- **Keep today's refusal messages.**
  - Test `CAPON` and `BKON` in `WVCC` before the stub, about 14 resident bytes. Capture on then still shows `WAVE: REFUSED`, and bank mode still leaves live FX alone.
  - Keep `WVLOAD`'s own `LVOFF`.
- **Disk dependency (user-visible change).** A wave load will need the FZED disk in the drive after any render, capture, tool use or buffer-using live effect. Today it never does. With the disk out it shows `TOOLS NOT LOADED` after releasing live FX. On an HxC this is invisible; with a real floppy swapped out it is new. *Needs a decision from Neil.*
- **Test fixture.** The capture-test fixture refuses every wave. The bit-identical test needs a clean voice-mode setup.
- **Housekeeping.**
  - `mkimg.py`'s "holds something on the base disk" guard must cover sector 50.
  - Update the committed `tests/fzedflat.bin` and `fzed.map`, `outputs/`, the "33 sectors" / "32 KB" comments and the stale error text at `fzed.asm:2868`.
  - New wave names also go in `remote_sl/build_sl_templates.py` (lines 102, 130) and `make_cc_appendix.py`.

### Step 2 changes (still optional, after Step 1 is stable)

- **Selection:** leave CC112's 15 bands alone. Add a separate selector (0 = off, n = module) that overrides the type inside `FXMOF`.
  - That needs a jump from `xt` (3 bytes free) into `lv`.
  - Option (c) would move 8 of the 15 types for presets built by `build_presets.py:38`. Option (a) would silently change old presets.
- **The hook is bigger than 5-8 bytes.**
  - `FXRUN` sends mode 12 or more to the live-engine render (`fxkz.asm:258`) and mode 9 or more to the fast loop (`fxkz.asm:297`).
  - `LPW`/`LPM` have 14 entries, so a mode of 14 or 15 would read past them into code.
  - Most of the hook goes in `lv`, with jumps from the high area (10 bytes free).
- **Rendering:**
  - `FXONE`'s D400h clear would erase the module, so EXT must skip it.
  - Prefer a chunk entry in the `FXLP` form (called once per 256 words) to a per-sample call.
- **Names:** show a resident "EXT" when it's selected and the module's name at render start. Never load a module on a knob sweep (disk access, live FX released).
- **Versioning:** the signature encodes only the sector. Modules need an ABI version field and fixed entry points, so a newer disk in the drive can't make an older program jump to wrong addresses.

### Existing low risk (not caused by this plan)

- Echo and position overwrite D400h but seem to leave D7BEh. A sample word equal to the signature there would pass `OVCALL`'s check, which also tests D400h.
- Possible fix: clear D7BEh whenever a buffer user claims the area. To be checked separately.
