# FZED Menu Revision

## Capture Lengths To 10 Seconds (next)

- FZED: capture's 16 lengths are now 10, 16, 25, 40, 63, 100, 160, 250, 400, 630 ms, 1, 1.6, 2.5, 4, 6.3 and 10 s (was 10 ms to 4 s): each step about 1.585 times the last (the R5 series), so the pot feels even. The top step is 9990 ms, so the FZ's four-digit LCD shows it. Same CC103 bands; the capture overlay table only, no resident memory.
- Gills Core 127: CAPTURE LENGTH labels to match.

## Status Out While Recording (next)

- FZED: STATUS OUT now reaches the Gills while armed, waiting and recording. In those states the FZ's MIDI interrupts are off (FZED reads the MIDI port itself), so messages left in the ROM's queue were held back until afterwards; they now go straight to the MIDI port (8251, waiting for it to be ready, with a time limit). Idle, done and the other states still go through the ROM's MIDI call.
- Emulator: `status41.py` checks ARMED, WAIT and RECORDING go straight to the port and IDLE through the ROM again; `emu.py` learned LOOPZ / LOOPNZ.

## Gills Core 124: The Pots Reach The New Choices (next)

- Gills Core 124: Cores 121-123 labelled the new choices but left the pots' step counts as they were, so STRETCH NEXT / LEAD-IN could not reach JOIN, LFO2 MODE could not reach the SLOW modes and WINDOW SNAP could not reach FRAMES GLIDE. Now 6, 5 and 4 steps, each in the middle of FZED's band. Editor: LFO 2 Mode and Window Snap now offer the new choices too. No FZED change.

## Status Out To The Gills (next)

- FZED: STATUS OUT (FZED 24, off whenever FZED loads): the record state (idle, armed, waiting, recording, done, used, no memory), the record rate and the slice count go to MIDI OUT as CC3 on channel 16, each only when it changes. Channel 16 whatever the FZ's basic channel; the ROM's own copy of each message is taken back out of its internal queue, so the FZ never acts on it.
- FZED: CHOP's finishing steps (the bank's name, the slices' properties, playing the bank) moved into tools overlay 2 with its slice loop, for room; its message stays resident. Tools overlay 2 may now run up to its end signature (it keeps no scratch there).
- Gills Core 123: on the RECORD page the encoder press (after P1-P9; P10 keeps Exit) turns FZ STATUS OUT on / off, with a pop-up; while on, the Gills sends it again whenever RECORD opens, shows `ARMED 36K SL 08` on the page's line 1, and pops up FZ RECORD and the new state on any FZ page.
- Emulator: `status41.py`: off at start-up; on sends state, rate and slices once each as CC3 channel 16; nothing more without a change; each change one message; off sends nothing; on again sends all three again. Chop tests and the full suite unchanged.

## Stretch JOIN (next)

- FZED: Stretch NEXT has JOIN (and JOIN, CUT LEAD-IN): the loops sit back to back, each starting where the last one ends, a grain apart instead of a segment apart, closer to an old sampler's time stretch. The 8 loops cover the first N x Grain of the play range; with Stretch on and JOIN, moving Sample Start builds them again from the new start (from the disk; not for matrix or LFO moves of Sample Start). TRACE and SKIP are unchanged, and WAVETABLE still uses TRACE.
- FZED: NEXT is now six bands (value x 6 / 128): TRACE, JOIN, TRACE CUT LEAD-IN, SKIP, JOIN CUT LEAD-IN, SKIP CUT LEAD-IN. The Gills' and editor's band-centre values (16, 48, 80, 112) keep their old modes; a raw pot value of 22-42 (was TRACE) now gives JOIN, and 86-106 (was SKIP) JOIN, CUT LEAD-IN.
- FZED: Stretch's scratch moved above the overlay's end signature (still below the deepest FZ-call frame) to make room.
- Gills Core 122: NEXT / LEAD-IN shows the six choices. Editor: the six choices.
- Emulator: `join41.py`: the six bands, old values, joined loops a grain apart, Sample Start rebuilding them with JOIN and leaving them with TRACE. `leadin40m.py` now sends the band centres (48, 112). Full suite, live FX, wave, glide, disintegration and capture tests unchanged.

## Frames Glide, LFO 2 Slow, An 82-Word Wavetable (next)

- FZED: Window Snap has a fourth choice, FRAMES GLIDE (107-127; WHOLE FRAMES is now 86-106). On whole frames the loop window steps one frame at a time towards where it is sent, at most one frame each cycle of the frame at its original key, and carries on until it gets there. A sweep from the knob, LFO 2, the matrix or a pattern now plays every frame on the way instead of jumping several at once. EXT WAVETABLE sets it.
- FZED: LFO 2 Mode has FREE SLOW and RETRIGGER SLOW, a sixteenth of the speed (with the remainder carried, so even the slowest rate keeps moving). CC93 is now five bands: FREE 0-25, FREE SLOW 26-51, RETRIGGER 52-76, RETRIGGER SLOW 77-102, MIDI CLOCK 103-127; the values the Gills and the editor sent for the old three modes still give those modes.
- FZED: EXT WAVETABLE LENGTH has 82 words (A 440 Hz, original key A4) as the first of five choices (CC115 in bands of 26: 82, 164, 327, 655, 1309). The FZ plays a sampled voice only 3 octaves either side of its original key, so only 82 is in tune across the whole keyboard; the longer frames stop at A6, A5, A4 and A3.
- Gills Core 121: WINDOW SNAP shows FRAMES GLIDE, LFO2 MODE the five modes (rate shows clock divisions from 103), WAVETABLE LENGTH the five lengths. The editor shows the new Window Snap and LFO 2 Mode choices.
- Emulator: `glide41.py`: a 64-frame table glides 0 to 63 and back through every frame in turn, each step at least one frame cycle after the last; WHOLE FRAMES still jumps; the slow modes run at exactly a sixteenth; the old mode values keep their modes. `ext41.py` checks the 82-word table word for word. Full suite, live FX, wave, disintegration, capture and start-up tests unchanged.

## Room For What Comes Next (next)

