# FZED live FX performance review

12 November 2026. Reviewed against `next` at ecb1993. Nothing in `work/fzed` is changed by this
folder: the code is offered as diffs in `diffs/`, and the scripts that produced the numbers are
in `harness/`.

## Conclusion

Yes, there is a worthwhile gain, and almost all of it is bit-identical. Changes that fit in today's free space make a live pass 10 to 30% shorter in most modes, which is 12 to 45% more words per second, and more than twice the speed for bit mangle and position when fully wet.

- **The mix.** The one-multiply form is exact, not approximate, once the overflow is handled with a small fix-up. With the other changes it takes a quarter to a third off most mixed passes on a V50, and more on 8086 timings.
- **The read into `LVBUF`.** Replacing its hand-written loop with a block move saves 3,100 clocks per chunk in every mode and frees 24 bytes.
- **The `MIXW` call.** Five modes call it for every word even when fully wet. Dedicated wet loops fix two of them now and three more once the wave overlay frees lv.
- **Outside the loops.** The mod matrix costs 4,650 clocks per pass with nothing routed; a third of that goes with a ten-byte change.
- **Tube2** stays the slowest mode. Exact changes gain 14%; anything more means changing how it sounds.

Three cautions. The set that fits today uses every free byte in the high and xt areas. All figures are emulator counts with data-sheet timings, so the percentages are reliable but words per second are not. And the ROM's timer interrupt probably takes a third to a half of the CPU, which nothing in FZED can recover.

## How the live path works

Live FX processes one 128-word chunk per main-loop pass, so throughput is 128 words times the pass rate. Everything the main loop does besides the effect counts against it.

**Each pass** (`fzed.asm:258-284`): the ROM key poll (call 6), `CAPTICK` (LFOs), `MATRIX`, `LVRUNX` (paced LCD, one curve-build step, then `LVRUN`), and `PARSE`.

**`LVRUN`** (`fx/fxkz.asm:916`):

- While the clean copy is being made, it copies 128 words per pass (`LVCPY`, `:1245`).
- Once live, three passes in four process the chunk just ahead of the playhead and the fourth advances a sweep over the whole voice.
- The chase reads the playhead from the gate array (`LVFINDPH`, `:852`) and stays within 512 words ahead of it (`:949-963`).
- With no note playing, every pass sweeps.

**Each chunk** (`LVCHK`, `:1012`):

1. `LVSEG` finds the segment or slice.
2. `LVRD` copies 128 words from the clean copy into `LVBUF` (D2F0h, 256 bytes), switching the bank through port 22h.
3. A per-mode preparation runs where needed: Tube2's previous word, the decimator's block position, the echo and position source words (`:1069-1096`).
4. The mode's loop runs over `LVBUF` through `call [LVLP]` (`:1116`).
5. `LVWR` block-moves the result into the voice.

**Loop selection**: `FXPAR` picks the loop from two tables (`:466-473`): `LPW` when Wet/Dry is fully wet (FXW = 16384), `LPM` otherwise. Only TapeHack, linear crush and ring mod have a separate wet loop. For Tube2, filter, rectifier, decimator, bit mangle, echo and position both tables hold the same loop, which tests FXW for every word.

