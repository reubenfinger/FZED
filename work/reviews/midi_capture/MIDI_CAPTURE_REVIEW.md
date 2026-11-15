# FZED MIDI handling review (capture: map only)

Reviewed: `next` at `f9bce8b`. Nothing on `next` or `main` was changed; all builds were scratch copies.

**This review is incomplete.** The session ran short. The MIDI path is mapped, measured in the emulator and has one built and tested improvement. Capture mode is mapped from the source only, with no measurements and no example code. The speed-gap section lists causes and measurements but does not settle the cause. Section 8 lists what was not done.

## 1. Conclusion

There is a worthwhile gain, and it is in one place: **FZED applies at most one CC per main-loop pass, and a pass with live FX on is one whole live chunk.** On the real FZ that is about 65-75 CCs a second with a TapeHack-family effect on and about 35 with Filter. Three knobs moving at 40 messages a second each (120 CCs a second) is more than that, so a backlog builds: CCs arrive up to 0.7 s late, and after about 1.5 s the 256-byte receive ring wraps and FZED silently skips 256 bytes of MIDI.

Diff B1 (11 bytes, built and tested) lets a pass apply up to four CCs. In the same test nothing is late and nothing is lost with TapeHack on. Filter still falls slightly behind at that rate.

MIDI clock is only counted when `PARSE` reaches the clock byte, so it is late by up to one pass (about 13 ms idle or with TapeHack, about 27 ms with Filter), and by the whole backlog when CCs are queued in front of it.

## 2. Timing basis (read this before any number below)

Every time below is given two ways where it matters:

- **Data-sheet clocks**: emulator instruction counts with NEC V30 data-sheet timings (`../live_fx/harness/cyc.py`). ROM calls are stubbed and count as nothing.
- **Real FZ time**: data-sheet clocks divided by **2.32 million a second**, which is 0.29 of 8 MHz. That factor comes from the FZ readings on `a183437`: TapeHack about 9,500 words a second against 33,300 predicted, and Tube2 about 2,750 against 9,400. It is not the earlier review's interrupt estimate, which implied 0.5-0.67 and was wrong.

A pass of 30,000 data-sheet clocks is therefore about 13 ms on the FZ, not 4 ms.

The factor was measured with one voice and light MIDI. Under a heavy CC stream the same build read 5,632-7,040 words a second, so the factor falls to roughly 0.17-0.21 there, because the ROM also parses every byte inside its timer interrupt.

## 3. Why the earlier absolute figures were wrong: causes and tests

Not settled. What I could establish, and what each cause predicts:

| Cause | Evidence | What it predicts |
| --- | --- | --- |
| Code fetch time. Data-sheet timings assume the instruction is already in the prefetch queue | A bus-limited estimate (`harness/bus.py`: 6-byte queue, 4 clocks per fetched word, queue emptied on every taken jump) gives 1.08-1.24 times the data-sheet count: 1.17 for a TapeHack pass, 1.12 for Filter. It is an estimate, not a cycle-exact model | A constant slowdown of about 15%, the same with or without notes or MIDI. Too small alone |
| Programmed wait states | ROM reset code writes 11h to FFF4h, 44h to FFF5h, 01h to FFF6h. Read from memory of the V50 manual (unverified): no waits on the low 64 KB where FZED runs, one on sample memory and on I/O | Under 1% for FZED's own code |
| Memory refresh | ROM writes 8Eh to FFF2h. Read (unverified) as one refresh cycle every 240 clocks | About 2% |
| Timer interrupt load | The handler (ROM 0A1Bh) re-arms a 250 µs one-shot on every tick, yet the measured rate is 3,240 a second (308.6 µs). The extra 58.6 µs a tick is time the handler chain takes before the re-arm, or a long eighth tick (key scan, MIDI parser at ROM 0E46h, voice housekeeping at 1CD8h). With the short path at about 750 clocks and a 15% bus slowdown, interrupts come to about half of the CPU | A share of about 0.5 / 1.15 = 0.42, still above the measured 0.29 |
| Unexplained remainder (about 0.7) | Not visible in the ROM. Candidates: the gate array holding the CPU's READY line while it reads sample memory for playing voices; a third interrupt source (ROM 23E7h, which services gate-array voice events and sends it new loop addresses); data-sheet timings that are optimistic for the V50 | READY stretching predicts a slowdown that grows with notes held and is worse for code that touches sample memory. A voice-event interrupt predicts a slowdown that grows with looping notes |
| The time base itself | The 3,240 figure is one stopwatch calibration (52,680 interrupts in 16.26 s, during a render in October). `LVMEASURE` assumes it | If the tick rate is different while live FX runs, every words-per-second reading is off by the same ratio |