- FZED: CHOP's slice loop (cutting each slice into its own voice) moved out of resident memory into tools overlay 3 (disk sector 47), which CHOP already loads for its bank choice. About 320 bytes of resident low memory are free again for the next features (FZED to Gills recording messages, capture refire, LFO2 slow mode). CHOP works and reads as before; no other change.
- Emulator: the chop tests and the full regression suite give the same results as the previous build; start-up unchanged.

## EXT BACKUP And EXT WAVETABLE (next)

- FZED: EXT BACKUP (module 3, FZED 19 = 24-31, disk sector 54): copies the edit voice into the first empty voice with its own copy of the sample, as a one-step undo before a render. The edit voice stays the edit voice. Shows BACKUP IN Vnn, BACKUP: NO SLOT or BACKUP: NO MEMORY.
- FZED: EXT WAVETABLE (module 4, FZED 19 = 32-39, disk sector 55): builds 8-64 single-cycle frames of 164-1309 words (A 220 to 27.5 Hz at 36 kHz, original key set to match) along a SYNC, PWM, FOLD or MORPH sweep, then sets loop 1 to the first frame, Window Snap to WHOLE FRAMES and Stretch to match (2, 4 or 8 segments, each loop one frame, Snap and Crossfade off).
- The program on disk is 39 KB (sectors 17-55). No change to FZED's code in memory.
- Gills Core 120: FX EXT view names modules 3 and 4, and with WAVETABLE shows TYPE, FRAMES, LENGTH and SWEEP with their choices.
- Emulator (`ext41.py`): BACKUP makes its own copy of every word, moves the start, end and loop addresses to it, leaves the edit voice and its sample untouched, and a render afterwards leaves the backup as it was; NO SLOT when every voice is taken. WAVETABLE matches a model word for word for each type (SYNC 64 x 327, PWM 32 x 164, FOLD 16 x 655, MORPH 8 x 1309); the voice, Window Snap and Stretch settings are as described; Window Position moves the loop by whole frames; Stretch On then gives 8 loops of exactly one frame, each at a segment's start; TOO BIG when the voice's memory is too small. Start-up and disintegration tests unchanged.

## A Different Dropout Pattern Each Run (next)

- FZED: the dropout pattern is seeded from the timer while the sample is new, and the seed is fixed as soon as it starts ageing. Each run (DECAY up from 0, each new capture take) loses a different set of stretches in a different order; within a run they stay the same, so nothing tears over it. Before, every sample lost the same stretches every time.
- FZED: for room, the render readout is the time alone (`012.3S`), and `RENDERING...` / `LIVE: COPYING..` lost their dots.
- Emulator: `dis41.py` checks that the seed changes while the sample is new, stays put while it ages, and differs the next time; the stage still matches its model word for word (`dis41.py`, `capdis41.py`); `ext41.py` passes; start-up unchanged.

## EVEN AGEING Range (next)