| Mode (internal number) | Fully wet loop | Mixed loop | Per word |
| --- | --- | --- | --- |
| TapeHack, Tape>Pockey, Wavefolder, XOver fuzz (1, 2, 5, 14) | `FXLT` `:1537` | `FXLTM` `:1560` | Curve table lookup with interpolation: one multiply, plus two for the mix |
| Linear crush (3) | `FXLC` `:1593` | `FXLCM` `:1603` | Mask and offset, plus two multiplies for the mix |
| Ring mod (4) | `FXLR` `:1623` | `FXLRM` `:1641` | Sine table times sample: one multiply, plus two for the mix |
| Tube2 (7) | `FXLU` `:1844` | same | Curve lookup, a square root (`SQRTQ` `:1781`), four more multiplies, then the mix |
| Filter (8) | `SVLV` `fx/svfi.asm:397` | same | State-variable filter: four multiplies and five saturations (`SVK8` `:44`) |
| Rectifier (9) | `FXLX` `fx/fx2h.asm:122` | same | One multiply on negative words, then `call MIXW` |
| Decimator (10) | `FXLD` `:140` | same | Hold counter kept in memory, then `call MIXW` |
| Bit mangle (11) | `FXLB` `:158` | same | One XOR, then `call MIXW` |
| Echo / comb (12) | `FXLE` `fx/fx3i.asm:238` | same | One multiply and a saturating add, then `call MIXW` |
| Position (13) | `FXLQ` `:260` | same | Copies a prepared word, then `call MIXW` |
| Karplus-Strong (6) | `LVKSCH` `fx/fxkz.asm:1152` | same | Own path: reads its history back from the voice; two multiplies, plus two for the mix |

Pockey2 (0) has no live loop.

## What it costs today

Tube2 is the slowest mode by a factor of four, and in every mode a third or more of each pass is spent outside the effect loop.

These are emulator counts on the unmodified `next` build: the repo's emulator ran the real binary, and every executed instruction was costed from the listing with NEC V30 data-sheet timings (the V50's core) and with Intel 8086 timings. "Mixed" is Wet/Dry at CC117 = 100. The words-per-second column assumes FZED gets every clock of an 8 MHz CPU, which it does not; see "CPU, clock and what is not verified".

| Mode | Loop, clocks per word (V50): wet / mixed | Same, 8086 timings | Whole pass, clocks (V50): wet / mixed | Words per second if FZED had the whole CPU: wet / mixed |
| --- | --- | --- | --- | --- |
| Linear crush | 77 / 230 | 98 / 512 | 23,600 / 42,300 | 43,300 / 24,200 |
| Bit mangle | 119 / 303 | 144 / 594 | 29,300 / 52,300 | 34,900 / 19,600 |
| Position | 123 / 307 | 146 / 596 | 35,600 / 58,600 | 28,800 / 17,500 |
| Ring mod | 138 / 321 | 285 / 735 | 31,000 / 53,400 | 33,000 / 19,200 |
| Rectifier | 171 / 355 | 248 / 699 | 35,700 / 58,800 | 28,700 / 17,400 |
| TapeHack family | 186 / 339 | 386 / 800 | 37,700 / 56,800 | 27,200 / 18,000 |
| Decimator | 197 / 381 | 237 / 687 | 38,500 / 62,300 | 26,600 / 16,400 |
| Echo / comb | 204 / 388 | 336 / 786 | 43,700 / 66,700 | 23,400 / 15,400 |
| Filter | about 420 / 600 | about 870 / 1,320 | 66,700 / 89,500 | 15,300 / 11,400 |
| Tube2 | 871 / 1,022 | 1,735 / 2,145 | 123,600 / 142,700 | 8,300 / 7,200 |

Karplus-Strong runs its own shorter chunks (13,700 / 16,000 clocks per pass) and is not broken down per word.

**Why the slow ones are slow**

- **The mix** costs about 150 clocks per word on a V50 and about 410 on an 8086, in every mode: two 16-bit multiplies, then `shr ax,14 / shl dx,2`, which the V50 executes one bit at a time.
- **Five modes call `MIXW` for every word even when fully wet.** The call, the FXW test and the return cost 58 clocks to do nothing. That is why bit mangle, one XOR, costs 119.
- **Tube2** spends 306 clocks per word in `SQRTQ` and 153 in `TLOOK`. A third of the square root is its normalising loop, which runs up to seven times on small values.
- **The decimator** keeps its counter and held word in memory and reloads them for every word.

**Where the rest of the pass goes** (TapeHack fully wet, 37,700 clocks)

