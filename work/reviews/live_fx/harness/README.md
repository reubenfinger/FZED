# Live FX measurement harness

These scripts produced the numbers in `../LIVE_FX_PERFORMANCE_REVIEW.md`. They run a build of
`work/fzed` in the repo's own emulator (`tests/emu.py`, on the `tchop.py` fixture), turn live FX
on, and either compare the processed voice between two builds or count clocks.

Nothing here touches `work/fzed`. Work on copies.

## Setting up

```sh
cp -r work/fzed /tmp/old  && (cd /tmp/old  && sh build.sh)    # the unmodified build
cp -r work/fzed /tmp/new  && python3 patch_a.py /tmp/new && python3 patch_a2.py /tmp/new \
                          && (cd /tmp/new && sh build.sh)     # set 1 (same as diffs/1_fits_today.diff)
```

The other patch scripts build the other variants, each on a copy of the one before:

| Script | Applies to | Gives |
| --- | --- | --- |
| `patch_a.py`, then `patch_a2.py` | `next` | Set 1 |
| `patch_ov.py` | Set 1 | Set 2. It cuts the wave generator out of `fx4m.asm` to stand in for the overlay, so that build is for testing only |
| `patch_2x.py` | Set 1 | Two chunks per pass |
| `patch_c1.py` | Set 1 or set 2 | Tier (c): no curve interpolation |
| `patch_c2.py` | Set 2 | Tier (c): Wet/Dry in quarters |

Build directories must be given as absolute paths.

## Comparing two builds

```sh
./runeq.sh /tmp/old /tmp/new mytag
```

runs sweep, chase and render for all 15 bands on both builds (two processes) and prints the
differences. `eq.py` is the runner, `cmp.py` the word-for-word comparison, `cmpc.py` the
error statistics used for tier (c). `runnew.sh` re-uses stored results of the old build.

## Counting clocks

```sh
python3 -I m1.py /tmp/old old.json 127,100        # every band, fully wet and at CC117 = 100
python3 -I m1.py /tmp/new new.json 127,100
python3 -I tab.py old.json new.json               # side by side
python3 -I brk.py old.json                        # where each pass goes
python3 -I prof.py /tmp/old 10 127 SQRTQ          # per-routine and per-instruction profile of one band
```

`cyc.py` holds the timing tables (NEC V30 data-sheet figures for the V50, and Intel 8086) and
maps executed addresses to source lines through the build's `fzed.lst`. `lvh.py` is the harness
itself; `sig.py` is the test voice.

## Linear crush DeFreq, live against render

```sh
python3 -I crusheq.py /tmp/new RATE DEFREQ MIX BITS     # e.g. 0 127 127 90: rate index 0, hold 26 words
```

runs live linear crush with DeFreq over the test voice at the given voice rate index (0-3), then renders the
same settings, and prints whether the two give the same words. The `runeq.sh` fixture plays at rate index 3,
where DeFreq below about 127 gives a hold of 1 word, so it does not exercise the hold.

## Things to know

- **DS = 1000h.** `tests/emu.py` treats any DS other than 0 as unknown memory. `lvh.py` wraps
  the emulator's memory reads so that DS = 1000h reads the sample window, which the `LVRD`
  block move needs. This is a change to the test model, not to the emulator file.
- **Pass-synchronised.** `eq.py` sends each CC at a main-loop boundary and waits a number of
  passes, not steps. Karplus-Strong reads its own output back from the voice, so two builds
  only match when they run the same number of passes between events.
- **Self-modified code** (`SVK8`, and `MIXW` in the c2 variant) is not in the listing as
  instructions, so `cyc.py` leaves those few instructions out or costs them as written. The
  filter figures in the report are marked "about" for that reason.
- **ROM time is not counted.** ROM calls are stubs in the emulator, and interrupts do not run.
- A full `m1.py` run takes about 25 minutes; a full `runeq.sh` about 15.
