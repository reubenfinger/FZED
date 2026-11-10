# FZED Browser Editor: developer notes

FZED is the browser editor for the current FZ optional-software controls.

The matching disk / source are `FZ1_FZED.img` (load **A FZ1_FZED.hfe**) and `work/fzed/fzed.asm` (build with `work/fzed/build.sh`). Gills Core 110 supplies the labels, values and held steps; the editor's pages follow the Gills menu, with two-view menus shown on one page (Capture) and the views that are menus of their own (Stretch, Slices) as their own pages. Gills-only controls (GO TO page, MIDI OUT, bank latch, FZ MIDI channel) are left out: the editor's CH selector is the MIDI channel. **Bank Builder** gathers the bank controls with the build sequence.

## Open

Open `FZED.html` in Chrome or Edge, or serve this folder on localhost and open `index.html`. A localhost preview uses `http://127.0.0.1:8918`. Browsers without Web MIDI can still edit and save settings offline. If MIDI is unavailable from a local file, use localhost. No installation, account, external font or CDN is required.

1. Load the intended voice and start PERF39A on the FZ. Match the MIDI channel.
2. Connect MIDI in the editor, choose the output, then enable output. Do not create a MIDI feedback loop.
3. Start with one harmless control, such as filter cutoff. Nothing is transmitted automatically on opening the editor.
4. Save/Open settings uses browser/editor JSON. The User Presets page keeps a Gills `USER_FZ.BIN` bank you can build, name and download. Neither contains sample audio or an FZ voice dump.

The on-screen audition keyboard displays four octaves at once; the octave buttons shift the range. It sends notes only when output is enabled. Notes/bend thru and clock thru are independently opt-in. ESC releases the editor's held notes and cancels MIDI Learn; it does not press the FZ's physical ESC key. Panic sends sustain off, CC120 and CC123, and releases notes the editor owns. It is not a replacement for recording STOP, nor proof that firmware can recover from every hang.

## Menus

| Page | Scope |
| --- | --- |
| Filter / Keys | Cutoff, resonance, Tape Speed (CC71), key range |
| ADSR | DCA/DCF shapes and signed velocity levels |
| Envelope stages | All eight DCA/DCF rate/level stages, sustain and end selectors |
| LFO 1 / LFO 2 | Shapes, depths, delays, fades, clock divisions, second destination/depth |
| Key / Velocity | Signed key-follow, rate scaling and velocity settings |
| Controllers | Separate mod-wheel, foot and aftertouch assignments; glide; confirmed voice INIT |
| Mod matrix | Ten routes, source/destination/amount views |
| Play / Loop | Bounds, loop mode, crossfade, play mode, window/snap; preset-wave selection and confirmed replacement |
| Stretch | Segments, hold time (32 steps, 0.02-19.5 s), grain, crossfade, snap, sustain, next / lead-in, order, skew, on / off |
| Record | Ordinary record controls and EXIT PERF (discard / keep sound / keep all of edit voice / keep all) |
| Capture | One page: rate, length, gain, hold, transpose, sync, on/off, recapture, intervals, velocity, stagger, fade and RELEASE |
| Chop / Pattern | Slice settings/actions, output, CHOP INTO / FREEZE, patterns/smoothing |
| Slices | Slice, move, lowest / highest, slice output, per-slice filter / env / LFO 1, copy voice |
| FX | All fifteen effect bands, matching parameter names and Ring/KS bindings |
| Bank builder | Voice pick / select, new voice, copy voice, bank select, add / clear, chop into / freeze, and the build sequence |
| User presets | 47 bundled presets (26 Gills + 21 page presets); save, name, rename, delete; BIN open/download |

Controls with distinct steps (lists, notes, semitones, stretch times) show exactly the steps the Gills core holds, and send the middle of each step.

The bundled bank starts with the Gills bank `Gills/outputs/SD_CARD_PERF38H/USER_FZ.BIN` byte-for-byte (26 presets, slots 1-26) and adds 21 page presets in slots 27-47: seven stretch (ST), five pattern (PT, on matrix route 10), six effect (FX) and three LFO 1 (LF). Each editing page has a Presets bar listing the presets that hold only that page's settings, with Open, Send and Save as preset.