| Part | Clocks | Share |
| --- | --- | --- |
| Effect loop, 128 words | 23,800 | 63% |
| `MATRIX` | 4,650 | 12% |
| `LVRD`, clean copy to `LVBUF` | 4,400 | 12% |
| `LVCHK` bookkeeping and `LVSEG` | 1,650 | 4% |
| `LVWR`, `LVBUF` to the voice | 1,200 | 3% |
| `CAPTICK` (LFOs) | 770 | 2% |
| `LVFINDPH` | 720 | 2% |
| Key poll, `PARSE`, the rest | 500 | 1% |

`LVRD` costs 3.5 times `LVWR` for the same 128 words: it moves them with a hand-written loop (`fx/fxkz.asm:1296-1321`), while `LVWR` uses `rep movsw`. `MATRIX` costs 4,650 clocks with nothing routed, for one voice.

## Tier (a): bit-identical improvements

Every change in this tier produced the same wave memory as the `next` build, word for word, in all 430 emulator cases (see "How this was tested"). The full code is in `diffs/`; the key routines are shown here.

### Set 1: fits in today's free space (`diffs/1_fits_today.diff`)

Measured whole-pass cost, V50 clocks, before and after:

| Mode | Fully wet | Mixed (CC117 = 100) | 8086 timings: wet / mixed |
| --- | --- | --- | --- |
| Position | 35,600 to 13,700 (-62%) | 58,600 to 40,000 (-32%) | -54% / -39% |
| Bit mangle | 29,300 to 14,300 (-51%) | 52,300 to 39,700 (-24%) | -48% / -35% |
| TapeHack family | 37,700 to 30,600 (-19%) | 56,800 to 40,600 (-29%) | -21% / -36% |
| Echo / comb | 43,700 to 36,000 (-18%) | 66,700 to 47,500 (-29%) | -15% / -33% |
| Linear crush | 23,600 to 19,500 (-17%) | 42,300 to 28,800 (-32%) | -16% / -41% |
| Karplus-Strong | 13,700 to 11,600 (-15%) | 16,000 to 13,900 (-13%) | -14% / -11% |
| Tube2 | 123,600 to 105,900 (-14%) | 142,700 to 117,400 (-18%) | -16% / -22% |
| Ring mod | 31,000 to 27,100 (-13%) | 53,400 to 38,800 (-27%) | -8% / -31% |
| Rectifier | 35,700 to 31,300 (-12%) | 58,800 to 41,200 (-30%) | -11% / -36% |
| Decimator | 38,500 to 34,700 (-10%) | 62,300 to 46,400 (-25%) | -10% / -34% |
| Filter | 66,700 to 62,200 (-7%) | 89,500 to 72,700 (-19%) | -4% / -21% |

A pass that is 29% shorter processes 41% more words per second.

**1. One-multiply mix** (`FXLTM`, `FXLCM`, `FXLRM`, `FXLU` in `fx/fxkz.asm`; `MIXW` at `fx/fx2h.asm:103`; `SVK8` at `fx/svfi.asm:95`)

It is a real saving and it is exactly bit-identical, so it belongs in tier (a), not (b). The mixed TapeHack loop drops from 339 to 245 clocks per word on a V50, and from 800 to 501 on an 8086.

- **Why it is identical.** FXW2 is always 16384 - FXW (`fx/fxkz.asm:415-417`), so wet\*FXW + dry\*FXW2 = dry\*16384 + (wet - dry)\*FXW. Shifting right by 14 takes dry out whole: the result is dry + floor((wet - dry)\*FXW / 16384), with no rounding difference.
- **The overflow.** When wet - dry does not fit 16 bits, the true difference is the 16-bit result plus or minus 65536, so the true product is the 16-bit product plus or minus FXW in the high word. `MIXOV` applies that from the flags the subtraction left. It still costs one multiply.
- **The shift.** Two `shl ax,1 / rcl dx,1` pairs leave the result in DX for 8 clocks; the old `shr ax,14 / shl dx,2 / or` took 32.