**What the ROM alone settles:** the programmed waits and refresh are small; the ROM's parser empties the receive ring completely on every eighth tick; only the timer interrupt stays on during recording. **What it cannot settle:** the READY line and the real interrupt share. **MAME:** not installed here, so nothing was measured in it. As far as I know its NEC core charges table clocks per instruction, so I would not expect it to reproduce a READY or bus effect either (unverified).

### Measurements that would tell them apart

| Test | Shows |
| --- | --- |
| Count timer ticks against a stopwatch for 60 s, four times: idle, live FX on, eight notes held, a CC stream running | Whether 3,240 holds in each state. A lower rate with notes or MIDI means the handler chain grew |
| With interrupts off for under 200 µs, read timer 0's counter (latch it through port C6h, read C0h), run a fixed register-only loop of about 1,000 data-sheet clocks, read it again. The counter runs at 4 MHz | The CPU's raw speed with no interrupt in the way. 500 counts means data-sheet speed; 575 means the bus-limited estimate is right; more means something else slows the CPU |
| The same timed loop reading and writing RAM in segment 0 | The cost of ordinary memory access |
| The same loop reading sample memory through the port 22h window, with no notes and with eight notes held | Whether the gate array stretches the CPU's sample-memory access |
| A free-running loop counter over one second (no cli), with no notes, one looping note, eight looping notes, and a CC stream | The share interrupts take in each state: divide by the raw speed from the timed loop |

**Where the bytes come from.** `LVMEASURE` no longer fits (lv has 13 bytes free). These tests need no resident bytes at all: on a test-only disk, sectors 44-45 can hold a test overlay in place of the capture overlay (`fx/capo.asm`). `CAPGO` loads it and calls it exactly as it does capture, `CAPTICK` then calls it once a pass, and `DISPATCH` calls its `CAPFLT` for every CC, so it can also count passes and CCs applied per second and the largest ring backlog. Live FX cannot run at the same time (both use D400h), so the live figures still come from words per second divided by 128. I did not write this overlay.

## 4. The MIDI path

Checked against the code; your description was right.

1. The ROM's serial interrupt (ROM 08E0h) writes each byte to the ring at 08D6h and increments the byte index at 09D8h. A framing or overrun error drops the byte. It compares the index only with the ROM's own read index (09D6h); if they meet it turns off all MIDI-played notes.
2. The ROM's parser (ROM 0E46h, every eighth timer tick, about 405 times a second) empties the ring through 09D6h. It plays the notes. FZED never sees this happen.
3. FZED reads the same ring with its own index at CS:8016h (`L6331`, `fzed.asm:2704`). Nothing protects that index: if FZED falls 256 bytes behind, the write index passes it and FZED carries on from the newest bytes.
4. `PARSE` (`fx/matrixz.asm:151`) loops over bytes. Realtime bytes go to `RTB2` (`fx/fx5xi.asm:2`). Notes, pressure, bend, CC1-5, CC9, CC111, CC120 and CC123 are handled inside the loop. It returns at the first other CC below 120.
5. The main loop (`fzed.asm:252-266`) then runs `MROUTE`, `DISPATCH` and `ECHOF` for that one CC and starts the next pass: key check, capture tick and LFOs, matrix, one live chunk, `PARSE` again.

Cost per message (emulator, data-sheet clocks; real time at 2.32 M/s):