- FZED: EVEN AGEING (FZED 23) is a range: the age may take 2^(value / 16) steps each time the live engine has been round the sample (1-15 one, 16-31 two, ... 112-127 128); 0 is off. In the first version any value above 0 allowed one step a round, which was seamless but slow (several minutes for strong ageing on a 12 s sample).
- FZED: the refused-module message is now `BAD MODULE` (was `EXT: BAD MODULE`), for room.
- Gills Core 119: P9 sends the pot's value and shows OFF or 1/ROUND ... 128/ROUND.
- Emulator: `dis41.py` checks EVEN AGEING 8, 40 and 127 (each step after at least the sample's length divided by 1, 4 and 128 words through the stage) and that more EVEN AGEING ages faster, the timer alone fastest.

## Cheaper Live Hiss (next)

- FZED: hiss costs about 60% fewer clocks, so it is less likely to push the live engine behind the playhead (the tearing heard with HISS up). The noise is now a multiply-free xorshift, its level set by a shift, and it is added to every other word only (white noise with every other value 0 is still white). HISS now moves in 6 dB steps, every 16 on the knob, from about -57 dB to about -15 dB; 0 is none. Measured on the timing model, per 128 words: hiss about 7,000 clocks, against about 18,000 before.
- FZED: FZED 19 = 0 now shows `EXT 00` on the FZ LCD instead of `EXT OFF` (for room). The Gills still shows OFF.
- Emulator: `dis41.py` and `capdis41.py` pass with the new hiss model; start-up unchanged.

## Render Keeps Live FX, Fading Dropouts, EVEN AGEING (next)

- FZED: Render (CC118) with live FX on keeps what they give. The age stops, one sweep runs over every word through the FX Type and disintegration at that age, and live FX are released without the clean copy going back (RENDERED (LIVE)). Before this, Render with live FX on went back to the original and rendered the FX Type alone, so disintegration was lost. With live FX off, Render works as before.
- FZED: dropouts fade as the sample ages instead of switching off at once: a stretch's level is 256 - (threshold - its hash) / 16, so it fades over about 16 steps of age at DROPOUTS 127. In an emulator run at DECAY 127, DROPOUTS 127, the largest jump the playhead met between neighbouring words fell from 10436 to 2985.
- FZED: EVEN AGEING (FZED 23, above 0 = on): with live FX the age moves on only after the stage has had as many words as the clean copy holds since the last step. In the same emulator run it left no jumps beyond twice the test tone's own largest step (the age moved more slowly: 58 of 255 against 255). Capture always ages by time.
- FZED: the render readout after Render shows the time only (`TIME 000.0S`); the words-per-second figure went, to make room.
- Space afterwards: low 0 bytes, high 4, xt 1, lv 5, capture overlay 4.
- Gills Core 118: FX EXT view P9 = EVEN AGEING (OFF / ON, sends FZED 23 = 0 or 127).
- Emulator: `dis41.py` checks the fading dropouts word for word against the model, that each ageing step with EVEN AGEING on came after at least the clean copy's length of words, that off it is the timer alone again, and that Render with live FX on passes every 128-word piece through the stage at one age and the voice keeps exactly what came out. `capdis41.py` and `ext41.py` pass.

## Disintegration And EQ Fixes After The First Hardware Test (next)

- FZED: disintegration aged 256 times too slowly (DECAY 127 took about 43 minutes, not 10 seconds), which is why it sounded subtle. Fixed: DECAY 127 about 10 s, 64 about 40 s, 32 under 3 minutes, 8 about 45 minutes.
- FZED: dulling now falls steadily with age (about 5 kHz a quarter of the way, 1.8 kHz half way, 135 Hz at the end, for a 36 kHz voice) instead of staying faint until the last quarter. Hiss goes up to about -12 dB (was -24 dB).
- FZED: the stage runs as separate passes (dulling, dropouts, hiss), each only when it does something.
- FZED: EXT EQ renders about 1.5 times faster (32-bit shifts by count instead of bit by bit). Every render works through the sample piece by piece; EQ was slow enough that you could hear it moving through.
- Gills Core 117: on the FX EXT view, P2-P5 (CC113-116) are smooth 0-127 pots. In Core 116, P2 and P4 kept the FX view's steps, so EQ BASS bottomed out at 004.
- Emulator: `dis41.py`, `capdis41.py` and `ext41.py` pass with the new model (the age grows by DECAY^2 x 1024 each 4096 timer units).

## Disintegration, EXT EQ And Room For Them (next)

- FZED: disintegration, a live stage after the FX Type effect (FZED 20 HISS, FZED 21 DECAY, FZED 22 DROPOUTS). With live FX on, the sample ages with time: it gets duller (a one-pole low-pass down to about 380 Hz) and, with DROPOUTS, 57 ms stretches drop out, each faded over 3.5 ms; the same stretches go first and more join. DECAY sets the speed (127: about 10 s from new to fully aged; 8: about 45 minutes); DECAY 0 makes it new again. HISS adds noise on top. It works from live FX's clean copy, so turning live FX off brings the sample back. No LCD readout for the three values (no room). Source: `work/fzed/fx/dis1.asm`-`dis3.asm`.
- FZED: in capture, disintegration works on a held take in place, 64 words a main-loop pass, so each pass builds on the last; hiss is left out there (it would pile up); each new take starts new; a last part shorter than 64 words is left as it is.
- FZED: EXT EQ (module 2, sector 53): three-band EQ for Render with FZED 19 = 16-23. CC113 bass (about 300 Hz), CC114 mid, CC115 treble (about 3 kHz), CC116 output; 64 = unchanged, 0 removes the band, 127 about +12 dB.
- Room: capture's variables moved from the top of the capture overlay's window into LVBUF (free while capture runs), so CAPRE no longer copies them out and back (space audit item 3.2). NEW VOICE's voice search moved into tools overlay 3 (sector 47, beside COPY VOICE; audit item 3.3), so NEW VOICE now needs the FZED disk in the drive, as preset waves do; it also releases live FX before searching.
- Space afterwards: low area 6 bytes free, high 32, lv 5, xt 20, capture overlay 4, tools overlay 3 about 400. The program on disk is 37 KB (sectors 17-53).
- Emulator checks: every call of the disintegration stage matches a model of it word for word, in sweep and chase, at several ages, dropouts and hiss levels (`work/fzed/tests/dis41.py`); the age grows by exactly 4 x DECAY^2 per 4096 timer units; with every control 0 the stage changes nothing; live off restores the clean sample word for word. In capture (`capdis41.py`): every stage call over the take matches the model with no hiss and HISS kept as set, each chunk lands in the take, the place walks the take and goes round, nothing outside the take changes, a new take starts new, and with every CC sent while capturing no other code writes capture's variables. EXT EQ matches a model word for word at four settings (`ext41.py`). Start-up, every other emulator test (capture tests updated for the variables' new address), the preset waves and live FX output (430 cases) are unchanged; the one start-up byte that differs is a pointer to a message that moved.
- The Gills has the controls from Core 116 (FX page, FX EXT view: P2-P5 the module's controls, P6-P8 HISS, DECAY, DROPOUTS). Not yet in the editor.

## EXT Disk Modules And EXT NOISE (next)

- FZED: new FZED 19 (CC10 = 88, CC11 = 19, then CC10 = 89, CC11 = value) chooses an EXT disk module: 0-7 off, then blocks of 8 for modules 1-15 (module n is disk sector 51 + n). With a module chosen, Render (CC118) loads it, shows its name and runs it instead of the FX Type effect, on the edit voice and every chop slice. Live FX are unchanged. Choosing a module reads nothing from the disk.
- Modules are effects (rendered in chunks of up to 256 words) or tools (run once). Each records which FZED build it belongs to, and FZED refuses one from any other build (EXT: BAD MODULE). A missing module shows TOOLS NOT LOADED. Either way the sample is left alone. Format: `work/fzed/fx/ext.asm`.
- EXT NOISE (module 1, sector 52): adds noise; CC115 level, CC116 tone (127 white, lower darker); same noise on every render; peaks held at full scale.
- Space: the EXT code uses 177 resident bytes (low area 192 free, high 227, lv 18, xt 56). The program on disk is 36 KB (sectors 17-52).
- Emulator checks (`work/fzed/tests/ext41.py`): EXT NOISE gives exactly the words of a model of its code, including clipped peaks; level 0 leaves the sample unchanged; FZED 19 back to off renders the FX Type effect exactly as before; an empty module slot and a module from another build are refused with the sample untouched; a tool module runs once on the edit voice and renders nothing. Start-up, every other emulator test, the preset waves and live FX output (430 cases) are unchanged.
- Tested on the FZ-1 with Gills Core 114: EXT NOISE renders and changes with level and tone, FZED 19 off renders the FX Type effect again, and an empty module slot shows TOOLS NOT LOADED.
- The Gills has the control from Core 114 (FX page, turn the encoder for the FX EXT view). Not yet in the editor.

# v1.2 (19 November 2026)

Tested on a real FZ-1. Frees memory for the planned work (chop, capture re-strike, modules); behaviour unchanged.

## Room For New Work: Start-Up Overlay And Small Savings (v1.2)

- FZED: the code that runs only once, at start-up, now lives on the FZED disk in sector 51 instead of staying in memory. FZED loads it with the rest of the program, runs it once before the main loop, and the memory it used is free again for the live FX and the overlays. Moved unchanged: the start of `MAIN` and `MINIT`, `MXINIT`, `PINIT`, `SVINIT`, `FXINIT`, `FX5INIT`, `PBGET`, `CAPINIT` and the two start-up messages. If sector 51 is missing or wrong, start-up stops with LOAD ERR, as for the other program sectors.
- FZED: small savings with the same behaviour: 23 `add`/`sub` by 1 or 2 became `inc`/`dec` where nothing reads the carry afterwards (each place checked, including the routines' callers); one unused message removed (`S_VI`); trailing spaces removed from five messages that `NMSG` shows (it blanks the line first); three `call`/`ret` pairs became `jmp`, one `jmp` to a `ret` became `ret`, one `cmp dx,0` became `or dx,dx`.
- Space: low area 349 bytes free (was 0), high area 247 (was 2), lv 18 (was 13), xt 56 (was 0). The start-up overlay uses 627 of its sector's bytes. The program on disk is 35 KB (sectors 17-51); `mkimg.py` places sector 51, checks its signatures and marks it used. Audit and plan: `work/reviews/space_audit/SPACE_AUDIT.md`.
- Emulator checks: start-up on the old and new builds leaves FZED's variables and the FZ's RAM identical byte for byte, with the same ROM calls in the same order and the same LCD lines, for a voice in the edit buffer and for an empty one, and the first CCs afterwards act the same (`work/fzed/tests/startup41.py`). The FZ-call stack stayed above the start-up code. Every other emulator test gives the same output as the build before, the preset waves come out word for word as before (14 cases), and live FX sweep, chase and render output is identical in all 430 cases, for the small savings and again for the start-up overlay. Test changes: the emulator now also runs code in a loaded overlay sector when not in capture (start-up needs it), and `wave40.py --stack` compares the refusal message without its trailing spaces. Tested on the FZ-1: start-up with and without a voice loaded, FX, LFO, matrix, pattern, glide and NEW VOICE, a chop and a preset wave load, and leaving with ENTER and with ESC.

# v1.1 (16 November 2026)

Everything from here down to v1.0, tested on a real FZ-1. Live FX words-per-second readings from the measurement build are still to be taken; they are for the record, not a pass/fail test.

## MIDI Keeps Up With Fast Knob Sweeps (v1.1)

- FZED: a main-loop pass can now apply up to four CCs instead of one, from the MIDI review (`work/reviews/midi_capture/`, diff B1). With a live effect on, CCs no longer queue up behind the live FX: in the emulator, scaled to the FZ's measured speed, three knobs at 120 CCs a second all land with TapeHack on (worst wait 14 ms, was 705 ms) and 109 a second with Filter on (was 35).
- FZED: MIDI clock no longer waits behind queued CCs (diff B2). A clock byte behind 60 CCs is counted in the next pass instead of 61 passes later, so a clocked pattern stays even while you sweep.
- FZED: if FZED ever falls 200 or more bytes behind the FZ's 256-byte MIDI receive buffer, it now skips to the newest byte instead of letting the buffer wrap (diff C1). Nothing is misread; a burst too fast to follow drops about 65 CCs at once and the control jumps to its current value.
- With chop slices, a CC that copies its settings to every slice ends that pass's batch, so ESC, ENTER, the key check, the LFOs and the matrix keep today's timing (32 slices: at most about 145 ms between key checks; with four CCs it would have been about 575 ms). With slices the CC rate is limited by the copy to every slice either way.
- Checks (emulator): the same CCs, in the same order with the same values, and the same MIDI clock count as before on random streams (running status, realtime bytes inside messages, bursts, SysEx); start-up values unchanged and ESC still exits; the source voice and all 32 slices end with the same settings as before; live FX sweep, chase and render output identical in all 430 cases. Tested on the FZ-1: about 20 minutes of a MIDI sequence with polyphony and three CCs, across several live effects, with no glitches.
- Space: the low area is full (0 bytes free); the room came from tightening start-up writes, the key check and three paths in the MIDI parser (all checked above).

## XOver Fuzz No Longer Silences Quiet Material (v1.1)

- FZED: at the fuzz end of XOver Fuzz, the threshold is now the clip point instead of a gate. Below the threshold the signal rises in proportion to full fuzz level; above it, it is clipped at full fuzz level, as before. Before, everything quieter than the threshold came out as silence, so at middle and high thresholds most of a sample vanished (on an SU10 test sample at threshold 29%, 89% of the words were below it). The crossover end is unchanged (its dead zone is the effect), and CC116 still blends between the two. Live speed is unchanged: the curve is still one table.
- Emulator check: the curve FZED builds equals the new formula in every entry at eight threshold / blend settings, including threshold 0.
- Space: 26 bytes of the high area (2 left).
- Manual: the effects table explains the threshold at each end of XOver Fuzz, and says Tube2's Amount has most effect at lower Pad settings (higher Pad drives more of the signal into Tube2's output clamp). That is how Tube2 works, not a change.

## Linear Crush DeFreq Live; Tube2 Render Overflow Fixed (v1.1)

- FZED: Linear Crush's frequency reduction (DeFreq, CC114) now works live as well as on render. Live uses the decimator's block placement with the hold length render uses (from DeFreq and the voice's rate), and crushes each held word, so the live result is the render's word for word: emulator check at holds of 3, 12, 13 and 26 words, fully wet and mixed, at three voice rates. Cost per pass is about the same as before (fully wet 19,365 V50 clocks against 19,603 without the hold; mixed 31,367 against 29,411).
- FZED: Tube2's render no longer clicks at high Pad settings. A fast fall at high level overflowed the slew stage's 16 bits and flipped the word's sign (a full-scale click); it now saturates. On an SU10 test sample at Pad 100% / Amount 73% this changed 42 words; at Pad 74% / Amount 35% and 50% / 50% nothing changed. Live Tube2 is unchanged.
- How (space): the Tube2 slew stage is one routine (`TUPOST`, lv) shared by render and the live curve build; the DeFreq hold length is one routine (`FXFQ`) shared by render and live; the per-chunk setup Tube2 live no longer needed (`TUPREP`) is gone. Free: high area 28 bytes, lv 13.
- Emulator check: render gives the same words as before in all 150 cases except the one overflowing word in the Pad 110 / Amount 20 Tube2 case (fully wet and mixed); sweep and chase are unchanged in every case; live, render, live again on Tube2 at Pad 100/73 and 110/20 matches the fixed model word for word.
- The measurement build (`LVMEASURE=1`) no longer fits: the lv area has 13 bytes free.
- Manual: Linear Crush's frequency reduction is no longer listed as render-only.

## Tube2 Live Without The Slew Stage (v1.1)

- FZED: live Tube2 now leaves out the slew stage, the part that reacts to how fast the wave is moving. Render is unchanged and still runs it, the same way Linear Crush's frequency reduction is render-only. Live keeps the static curve together with the slew stage's effect at zero slew, its clamp and its gain, built into the curve table, so each live word is one table lookup (and the Wet/Dry mix). In the emulator a fully wet live pass drops from 108,810 to 29,841 clocks (3.6 times faster) and a mixed pass from 114,783 to 39,687. Measured on the FZ, Tube2 ran at about 2,700-2,800 words per second fully wet; it should now come out near TapeHack (about 9,500).
- The sound live: on an SU10 test sample the difference from the full render is 44-51 dB below the signal, a little less bite on bright, fast-moving material.
- How: the live curve has its own key (Tube2 + 32) while live runs, so a render (which turns live off first) builds the full curve and live builds its own on the next pass. The Tube2 entries in the fast-loop tables point to new loops that run FXLU when live is off. Space: 237 bytes of the lv area (116 left); the high area is unchanged.
- Emulator check: render gives the same words as before in all 150 cases; sweep and chase are unchanged in every mode except Tube2, whose live output matches a word-exact model of the new loop fully wet and at five Wet/Dry settings; live, then render, then live again gives the full render and the live curve each time.
- Manual: the effects table says the slew stage is render-only.

## Triangle Wave Starts At Zero (v1.1)

- FZED: the Triangle preset wave now starts a quarter cycle in, at zero going up, instead of at its lowest point. Starting at full level made a slight click at note-on. The wave's shape, level and loop are unchanged; only where the cycle starts moved. Checked on the FZ-1: no click.

## Live FX Chase Gets More Time (v1.1)

- FZED: live FX now give the work near the playing note more of the CPU. The chase (the 512 words just ahead of the playhead) runs every pass until it is 512 words ahead, then one pass goes to the sweep (the rest of the sample); at least one pass in eight always sweeps. Before, three passes in four chased and one swept, whatever the chase's lead. In the emulator a fast playhead gets 11-14% more chase chunks.
- The processed sound is the same in every mode except Karplus-Strong, whose live result depends on the order chunks are processed in by design.
- For testing: `LVMEASURE=1 sh build.sh` makes a measurement build that shows live words per second on line 3 (`LV nnnnnn W/S`), timed by the FZ's timer at the measured 3,240 interrupts per second.

## Faster Live FX (v1.1)

- FZED: live FX passes are shorter, from the live FX review's sets 1 and 2 (`work/reviews/live_fx/`): a faster read of each chunk into the live buffer, tighter inner loops, a one-multiply Wet/Dry mix, and fully wet loops for rectifier, decimator and echo / comb (in the space the wave overlay freed). The sound is unchanged: every mode and setting in the emulator comparison (sweep, chase and render) gives the same words as before.
- The faster read briefly changes a CPU segment register while interrupts can arrive (see the review's section on DS). Soak-tested on the FZ-1 with the MIDI test above: no glitches.

## Preset Waves From The FZED Disk (v1.1)

- FZED: the preset wave generator moved from resident memory into a disk overlay (sector 50), freeing about 495 bytes in the crowded lv code area for later work. The seven waves come out word for word as before, with the same messages and refusals (emulator check `work/fzed/tests/wave40.py`).
- Loading a wave now reads FZED's disk when the overlay isn't already in memory (after a render, capture, tool or buffer-using live effect): keep the FZED disk in the drive, or the FZ shows TOOLS NOT LOADED.
- Capture and bank mode are still refused with WAVE: REFUSED before the overlay loads. If the FZ's own calls ever push the stack into the overlay's end, the load is refused rather than run on damaged code.

## Loop Mode ORIGINAL Restores Loop Points (v1.1)

- FZED: Loop Mode ORIGINAL now also puts the voice's loop points back as they were when FZED took the voice (it already restored the loop times and the sustain / end loop). A preset wave's perfect loop comes back after Loop Start / End have moved it. Moving Loop Start / End afterwards works from the knob position as before. STRETCH OFF keeps the loop points you set before Stretch (with the voice's own loop times and sustain / end loop, as before); choose ORIGINAL after it for the voice's own points. Space: the three copies of the voice's loop table share one routine, which freed the bytes.
- Manual: leaving with ENTER (Keep Sound) while Stretch is on keeps the stretch loops but puts the start and end back (a Cut Lead-In start is not kept); Keep All Of Edit Voice or Keep All saves it as heard. The manual had said ENTER kept the moved start.

# v1.0

## Stretch Sustain At Names

- The Sustain At knob now names its positions the way FZED reads them: NO SUSTAIN, then HOLD SEGMENT 1 up to the last segment, and the choices follow Segments (9 positions at 8 segments). Before, the names came from a fixed three-way list, so at 8 segments the second and third positions said NO SUSTAIN while FZED held segments 1 and 2. The values sent were already right; only the names changed. Manual and Appendix A updated.

## README For Users

- FZED.zip's README is now for users: what's in the zip, how to put the FZED disk on the FZ (the .hfe on an HxC's SD card, or the .img written to a 3.5" HD floppy) and how to connect the editor. The developer notes moved to DEVELOPER.md, which stays in the repository.

## Manual: What Changes Live

- Section 1 now says which kinds of control change sounding notes and which apply from the next note.
- New Appendix B lists every control by page as live, next note or command, from FZED's code and hardware tests (LFO 1 confirmed live on the FZ).

## Output Lock

- Opening a preset (Open), a settings file or a USER_FZ.BIN bank no longer locks output: none of them sends anything, and the next control you move goes to the FZ as usual. Use a preset's Send to put the whole preset on the FZ.
- Output still locks when the MIDI set-up changes (IN, OUT or channel changed, a device added or removed) or a send fails.
- Moving a control while output is locked now flashes the Output locked button and says "Output is locked · press Output locked to send" (or asks you to connect MIDI and choose OUT).

## Loop And Play Mode On The FZ Screen

- FZED now names the loop mode (CC86: ONE-SHOT, ORIGINAL, LOOP) and the play mode (CC70: ORIGINAL, REVERSE, CUE) on line 3, instead of only echoing the value; the editor's FZ SCREEN shows the same.
- To make room, FZED blanks line 3 with a full-width blank before every message, so its messages no longer carry trailing spaces. (The first build of this blanked from the message's end by passing a column to the ROM text routine; that argument is really the inverse-video attribute, so the FZ drew black squares. Fixed.) Messages that were shorter than the line (CAPTURE OFF, FADE, NOT ARMED and others) no longer leave old characters behind.
- Checked in the emulator against the released FZED: of 2,082 screen outputs, all are unchanged or only lose leftover characters, apart from the new names; every Loop / Play and Chop control changes the same voice settings as before. Needs a hardware test.

## File Names

- Disk images drop the size suffix: `FZ1_FZED.img` and `A FZ1_FZED.hfe` (were `_33S`, the program's 33 disk sectors). Later versions keep plain names.

## FZED Checkpoint

- The optional software is now called **FZED** on the FZ (title line and disk name) and on the editor's FZ SCREEN. The code is FZED40N's: only the name bytes differ (the title is padded, so no address moves); the emulator boots it showing FZED.
- Disk images: `FZ1_FZED_33S.img` and `A FZ1_FZED_33S.hfe` (the HFE converts back to the same image). Source and build: `work/fzed/` (`fzed.asm`, `fx/`, `build.sh`, `mkimg.py`), the starting point for later versions; emulator checks in `work/fzed/tests/`.
- The FZED40N and PERF40N images are no longer in the repository's outputs (they stay in its history and on the Mac).

## Inputs For FZED Users

- INPUT VALUES: **Plain 0-127** is the default. **FZED** is renamed **FZED messages (as sent)**: for anything that already sends what FZED receives (Appendix A), such as a sequencer replaying the editor's output. **Remote SL** is offered only when the editor is opened as `FZED.html?remotesl` (and stays offered once chosen).
- IN: new **All inputs** choice, so several controllers can be used at once; learned controls keep their own input and channel. The input named like OUT is left out to avoid feedback.
- FZED.zip leaves out the ReMOTE SL templates and notes (they stay in the repository). New check `test_fakedom/inputs.cjs`.

## ReMOTE SL: Chop Count Stuck At 4

- The SL templates sent each control to USB 1 and MIDI OUT 1. Wherever that raw NRPN reached the FZ, its CC99 (NRPN MSB 0-7) set FZED's chop count to 4 and its CC98 (NRPN LSB) acted as CHOP MAKE PLAY, right before FZED's own translated MAKE SLICES: CHOP 04/04 OK whatever the count (reproduced in the emulator). The controls now go to USB 1 only. Reload FZED_SL_1_SOUND.syx, FZED_SL_2_MOD.syx and FZED_SL_3_SAMPLE.syx.

## Three-Way Check: Manual, Editor, FZED40N

- Manual: new Appendix A, every MIDI message by menu page in the editor's order (CCn, Pn = CC10/CC11, FZED k = CC10 88/89), with the value ranges FZED receives. Built from the editor by `make_cc_appendix.py`.
- Every editor control was sent to FZED40N in the emulator (`work/perf39c/tests/RXCHECK.md`): all reach the setting they name, and every step of a stepped control is a different setting.
- Fixed: AMP+FLT RELEASE (Capture) sent CC81 = 0 with CC85 = value, so it zeroed the amp release; it now sends the value on both.
- Fixed: the FX Filter's TYPE control (CC94: low, band or high-pass) was missing from the FX page. Its CUTOFF and RESONANCE now show 000-127 instead of the tape dB scale.
- FZ SCREEN now draws what FZED40N draws, checked against the emulator's LCD: the C=ccc vvv / P=ppp vvv echo is on line 4 (line 3 keeps FZED's last message); FX values, capture and chord settings show FZED's own text (MIX 050%, INPUT x02.9, RING 0021.3HZ, C0010 x4 +00 F, 5+8  SAM 0000MS, FADE 0050MS) with no echo, as FZED does. CC98 shows > PLAY SLICES / > PLAY VOICE on line 3 (the editor's note) with FZED's echo on line 4.
- Manual: preset waves are Off and seven waves on CC111 0-63 (the list of 16 was wrong); Load sends CC9 = 0 then 127; Chop / Pattern lists its DCF Cutoff; FZ SCREEN description updated; a leftover controller page reference removed.

## Manual For FZED Users

- The manual covers FZED (the optional software and this editor) only: no Gills or ReMOTE SL sections or references, and the optional software is called FZED throughout (EXIT FZED, not EXIT PERF). 25 sections.
- Editor wording: the bank messages no longer mention the Gills SD card.

## FZED40N

- The optional software now shows FZED40N (title line and the name on disk) instead of PERF40N; the code is otherwise PERF40N unchanged. FZ SCREEN shows FZED40N on line 1.

## Expected FZ Screen

- FZ SCREEN: CHOP MAKE PLAY shows PERF's text (CHOPPING... or the C=098 echo) and, on line 5, which it is: > CREATE SLICES, > PLAY SLICES or > PLAY VOICE.
- ReMOTE SL SAMPLE template: ST SUS steps through 9 settings (none and hold segments 1-8; the extra presses repeat when there are fewer segments). SLICE moves to a pot (spans 4-32 slices); CAP REL becomes an 8-step button. Reload FZED_SL_3_SAMPLE.syx.

- FZ SCREEN follows every change made in the editor (mouse, keys), with or without MIDI input and with output locked.
- New check `test_fakedom/fzscreen.cjs`.

- FZ SCREEN shows BANK ADD / CLEAR as PERF does: VOICE ADDED, CHnn CLEARED.

- CREATE SLICES now sends the re-arm (CC98 = 0) and then CC98 = 127 150 ms later, from the editor, the SL and learned controls, so PERF has finished going back to the voice before it chops.

- New **FZ SCREEN** beside each page title: a 16 x 8 copy of the FZ's screen showing what PERF40N should display for each message FZED sends or receives from the controller (PERF's message line, the C= / P= echo, the record lines and state such as ARMED). Worked out from the messages, not read back; it follows the controller even when FZED is not forwarding (FOLLOW = Display only).
- MIDI monitor shows outgoing (OUT) messages as well as incoming.

## ReMOTE SL Fix

- New **MIDI monitor** (left panel): open it to see every message from the input port (IN) and every message FZED sends to the FZ (OUT), with Copy.
- Channel 16 CC100 / CC101 (RPN select or null) are no longer passed to the FZ as DELETE UNUSED / NORMALISE; the SL's FX DEL and FX NORM buttons now send NRPN 7/100 and 7/101.

- Fixed: buttons and knobs that send NRPN (chop mode, slice count, pattern, slice, stretch, grain, matrix, controllers, FX P2-P5 and more) did nothing. The SL sends the templates on channel 1, not 16, so FZED passed CC99 / CC98 / CC6 straight to the FZ. With INPUT VALUES = Remote SL, FZED now reads every CC from the SL's port, on any channel (CC99, CC98, then the value on CC6, as captured from the SL).

## Novation ReMOTE SL

- Three linked ReMOTE SL (MkI) templates, FZED 1 SOUND, 2 MOD and 3 SAMPLE (`FZED_SL_*.syx`), with PERF names on the SL's screens. Direct PERF CCs go out as themselves; parameters and PERF controls go as NRPN and FZED turns them into CC10 / CC11 and 88 / 89. Stepped settings are STEP buttons; selections (controller source, matrix route, current effect's parameters) are picked on the SL.
- New INPUT VALUES choice **Remote SL**: reads the templates' messages and forwards them on the FZ channel.
- Manual: new section 22, Novation ReMOTE SL (27 sections). `FZED_REMOTE_SL.md` has setup and the full layout.
- New check `test_fakedom/remotesl.cjs` (15 checks).

## Gills Core 110 Layout

- Profile regenerated from Gills Core 110, which lays the FZ pages out by function on its two rows of five. The editor's rows now match the pots: top row P1-P5, bottom row P6-P10.
- Moved pots: Filter / Keys, Envelope stages, LFO 1, LFO 2 (rate, shape, delay, fade-in, mode, as LFO 1), Key / Velocity, Controllers, Play / Loop, Record. ADSR, Matrix, Stretch, Chop / Pattern, FX, Slices, Capture and Bank builder unchanged.
- MIDI Learn assignments saved by earlier versions follow their control to its new position.
- Manual: Capture 2 Release is P5 (was listed as P8).

## Knobs, Switches and Preset Building

- New FZ panel look: matte black panel, backlit aquamarine LCD readouts with navy dot text and title bars (5x7 dot font, built in, works offline), FZED title with a block white FZ and outlined ED, light-blue cursor-key primary buttons, red LEDs for the active page, toggles and switches, fader-style sliders, black knurled pots.
- Pages are laid out by function, not by the Gills' pots per page: each page has labelled groups in balanced rows (for example Filter / Speed above Keys: original, lowest, highest).
- Stepped controls are now pots (drag, wheel, arrow keys, Page Up/Down, Home/End); two-choice settings are switches.
- User presets: Save as preset (name, slot, this page / pattern only / whole voice), Rename, Delete, Download USER_FZ.BIN, New empty bank, Bundled bank. The bank is kept in the browser until downloaded.
- Each editing page has a Presets bar with its page presets (Open, Send, Save as preset).
- 21 new bundled presets: ST TIMESTRCH, ST REVERSE, ST SHUFFLE, ST STUTTER, ST SLOWDOWN, ST FREEZE, ST PINGPONG; PT 8THS GATE, PT TRANCE, PT GALLOPFLT, PT RAMPPITCH, PT BROKEN; FX TAPE SOFT, FX TAPEDRIVE, FX FOLD, FX TUBE, FX RING LOW, FX KS PLUCK; LF VIBRATO, LF TREMOLO, LF WOBBLE.
- Stretch settings are saved in the slot's spare bytes; Gills Core 109 replays them.
- New check `test_fakedom/presets40.cjs` (21 checks); pages40 now 23 checks.

## PERF40N / Core108 Editor Update

- Profile regenerated from Gills Core 108 for PERF40N: 400 controls, each with its held steps where it has distinct steps.
- New pages: **Stretch**, **Slices** and **Bank builder** (with the build sequence). Filter / Keys no longer carries the bank controls.
- New PERF commands: VOICE SELECT, NEW VOICE, COPY VOICE, EXIT PERF (discard / keep sound / keep all of edit voice / keep all), CHOP INTO own / target bank, FREEZE CHOP.
- Capture On now sends PERF control 7 (parameter 88 = 7, 89 = 127), as PERF40K requires; Capture Off is CC108 0.
- Follow decodes PERF's multiplexed controls (parameter 88 chooses, 89 sets): stretch, voice pick, per slice, capture on.
- Stepped controls (keys, lists, stretch times, order, skew, slice keys) are lists of exactly the Gills steps; SUSTAIN AT follows the segment count and SLICE the slice count.
- Gills-only controls are left out: GO TO page, MIDI OUT, bank latch, FZ MIDI channel confirm.
- Manual: new sections Stretch, Slices and Bank Builder (26 sections), Record Auto / Capture On, Exit PERF, one-shot, held steps. Rendered with the Python fallback (`render_manual.py`); the marked package wasn't reachable.
- New check `test_fakedom/pages40.cjs` (20 checks, three passes); the 13 input-value and 31 follow checks still pass.

## Input Values and CC10/CC11 Fixes

- Added **INPUT VALUES**: FZED (the controller sends FZED values and CC10/CC11 pairs) or Plain 0-127 (any controller; values are scaled to each setting).
- Fixed: a learned FZED CC with compressed values (LFO 1 waveform, key range, sustain/end steps) was read as 0-127, so the LFO 1 waveform stayed on SIN. FZED values now land on the right setting.
- Fixed: a plain 0-127 CC50 in Follow and forward was passed raw to the FZ (an invalid waveform value) and displayed as RND above 5. It is now scaled and sent as the FZED value.
- Fixed: MIDI Learn could bind CC10 from a controller that sends a parameter pair, which then hijacked every CC10/CC11 pair. With FZED input values, Learn now ignores CC10/CC11 (and cancels), and stale CC10/CC11 learns are ignored.
- Fixed: a bare CC11 after one CC10 was ignored; it now keeps editing the selected parameter, as FZED does.
- Plain 0-127 controllers can learn one CC onto any indexed parameter (for example LFO2 destination 2); the editor sends the CC10/CC11 pair or macro FZED expects.
- Notes / bend thru no longer forwards CC11, which FZED reads as a parameter value.
- New checks run the editor with a small DOM stand-in (no jsdom available): 13 input-value checks and the 27 existing follow checks, three passes each.

## Follow Mode and Current Controls

- Added Off, Display only, and Follow and forward input modes. Display-only changes never echo to MIDI; forward mode sends each original incoming CC message exactly once and requires enabled output.
- Follow resolves ordinary CCs on any page, routes context-sensitive FX and Capture controls from current editor state, and decodes indexed CC10/CC11 writes for voice parameters, envelope steps, controllers and matrix values.
- Added optional page following, enabled by default and rate-limited to one page change per 300 ms. MIDI Learn keeps priority on the visible page.
- Regenerated the editor profile and metadata from Gills Core80, including its current parameter/helper mappings, Capture RELEASE and Chop/Pattern assignments.
- Added a default-off, confirmation-gated MIDI Actions switch and per-command MIDI Learn. Learned commands trigger on a rising edge only; each selectable action command is learned independently.
- A single learned CC mapped to an indexed parameter now emits the target CC10/CC11 pair in Follow and forward mode without forwarding the source CC too.
- Added regression checks for full 0-127 key-range input, LFO1 waveform following, single-CC indexed mapping, and opt-in record commands.
- Added automated tests for display-only, exactly-once forwarding, indexed values, contextual CCs, learned-control priority and page-follow behavior.
- Current profile details carried forward: RELEASE offers TOGETHER / TOP FIRST; CC110 has five recording-filter bands; FX unused pots are omitted and context labels follow the selected effect; CC71 is TAPE SPEED; Core80 moves Chop/Pattern to P6-P8 and RELEASE to Capture 2 P5. The Gills-only MIDI OUT selector is not presented as an FZED control.

## PERF39A / Core77 Editor Update

- Rebuilt the editor profile from Core77 and aligned it with PERF39A.
- Kept the five CC110 filter/cutoff bands on Record only; Capture omits Norm Filter.
- Added the current Capture RELEASE (CC41) with the two modes implemented by PERF39A: TOGETHER and TOP FIRST.
- Updated the manual for persistent CC110 choice, ascending strums, widened capture key range, octave-rounded PASSES holds and fairer capture length/rate matrix updates.
- User-facing manual now describes only the available Release choices, without implementation-history notes.

## Record-Only Norm Filter

- The browser presents CC110 on Record only. Its selected recording filter remains in effect during Capture, without duplicating the control on the Capture page.

## Norm Filter Documentation Verification

- Confirmed from recording ROM bytes that 36 kHz bypasses the switchable input anti-aliasing filter, while both 18 and 9 kHz enable it. The service manual's NORM table independently groups 18/9 apart from 36.
- Documented the earlier binary's CC110 on/off behaviour and its lack of cutoff control or persistent capture override. This description is superseded by PERF39A's five-band CC110 control.
- Three isolated bytecode passes, 96 state/rate/switch cases each, passed. These do not measure analogue response or constitute a hardware recording test.

## Browser Capture Consolidation

- One browser Capture page combines thirteen recording/hold/chord/transition controls, without tabs. Pattern controls and Delete Unused/Normalise remain only on Chop/Pattern. The hardware controller's encoder views and the optional-software binary are unchanged.
- Preserved existing capture parameter and Learn identities. Learn assignments are exclusive across the combined page, and a legacy duplicate incoming mapping can no longer trigger two capture parameters at once.
- Manual explicitly warns that Live FX may not work above 9 kHz, short samples may still work at higher rates, and Render is more reliable but destructive.

- Renamed the editor FZED; retained existing version-38X settings-file compatibility and the 26-preset USER_FZ.BIN.
- Browser and Gills: Record, Capture (1/2), Chop/Pattern, FX, User. Gills uses the encoder to select Capture 1/2.
- Matrix view order: Source, Destination, Amount. Parameter IDs and values are unchanged.
- Gills: expanded physical page count and selection storage, distinguished ordinary/capture aliases with explicit view context, updated OLED titles and entry-cache invalidation. New SRAM3 marker: 4753F047h.
- Browser: separate Capture-view MIDI Learn handling and unlearning; grouped navigation never starts capture.
- Added the FZED user manual as HTML and Markdown, covering all menu groups and important state/processing limitations.

Historical verification: three host-compiled Core71 menu passes and three editor DOM/MIDI passes. Those checks covered the previous Core71/PERF38X revision only.

Limits: no full revised target-firmware build or hardware test; browser screenshots blocked by the macOS Chromium Mach bootstrap restriction. Host/DOM checks are not substitutes for those tests. The FZ optional-program source and disk remain unchanged.
# PERF39C / Core81 bank builder

- Add This Voice now adds the currently edited voice to the selected/available bank for the incoming MIDI channel. Clearing removes only that channel's entry.
- Selecting a bank also selects the add target; without an explicit target, FZED uses the existing PERF BANK or names the first empty bank.
- Adding leaves the program in voice-edit mode rather than starting bank playback.
- CC16 remains BANK VOICE for preset-wave writes. No new voice-selection action was added.
- PERF39C and Core81 have not been tested on hardware.

## PERF39C Seven Waves / New Voice

- PERF39C retains the seven original preset waveforms and uses CC16 for NEW VOICE.
- NEW VOICE selects the first empty voice after a low-value re-arm; it is refused during recording/capture and inactive in bank-play mode.
- Core82 labels the CC16 action and limits preset-wave selection to OFF plus the seven retained waveforms.
- The browser editor confirms NEW VOICE and sends the re-arm edge before the trigger. Its manual now lists the available waveform set.
- The voice-selection fields are grounded in the FZ ROM Voice Edit path at 0x787B-0x7892; hardware testing is still required.

