# FZED Menu Revision

## Preset Waves From The FZED Disk (next)

- FZED: the preset wave generator moved from resident memory into a disk overlay (sector 50), freeing about 495 bytes in the crowded lv code area for later work. The seven waves come out word for word as before, with the same messages and refusals (emulator check `work/fzed/tests/wave40.py`).
- Loading a wave now reads FZED's disk when the overlay isn't already in memory (after a render, capture, tool or buffer-using live effect): keep the FZED disk in the drive, or the FZ shows TOOLS NOT LOADED.
- Capture and bank mode are still refused with WAVE: REFUSED before the overlay loads. If the FZ's own calls ever push the stack into the overlay's end, the load is refused rather than run on damaged code.

## Loop Mode ORIGINAL Restores Loop Points

- FZED: Loop Mode ORIGINAL now also puts the voice's loop points back as they were when FZED took the voice (it already restored the loop times and the sustain / end loop). A preset wave's perfect loop comes back after Loop Start / End have moved it. Moving Loop Start / End afterwards works from the knob position as before. STRETCH OFF keeps the loop points you set before Stretch (with the voice's own loop times and sustain / end loop, as before); choose ORIGINAL after it for the voice's own points. Space: the three copies of the voice's loop table share one routine, which freed the bytes.
- Manual: leaving with ENTER (Keep Sound) while Stretch is on keeps the stretch loops but puts the start and end back (a Cut Lead-In start is not kept); Keep All Of Edit Voice or Keep All saves it as heard. The manual had said ENTER kept the moved start.

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