**Open** applies a preset to local controls and locks output; it does not transmit. **Send** requires enabled output and confirmation and replays the stored values at 20 ms per parameter. Matrix clear (parameter 120) goes first when the preset holds it. Action fields are never stored or sent: recording, preset-wave replacement, bank routing, voice INIT, chop, normalise, render.

The bank's **INIT** preset resets PERF additions, not the whole FZ voice: it intentionally leaves existing sample bounds, filter and envelopes alone. It is different from the confirmed VOICE INIT command on Controllers. The bank controls add the currently edited voice, using the selected bank and incoming MIDI channel. Core banks store wire values; the editor converts them back to pot positions only where the exact Core82 mapping can represent them.

**Save as preset** stores the editor's current values in a slot with a 12-character name, for this page, the pattern only, or the whole voice. Presets can be renamed or deleted. **Open USER_FZ.BIN** accepts a compatible 54,416-byte GLUSER01/device-4 bank and locks output. **Download USER_FZ.BIN** saves the bank for the controller's SD card. The bank is kept in this browser until downloaded or replaced (Bundled bank, New empty bank). Stretch values are stored in bytes 530-541 of each slot ('S' marker); Gills Core 109 replays them, older cores ignore them.

## Values And MIDI

- Human-readable values come from Core80's actual display functions, compiled and evaluated for every input value. The small numeric field is always the controller's **raw 0-127 input**, not necessarily the final wire value. Key notes, waveform IDs and envelope stage indexes use Core80's transformations.
- Signed key/velocity settings retain neutral raw 64. The -128 edge is shown as Core80 shows it; the editor does not silently alter firmware encodings. Envelope-rate direction preservation and nonzero storage are PERF39A's responsibility, not extra browser transformations.
- CC10/CC11 indexed writes are sent as a group. LFO2 destination 2 retains Core80's four-message route-10 macro. Follow mode decodes Gills' incoming pairs and a single learned CC can be remapped into the pair required by the FZ.
- **INPUT VALUES** says what the input controller sends. **Plain 0-127** (default): any controller; each CC's full travel is spread across the control's settings (for example the six LFO 1 waveforms), and Follow and forward sends the scaled FZED message, including CC10/CC11 pairs for indexed parameters, never the raw value. CC10 and CC11 are then ordinary learnable CCs. **FZED messages (as sent)**: FZED values and CC10/CC11 pairs, as the Gills, a sequencer replaying the editor's output, or a controller set to Appendix A sends them; values are converted to each control's position, pairs are followed, and forwarding passes messages through unchanged. A bare CC11 keeps editing the last CC10 parameter, as FZED itself does. MIDI Learn ignores CC10/CC11 in this setting. A plain knob learned onto a control other than its own FZED CC is always treated as 0-127. **Remote SL** is offered only when the editor is opened as `FZED.html?remotesl` (or once it has been chosen). **IN** can be **All inputs**: every input except the one whose name matches OUT.
- Notes / bend thru no longer passes CC11: FZED reads CC11 as the value of the parameter chosen with CC10.
- Incoming MIDI Learn assignments apply only on the current view, to its selected stage/controller/route field. A single learned CC assigned to an indexed parameter emits the CC10 identifier and CC11 value pair. Explicit commands have per-command Learn controls and remain disabled until MIDI actions are deliberately enabled and confirmed; rising-edge triggers prevent repeated firing from a held CC.
- Input notes, note-off velocity, zero-velocity note-on, pitch bend, aftertouch and selected performance CCs can pass through when explicitly enabled. Incoming channel is remapped to the chosen output channel. System clock/start/continue/stop has a separate switch. This is not unrestricted MIDI or SysEx thru.
- Continuous edits are queued and pending writes to the same parameter coalesce. Switching input, output or channel locks output, clears pending writes and releases notes/sustain at their original endpoint.

## Norm Filter

CC110 selects the switchable recording-input filter and cutoff. Core80 labels the five value bands shown below; PERF39A reapplies the last choice after recording setup and each capture take, until PERF exits. Before the first CC110 message, the normal rate-dependent defaults apply.