```nasm
    mov bx,[es:si]          ; dry
    sub ax,bx               ; wet - dry
    jo .of
    imul word [FXW]
.j: shl ax,1
    rcl dx,1
    shl ax,1
    rcl dx,1
    add dx,bx
    mov [es:si],dx
    ...
.of: call MIXOV
    jmp .j

MIXOV:              ; wet - dry did not fit 16 bits (flags from the SUB)
    js .p
    imul word [FXW]
    sub dx,[FXW]
    ret
.p: imul word [FXW]
    add dx,[FXW]
    ret
```

Bytes: each inline mix shrinks by 1 to 5 bytes; `MIXOV` adds 20 in the high area; `MIXW` grows by 1 in xt.

**2. `LVRD` as a block move** (`fx/fxkz.asm:1296`)

Saves 3,100 clocks per chunk in every mode (4,400 to 1,300) and frees 24 bytes in the high area.

```nasm
LVRDX:
    push di
    call LVSET
    pop di
    cld
.l: call LVRUNN             ; ax = words in this run, cx = words after it
    xchg ax,cx
    push es                 ; rep movsw reads DS:SI: DS on the sample window
    push ds
    pop es
    pop ds
    rep movsw
    push es
    push ds
    pop es
    pop ds
    mov cx,ax
    jcxz .r
    call LVBK
    jmp .l
.r: ret
```

Risk: DS is 1000h during the move. I checked the ROM: all four interrupt handlers it installs (at ROM 0A1Bh, 08E0h, 23E7h and 0943h) load DS = 0 themselves before touching memory, and FZED has no interrupt code of its own. The move is the mirror image of what `LVWR` already does with ES. It still needs a soak test on hardware.

**3. Fully wet loops without the `MIXW` call** (bit mangle and position)

Bit mangle drops from 119 to 35 clocks per word, position from 123 to 8. `LPW` points at them; `LPM` keeps the mixed loops. `FXLBW` also serves the render, which uses the same table.

```nasm
FXLBW:              ; bit mangle, fully wet
    mov ax,[MGM]
.l: xor [es:si],ax
    add si,2
    loop .l
    ret
FXLQW:              ; position, fully wet: the chunk is DBUF
    mov di,si
    mov si,DBUF
    rep movsw
    ret
```

**4. Cheaper shifts in the table lookups** (`FXLT`/`FXLTM` `:1549`, `:1572`; `TLOOK` `:1816`; `SQRTQ` `:1799`)

The V50 shifts by a count one bit per clock, so `shr ax,6 / shl dx,10 / or ax,dx` costs 32 clocks. Two `shl/rcl` pairs and two byte moves give the same word in 12. Saves 20 clocks per word in the TapeHack family and 24 each in `TLOOK` and `SQRTQ`.

**5. `SQRTQ` normalising** (`:1784`)

Values below 256 take four of the loop's steps at once (`xchg al,ah / mov cl,4`). With the shift changes, Tube2 drops from 871 to 784 clocks per word. The saving depends on the signal: quiet or slow-moving audio gains most.

**6. `MATRIX` with nothing routed** (`fx/matrixz.asm:806`)

A record with no destination in use this pass or last pass skips both destination loops and goes straight to the glide step. Saves 1,550 clocks per pass per voice (4,650 to 3,100), costs 10 bytes.

```nasm
    mov [bx+MXUSE],ax
    cmp word [MXOLD],0
    jnz .w
    jmp PTICK
.w: mov word [MXD0],1
```

**Where the bytes come from.** The set needs more room than is free, so it removes 17 `cs:` prefixes from table reads in routines that already read their variables through DS (`FXPAR`, `SQRTQ`, the crush and mu-law tables, `FXMOF`). Each is one byte and two clocks. After the set: low 16 free (unchanged), high 0 (was 10), lv 2 (unchanged), xt 0 (was 3). That leaves no slack in high or xt; about 75 more `cs:` prefixes remain in resident code if you accept the same assumption, DS = CS, for them.

### Set 2: needs the wave overlay (`diffs/2_needs_wave_overlay.diff`)