| Message | Passes to act | Clocks | On the FZ |
| --- | --- | --- | --- |
| Note on / note off (FZED's matrix tracking; the ROM plays the note) | same pass | 1,260 / 1,100 | 0.5 ms |
| Pitch bend, poly pressure | same pass | about 1,000 | 0.4 ms |
| Channel pressure, program change | same pass | about 590 | 0.25 ms |
| Clock, start, stop, active sensing | same pass | 380-450 | 0.2 ms |
| SysEx, per byte (skipped) | same pass | about 200 | 0.1 ms |
| CC1-4 | same pass | about 1,050 | 0.45 ms |
| Voice CC (cutoff, resonance, tape speed, LFO rate, envelope) | one pass each | 6,600 (PARSE 1,030, MROUTE 120, DISPATCH 4,550, ECHOF 925) | 2.9 ms |
| FX CC (113-117) | one pass each | about 4,000 | 1.7 ms |
| LFO 2, CC10, CC11 | one pass each | 2,800-3,100 | 1.3 ms |
| Sample start / end (CC76 / 77) | one pass each | 8,400-11,000 | 3.6-4.7 ms |
| Loop start (CC87) | one pass | 92,500 | 40 ms |
| CC120 / CC123 panic | same pass | 61,000 plus 129 FZ note calls | over 26 ms |

The LCD echo is paced to one line per 60 ms. Each line is ROM call A2h, which handshakes with the display for every character (ROM B9BCh and DDE5h). Its real cost is unknown and is not in any figure here.

A whole pass:

| State | Clocks per pass | On the FZ | Passes a second |
| --- | --- | --- | --- |
| No live FX, nothing arriving (includes the idle wait `L6398`, 24,600 clocks) | 29,700 | 12.8 ms | 78 |
| No live FX, a CC in every pass | 10,900 | 4.7 ms | 213 |
| TapeHack live, no CC | 29,500-30,700 | about 13 ms | 74-78 (FZ reading: 74) |
| TapeHack live, a CC in every pass | 35,400 | 15.3 ms | 65 |
| Filter live, no CC / a CC in every pass | 59,400 / 65,300 | 26 / 28 ms | 39 / 35 |

## 5. Throughput, latency, overflow and clock jitter

Simulated with `harness/t2.py` at the measured factor: messages arrive in real time, the ring behaves as the ROM's does.

| Case (`next`) | Applied per second | Wait, median / worst | Ring |
| --- | --- | --- | --- |
| No live FX, 120 CCs a second | 120 | 7 / 14 ms | 6 bytes at most |
| No live FX, 300 CCs a second | 213 | 142 / 284 ms | wraps |
| TapeHack live, 40 CCs a second (one knob) | 40 | 7 / 14 ms | 3 bytes |
| TapeHack live, 120 CCs a second (three knobs) | 65 | 355 / 708 ms | wraps after about 1.5 s; 255 messages skipped in 6 s |
| Filter live, 120 CCs a second | 35 | 351 / 695 ms | wraps after about 1 s |

On the FZ under real CC load the factor is lower than 0.29 (section 2), so the real limits are lower than these: your heavy-load reading of 5,632-7,040 words a second means 44-55 passes, so 44-55 CCs, a second.

**Overflow.** The ring holds 85 three-byte CCs. It wraps when the backlog reaches 256 bytes, which takes 85 / (arrival rate - applied rate) seconds. FZED then skips exactly 256 bytes with no sign of it. The skip can start in the middle of a message:

- With a status byte on every message, at most one CC gets a wrong value (another CC's value, or a CC number used as a value), then the next status byte realigns it.
- With running status, number and value can stay swapped until the next status byte, so values land on CC numbers that were never sent. I did not reproduce this case in the simulation; it follows from `PARSE` keeping `RSTAT`, `RDCNT` and `RD1` across the gap (`fx/matrixz.asm:163-183`).
- Skipped note-offs leave FZED's own held-note state wrong (pattern restart, LFO 2 retrigger). The ROM still plays and stops the notes itself.

This may be what happened in the hardware session where readings were low until you reloaded: values landing on CC113-117 would change the effect's mix and curve. That is a guess.

**MIDI clock.** `PCNT` (`fx/fx5xi.asm:4`) only advances when `PARSE` reaches the clock byte, and the pattern, LFO 2 and capture sync read it once a pass. So:

- idle, no live FX: up to 12.8 ms late, almost all of it the idle wait;
- TapeHack live: up to about 13-15 ms; Filter: up to about 28 ms;
- with CCs queued ahead of it, a clock byte waits for the whole backlog, up to about 0.7 s, and is lost if the ring wraps.

At 120 BPM clocks are 20.8 ms apart, so a 13 ms pass already makes steps uneven and a 28 ms pass can take two clocks in one pass.

## 6. Improvements

### B1. Up to four CCs a pass (tier b; built, tested)

`diffs/b1_ccs_per_pass.diff`, `fzed.asm:252-266`. After `ECHOF` the loop goes back to `PARSE` instead of to the top, up to four CCs, then runs a normal pass.

- **Gain** (same simulation, three knobs at 120 CCs a second):

| | `next` | B1 |
| --- | --- | --- |
| TapeHack live: applied per second | 65 | 120 (all) |
| TapeHack live: wait, median / worst | 355 / 708 ms | 7 / 14 ms |
| TapeHack live: ring | wraps | 6 bytes at most |
| Filter live: applied per second | 35 | 110 |
| Filter live: wait, median / worst | 351 / 695 ms | 180 / 347 ms |

- **Cost while CCs arrive:** live passes drop from 65 to 53 a second with TapeHack, so live FX covers the sample about 18% slower during a sweep. With no CCs nothing changes.
- **Bytes:** 11 in the low area. It had 16 free, and the build needed 2 more, which come from removing a redundant `push ax` / `pop ax` around `DISPATCH` (it restores `ax` itself). Low area after: 0 free. One RAM byte at D2DBh, which I found unused.
- **What a user notices:** fast sweeps land on time and keep their intermediate steps. The matrix, LFOs and key check run once per four CCs instead of once per CC during a burst. The LCD echo shows the latest of the group.
- **Check** (`harness/eqmidi.py`, 60 random bursts with running status, realtime bytes inside messages, notes, bend, SysEx; with live off and on): the same 142 CCs applied in the same order with the same values, the same clock count, the same last LCD lines with live off. Time-dependent state (LFO phase, live cursor, LCD lines with live on) differs, as expected for tier (b). I did not go through every differing RAM byte.
- **Risk:** up to four CCs (about 12 ms on the FZ, 40 ms each for loop-start CCs) now run before the next key check and matrix pass. Filter still falls behind above about 110 CCs a second; a higher limit, or "until the ring is empty, at most eight", would cover it at more cost to live FX.

### Not built (ideas only, no code, untested)

- **Count clocks ahead of the backlog (tier b).** A second read index that runs over the whole ring once a pass and handles only realtime bytes, with `PARSE` then skipping them. Clock would never wait behind CCs. About 35 bytes in the high area, which has 2: the room would have to come from tightening `PARSE`'s CC1-4 chain or from moving code out.
- **Shorter idle wait (tier b).** `L6398` (`fzed.asm:2756`) waits 24,600 clocks, which is about 10.6 ms on the FZ, not the 3 ms its comment says. Halving the constant halves idle clock lateness. No bytes. It needs a check that nothing relies on the pace.
- **Tier (a), faster byte fetch.** `PARSE` costs 330-380 clocks a byte, much of it the `call L6331` and its CS-override index updates. Inlining the read could save perhaps a third of `PARSE`. It is small next to B1.
- **Ring protection (tier c).** FZED cannot see a wrap after it happens. It could detect a backlog over about 200 bytes and jump its index forward to the next status byte, losing CCs deliberately but never misreading them.
- **The ROM's own clock counter.** The ROM counts clock bytes at 0DF0h inside its interrupt when 0DEFh is 1 (ROM 0E80h-0EB5h); it is off (FFh) by default. Turning it on would give FZED a count that is never late, but the same flag makes the ROM's note call log events to a buffer at 0BE2h (ROM 287Ah). Unverified; I would not use it without a hardware test.
- **On the controller side:** no code change in FZED removes the limit of about 50-70 CCs a second with live FX on today. Limiting each knob to about 20 messages a second on the Gills would keep three knobs inside it.

## 7. Capture mode: map from the source (no measurements)

- **Resident:** `CAPGO` (`fx/capru.asm:5`) turns live FX off, deletes the edit voice, loads sectors 44-45 to D400h and starts the overlay. `CAPTICK` (`fx/capr2z.asm:2`) calls `CAPRUN` once a pass. `DISPATCH` sends every CC to `CAPFLT` first.
- **Overlay states** (`CST`, `fx/capo.asm:214-285`): 0 wait for sync and start; 1 recording; 2 playing the chord; 3 fade; 4 releasing notes one per stagger step.
- **What stops:** live FX and the curve build (shared D400h). During recording the ROM masks every interrupt except the timer (ROM 2566h writes FEh to the mask at E2h), so FZED polls the serial port itself (`UPOLL`, `fzed.asm:840`).
- **Two things that look worth measuring:**
  - While recording, an idle pass polls the port 2,048 times before the loop comes round (`fzed.asm:269-272`). That is roughly 200,000 clocks, about 90 ms on the measured factor, between checks for the end of the take. The shortest take is 10 ms. The take's length is set from the word count, so this adds dead time before playback, not length. Unmeasured.
  - Between polls, the rest of a pass (matrix, capture tick, about 5,000 clocks, about 2 ms) is longer than one MIDI byte (0.32 ms), so a second byte arriving in that time is lost. Clock bytes on their own survive; clock inside dense CC traffic may not, which would shift capture sync. Unmeasured.
- `CSTART` waits for the ROM's key queue to empty and, with sync on, for `PCNT` to cross a division. `PCNT` has the lateness described in section 5.

## 8. Not done

- No capture measurements, tiers or example code.
- No tier (a) example and no example for the clock or ring ideas.
- The speed gap is not explained; the test overlay in section 3 is not written.
- No MAME runs. LCD line cost not estimated.
- The running-status mis-parse after a wrap is argued from the code, not reproduced.
- B1 was not compared byte by byte beyond the checks listed.

## 9. Hardware measurements needed

| Question | How |
| --- | --- |
| Does B1 help as predicted | B1 test disk, TapeHack live, sweep three knobs hard: the sound should follow the knobs with no lag, and stop moving when you stop. On `next` it keeps moving after you stop |
| Does `next` really wrap the ring | On `next`, TapeHack live, sweep three knobs hard for 10 s with the Gills sending running status if it can, then check whether any FX setting or unrelated control changed |
| CPU speed and interrupt share | The tests in section 3 |
| LCD line cost | Passes per second with the CC echo on and with a control that draws no echo |
| Capture end-of-take delay | A 10 ms capture with hold x1: time from the end of the input sound to the first chord note |