| CC110 | Display | Effect |
| --- | --- | --- |
| 0-63 | OFF | Filter bypassed |
| 64-79 | ON 18K CUT | Filter on, 18 kHz cutoff |
| 80-95 | ON 9K CUT | Filter on, 9 kHz cutoff |
| 96-111 | ON 4.5K CUT | Filter on, 4.5 kHz cutoff |
| 112-127 | ON RATE CUT | Filter on, cutoff follows recording rate |

The browser exposes CC110 on Record only. Its selection remains active through Capture takes. Changes affect subsequently recorded input, not already recorded PCM. The editor shows the last value it sent; the FZ provides no hardware readback.

RELEASE (CC41) is on the combined Capture page. Choose TOGETHER to release the chord at once, or TOP FIRST to release from the highest note down at the Stagger interval. Chord strums run from low to high. Fade timing starts after the last note-off. Capture widens the key range before chord playback. PASSES hold time rounds transpose to the nearest octave without changing pitch. Slow matrix routes to capture length/rate alternate updates; with three or more slow routes, a later route can still be delayed.

## Important Limits

**Live FX may not work reliably above 9 kHz. Short samples may still work at higher rates. Render is more reliable than Live FX, but destructive: preserve an untouched sample before rendering.** Lower rates are a practical starting point, not a guarantee for every sample/effect workload.

**There is no FZ parameter readback.** A dash means no local value, not the FZ's default. Reopening the editor restores local settings without sending them. An enabled output does not mean local values equal the voice. Sending a view transmits only its stored, non-action values, after confirmation; it is not a complete patch synchronisation. Select the intended FX algorithm explicitly before adjusting effect-dependent controls.

**Page selection is local navigation, not a capture command.** Enter/Leave capture is explicit on the Capture page. Its shared CCs have different meanings inside and outside capture; ensure the FZ is in the matching state. Transpose, sync and fade use safe aliases CC23, CC33 and CC34. Firmware ignores some FX, wave and loop changes during capture. The browser does not override these guards.

PERF39A also makes CC108 context-dependent: with the ordinary recorder armed it enables auto-trigger; otherwise a high value enters capture. Enter capture with the recorder idle. The Record page label does not change this firmware behaviour. Repeated slice, render, normalise, INIT and bank actions include their required re-arm edge.

Raw envelope stages and ADSR are two ways to edit overlapping envelope storage. Do not send contradictory views expecting independent envelopes. There is deliberately no global Send All. The graph is a local schematic, not measured timing, device readback or audio analysis.

Preset replacement, recording, render, normalise, slice creation, bank clearing and INIT require deliberate confirmation. Preset wave selection alone sends only CC111; replacement sends CC111, CC9=0, CC9=127. Imports never run actions, and lock output. Existing PERF38C JSON is rejected rather than guessing how obsolete encodings should migrate.

## Verification And Provenance

`work/fz_browser_editor/build_profile.py` generates `profile.js` from Core80 and its shared header. There are 379 contextual control records, each with 128 formatted values and exact wire mappings, including the five CC110 labels and current RELEASE / pattern assignments. The profile includes source hashes for Core80 and PERF39A. FX-page Delete Unused and Normalise helper commands appear separately from effect parameters; duplicate helper-pot parameter aliases remain hidden while Follow uses the full Core80 map across pages.

The DOM/MIDI test report covers editor behavior only; it does not verify hardware behavior. See `VERIFICATION.json` for the current verification status.

Full Chromium/Playwright launch was blocked by the macOS sandbox's Mach bootstrap restriction. **Desktop/mobile screenshots and real-browser MIDI permissions have not been verified.** A Playwright test is included in the repository work folder for rerunning outside that restriction. DOM tests are not a claim of browser layout or hardware success. PERF39A capture alternates recording and playback and retains its timing limits.

The standalone HTML embeds all app assets. The ZIP also contains the editable split-file version, source/mapping manifest and Lucide's license. `SHA256SUMS.txt` covers the package files.

Airwindows-derived effects in the optional software are credited to Chris Johnson / Airwindows under the upstream MIT licence. The manual reproduces the complete licence and the source-specific 2016 notices; `LICENSE_AIRWINDOWS.txt` and `THIRD_PARTY_NOTICES.md` are included in this package. This attribution does not relicense unrelated code or imply endorsement.

The source profile comes from Core80; no controller firmware changes are included in this browser-editor package. PERF39A's corresponding source and image are included in the project outputs, but this editor update does not rebuild them.