Three more fully wet loops, about 105 bytes in lv. To build and test them I cut the wave generator out of the scratch copy to stand in for the overlay (`harness/patch_ov.py`).

| Mode, fully wet | Loop, clocks per word | Whole pass |
| --- | --- | --- |
| Decimator (`FXLDW`: counter and held word in registers) | 197 to 62 | 34,700 to 17,600 |
| Rectifier (`FXLXW`) | 171 to 104 | 31,300 to 22,900 |
| Echo / comb (`FXLEW`: gain in a register) | 204 to 120 | 36,000 to 25,700 |

The same diff gives Karplus-Strong the one-multiply mix (mixed pass 13,900 to 12,700). That change is shorter than the code it replaces, so it does not depend on the overlay.

## Tiers (b) and (c)

### Tier (b): differences of at most 1 LSB

Nothing here is worth doing. The obvious candidate, the one-multiply mix, turned out to be exact. The other rounding-only ideas I looked at either save a couple of clocks (dropping the carry after a Q15 multiply) or change more than 1 LSB (16-bit filter state).

### Tier (c): audible approximations

**c1. Curve lookup without interpolation** (`diffs/4_tier_c_no_interpolation.diff`, on top of set 1; fits today and frees 44 bytes in the high area)

TapeHack, Tape>Pockey, Wavefolder and XOver fuzz take the nearest of the 513 curve points instead of interpolating between two.

| | Loop, clocks per word | Whole pass |
| --- | --- | --- |
| Fully wet | 166 to 88 | 30,600 to 21,000 (-31%) |
| Mixed | 245 to 167 | 40,600 to 30,800 (-24%) |

- Measured against the interpolated result over the test voice: TapeHack, Tape>Pockey and Wavefolder differ by at most 75 LSB, with an RMS error of -59 to -75 dB below full scale.
- What you would hear: a faint grit on smooth, quiet material, as if the curve had about 10 bits of resolution. Words within 32 levels of zero all become the curve's first point.
- XOver fuzz is the exception: at a hard setting the largest difference was 13,000 LSB (RMS -21 dB), because its curve has a step at the crossover and the nearest point lands on the other side of it. Keep interpolation for that mode if you use this.

```nasm
    mov bx,ax               ; |sample|
    add bx,32               ; the nearest curve point
    shr bx,5
    and bx,0xfffe
    mov ax,[bx+THT]
    xor ax,bp               ; sign back
    sub ax,bp
```

**c2. Wet/Dry in quarters** (`diffs/5_tier_c_quarter_mix.diff`, on top of set 2; needs about 100 bytes, so it needs the overlay)

`FXPAR` rounds FXW to 0, 25, 50, 75 or 100% and writes the matching shift sequence into `MIXW`, so the five `MIXW` modes mix without a multiply.

| Mode, mixed | Loop, clocks per word |
| --- | --- |
| Rectifier | 257 to about 190 |
| Decimator | 292 to about 230 |
| Bit mangle | 239 to about 200 |

- What you would hear: the Wet/Dry knob moves in five steps, in every mode, because they share FXW. With the knob between steps the output differed from today's by up to -27 dB RMS, which is simply the mix being somewhere else.
- I would not take this one. It gains 15 to 20% of the pass in five modes, only when mixed, and gives up a continuous control to do it. It also adds self-modifying code.

**Not built.** Tube2 is where an approximation would pay most: the square-root slew stage is roughly half of its 784 clocks per word. Replacing it changes the character of the effect, so that is a design decision more than an optimisation.

## Outside the inner loops

After set 1, about 5,000 clocks of each pass are still spent on work that is not tied to the chunk, and the ROM's timer interrupt probably takes more CPU than anything FZED does.

**Two chunks per pass** (`diffs/3_two_chunks_per_pass.diff`: one extra `call LVRUNW` after `call LVRUNX` at `fzed.asm:283`)

| Mode | Clocks per chunk, one chunk per pass | Two chunks per pass |
| --- | --- | --- |
| Linear crush, fully wet | 19,500 | 16,800 (-14%) |
| Linear crush, mixed | 28,800 | 26,400 (-8%) |
| TapeHack, fully wet | 30,600 | 28,300 (-8%) |
| TapeHack, mixed | 39,600 | 38,200 (-4%) |

- The cost is control latency: MIDI, the LFOs and the matrix are then served once per two chunks.
- Output was identical in every mode except Karplus-Strong, whose live result depends on the order and timing of chunks by design (it reads its own output back from the voice).
- It takes 6 bytes in the low area (16 free today).

**Chase and sweep ratio** (`fx/fxkz.asm:943-945`). One pass in four always sweeps, even while a note is playing and the chase is only just ahead of the playhead. Sweeping only when the chase cursor has reached its 512-word lead would give the chase up to a third more words per second. I did not build this.

**Chunk size.** 128 words is fixed by `LVBUF` (256 bytes at D2F0h, directly below D400h). A larger chunk needs a larger buffer; two chunks per pass gets the same effect without one.

**Curve rebuilds** (`CBSTEP`, `fx/fx5k.asm:250`). A changed curve is rebuilt 32 entries per pass, so about 17 passes for the 513-entry table. For Tube2 I measured about 20,000 extra clocks per pass while a rebuild runs. This affects how fast a knob move lands, not steady throughput.

**Bank switching.** `LVSET` reads and writes port 22h once per transfer, twice per chunk, about 40 clocks in total. There is nothing to gain there.

**`MATRIX` pacing** (`fx/matrixz.asm:705`). It is paced to run about every 1.2 ms, but a live pass is longer than that, so it runs on every pass. Item 6 above removes a third of its idle cost; the ten-slot scan per record (about 1,000 clocks) remains.

**ROM calls while live is on.** Only call 6, once per pass. In the ROM it is a few instructions that read one byte at 042Ch; with the INT 3 gateway it costs about 300 clocks. The LCD print (call A2h) runs only when a message is due. Calls 117 and 169 run only when live is switched on or released.

**The ROM timer interrupt.** This is the largest unknown.

- The handler (ROM 0A1Bh) re-arms timer 0 on every tick and walks eight voice entries. I count about 750 clocks for the shortest path.
- Every eighth tick it also runs the key scan, the ROM's MIDI parser and voice housekeeping.
- The project's status log records 3,240 ticks per second measured on hardware.
- Taken together, my estimate is that interrupts use somewhere between a third and a half of the CPU. That is an inference from reading the ROM, not a measurement.
- Because the ROM parses MIDI inside that interrupt, a dense CC stream slows live FX whatever FZED does.

## CPU, clock and what is not verified

The relative gains above are solid; every absolute words-per-second figure is unverified until measured on the FZ.

**CPU clock: 8 MHz, derived from the ROM, not from MAME.** I could not open MAME's FZ-1 driver source: the fetch tool refused the MAME repository pages and search did not return the file. The ROM's own setup gives the clock instead:

- It writes 0 to the V50's timer clock register (FFF0h), which selects CPU clock / 2 for the timers.
- It sets timer 1 to divide by 8 and the serial unit to a x16 clock.
- MIDI is 31,250 baud, so the timer clock is 31,250 x 16 x 8 = 4 MHz and the CPU clock is 8 MHz.

This rests on my reading of the V50 register meanings from memory. The V50 manual was not available to me; please check the register meanings against it.

**Wait states.** The ROM writes 44h to FFF5h and 11h to FFF4h. I read that as one wait state on the memory block that holds the sample window, and on I/O. That adds about 250 clocks per pass, under 1%. Whether the gate array stretches CPU accesses further while voices play cannot be seen from the code.

**Timings.** V50 counts use NEC's V30 data-sheet figures as I know them, with multiplies at the middle of their range (signed 16-bit: 44 clocks register, 50 memory). I could not check them against MAME's table. 8086 counts use Intel's tables with address-calculation times; the 186-only shift-by-count instructions are costed as the CL form. The tables are in `harness/cyc.py`.

**MAME.** It was not installed in the review session and could not be installed, so nothing here was measured in MAME. Both MAME and this model charge fixed clocks per instruction, so I would expect MAME to reproduce the relative gains closely. Its absolute rate depends on how well the driver models the timer interrupt and the gate array, which I could not inspect.

**What needs hardware, and how to measure it**

| Unknown | How to measure |
| --- | --- |
| The share of the CPU that interrupts take | Render TapeHack fully wet with no notes and no MIDI, and read the `nnnnn/S` figure. Multiply by 190 clocks per word plus the chunk overhead; the result is the clocks per second FZED really gets. Repeat with a dense CC stream running. |
| Live words per second | A debug build that counts chunks in `LVCHK` and prints the count every 3,240 timer ticks. Compare old and new builds on the same voice. |
| Whether the `LVRD` block move is safe under interrupts | Run live FX for several minutes with notes held and MIDI streaming, switch live off, and compare the restored voice with a saved copy. The restore uses the same routine. |
| Slowdown from the gate array while voices play | The same chunk counter, with zero, one and eight notes sounding. |
| The timer tick rate | Already measured at 3,240 per second. The ROM's reload value suggests up to 4,000, so the difference is time the handler itself takes. |

## How this was tested

All builds ran in scratch copies made with `work/fzed/build.sh`; a fresh build of `next` reproduces the committed `tests/fzedflat.bin` byte for byte.

**Emulator comparison.** Each build ran in the repo's emulator (`tests/emu.py`, on the `tchop.py` fixture) with a 1,536-word test voice: sine, full-scale noise, extreme values, low-level noise, a clipped sine and a ramp.

- **Sweep:** live FX with no note, 14 live modes x 10 settings (three parameter sets; Wet/Dry at 127, 126, 100, 90, 64, 33, 1, 0). 140 cases.
- **Chase:** the same with a note playing and the playhead moving, so the chase path runs. 140 cases.
- **Render:** CC118 on all 15 modes with the same settings. 150 cases.
- The processed voice was compared word for word with the `next` build's, and so was the voice restored after live off.
- Set 1 and set 2: 430 of 430 identical. The runs reached both branches of `MIXOV` and the overflow exits of every mix except linear crush, whose wet and dry words are never far enough apart.

**Two things about the harness you should know**

- The emulator treats any DS other than 0 as unknown memory. For the `LVRD` change the harness extends it (in `harness/lvh.py` only) so that DS = 1000h reads the sample window as ES = 1000h already does.
- Karplus-Strong reads its own output back from the voice, so its result depends on how many passes run between events. The old and new runs are synchronised by pass count; with that, it matched too.

**Cycle counts** come from the same runs: each executed instruction is looked up in the build's listing and costed. They are emulator counts with table timings, not hardware timings.

**ROMs.** I read the reset code, the INT 3 gateway, call 6 and the interrupt handlers in a scratch copy. This report quotes only addresses and register values from them.

## Files

| File | Contents |
| --- | --- |
| `diffs/1_fits_today.diff` | Set 1: the six tier (a) changes that fit now |
| `diffs/2_needs_wave_overlay.diff` | Set 2: three fully wet loops for lv, and the Karplus-Strong mix |
| `diffs/3_two_chunks_per_pass.diff` | The one-line scheduling change |
| `diffs/4_tier_c_no_interpolation.diff` | Tier (c) c1 |
| `diffs/5_tier_c_quarter_mix.diff` | Tier (c) c2 |
| `harness/` | The measurement and comparison scripts; see its README |

Diff 1 applies to `next` on its own (`patch -p1` from the repo root); 2, 3 and 4 each apply on top of 1. I checked that they apply cleanly and that 1, and 1 with 3, rebuild to the binaries tested. Diff 2 will not assemble until the overlay has freed lv. Diff 5 applies on top of 2 as built in scratch, where the wave generator was cut out; it will need re-basing once the overlay exists.
