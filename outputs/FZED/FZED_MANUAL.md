# FZED
## User Manual

FZED optional software for Casio FZ hardware, operated through the FZED browser editor.

## 1. What FZED Is

FZED is optional software that runs on the Casio FZ and turns it into a more immediate, MIDI-controlled sampling instrument. The FZED browser editor sends parameter changes to FZED over MIDI. The FZ supplies the sample memory, sound generators, filters, envelopes, converters and audio outputs.

The FZED optional software combines voice editing with performance tools: MIDI-controlled envelopes and loop windows, two LFO systems, a modulation matrix, sample-processing effects, slicing, rhythmic patterns, and an alternating record/play capture engine. It is not a replacement operating system, a plug-in hosted by the browser, or a new audio engine running on the computer. The FZED browser editor controls the hardware; it does not produce the FZ's audio.

A stored voice is a sound definition. An active generator is one of the FZ's eight simultaneous playback resources. Editing a voice, changing a running generator and processing sample memory are different operations: they need not become audible at the same moment. Some changes affect held notes; others depend on a new note, a new capture, the voice's configuration or a render. As a rule, the filter, envelopes, loop points, tape speed, LFO 2, the mod matrix and patterns change notes that are already sounding, while key ranges, play and loop mode, sample start, velocity and key-follow settings, and stretch apply from the next note you play. Appendix B lists every control.

This manual describes the FZED optional software and the FZED browser editor, not a claim that every combination has been proved on hardware. The browser editor's controls and MIDI output have automated tests; visual browser checks and hardware testing remain necessary. Use a known-working voice and verify each new sound path on the FZ.

## 2. Getting Started

1. Back up your samples and voices. Processing, recording, deleting unused data, slicing and loading preset waves can change memory.
2. Load a working sample/voice and verify it from the FZ keyboard in the normal operating system.
3. Load and execute the FZED optional software on the FZ. Entering optional software cuts existing audio; do not rely on holding a note while entering it.
4. Choose the startup option on the FZ: retain the loaded voice's settings, or initialise them. Retain is the usual choice for an already prepared sound. When there is no usable voice, the program follows its no-voice/init path.
5. Open the FZED browser editor and select the MIDI output connected to the FZ and the correct MIDI channel.
6. Enable browser output explicitly, then test one control, such as cutoff, while playing a note. The browser starts locked and never sends a patch automatically. While output is locked, moving a control makes the **Output locked** button flash: press it to start sending.

### Connecting The Browser Editor

Use a MIDI interface whose output reaches the FZ's MIDI input. If you want to play from an external MIDI keyboard through the browser editor, select that keyboard as the input and enable Notes / bend thru. Alternatively, audition with the browser editor's keyboard or the FZ keyboard.

Use a browser with Web MIDI support, such as Chrome or Edge. Grant MIDI access when requested. If opening the HTML file does not provide MIDI access, open the editor through localhost. Avoid sending the same notes through two parallel MIDI routes.

### Follow Controls From MIDI

**Follow** has three choices. **Off** keeps the existing MIDI Learn behavior. **Display only** follows incoming controls without sending those changes back to the FZ; use this when your controller already reaches the FZ directly. **Follow and forward** updates the editor and passes each incoming CC to the FZ once; use this when the controller reaches the computer but is not otherwise connected to the FZ. Output must be enabled for forwarding, and input and output must be separate MIDI ports.

**Input values** says what your controller sends. **Plain 0-127** (the default) suits any controller: each knob's full travel is spread across a control's settings, and in **Follow and forward** the editor sends the converted FZED message, including the CC10/CC11 pair an indexed parameter such as LFO 2 Destination 2 needs. Choose **FZED messages (as sent)** when the input already sends exactly what FZED receives, as listed in Appendix A: FZED's own values (for example 0-5 for the LFO 1 waveform) and CC10/CC11 parameter pairs. That fits a sequencer or DAW replaying what it recorded from the editor's output, or a controller set up with those numbers; the editor follows the messages and passes them on unchanged. With FZED messages, MIDI Learn ignores CC10/CC11 because Follow already tracks those controls; with Plain 0-127 they are ordinary CCs you can learn.

**IN** can be one MIDI input or **All inputs**, so several controllers can be used together. Learned controls remember the input and channel they were learned from. All inputs leaves out the input of the interface chosen as OUT, so the FZ's own messages are not fed back to it.

Follow listens on the selected MIDI channel and identifies controls across every page, including CC10/CC11 parameter pairs, envelope steps and matrix values. A CC10 message selects an FZ parameter ID; its following CC11 supplies that parameter's value, and later CC11 messages keep editing it until another CC10 arrives, as on the FZ. Follow keeps that pair's context separate by MIDI input and channel. Context-sensitive CCs follow the editor's current FX selection or Capture On/Off setting. **Follow pages** is on by default and switches to the relevant page, at most about once every 300 ms; turn it off to keep the current page visible while values continue updating in the background. Where FZED offers the same setting in two places, both update the one control in the editor.

## 3. Reading The Browser

The large value is a named or formatted value. The small numeric field is the raw **0-127** MIDI input value. These are not always identical: stage selectors become indexes 0-7 on MIDI, and key controls become note numbers.

Controls with distinct steps (lists, notes, semitones, stretch hold times) are stepped pots: drag up or down, use the mouse wheel or the arrow keys, one step at a time. Two-choice settings are switches. **FZ SCREEN** (beside the page title) shows what the FZ's own screen should show for every change: made in FZED with the mouse or keys (output enabled or not), or received from the controller (FOLLOW must not be Off): the lines are the FZ's own. Line 3 is FZED's message line (CHOP 08 SLICES, FX TAPEHACK, MIX 050%, the capture settings line C0010 x4 +00 F and so on). Line 4 is FZED's echo of the last message, C=ccc vvv for a controller or P=ppp vvv for a parameter; FZED leaves it out after the FX value, capture and chord messages. Lines 5-6 are the record settings and state. Lines starting with **>** (> PLAY SLICES, > PLAY VOICE) are the editor's own note of what CC98 asked for; the FZ shows only the echo for those. The screen is worked out from the messages, not read back from the FZ, so anything that depends on the FZ's contents is not shown: the voice name, whether a bank is empty, slice notes and results, stretch timing and the outcome of Render, Normalise or Delete Unused. Each page groups its controls by function (FILTER, KEYS, AMP, LOOP and so on). Related settings line up in columns, such as the amp settings above the filter ones. For stepped settings the editor sends the middle of each step, so a choice never lands on a border.

A dash means **no local value is known**. It does not mean zero or the FZ's default. There is no FZ voice-parameter readback. The editor remembers local values, not the actual current contents of the FZ.

| Browser control | Function |
| --- | --- |
| Connect MIDI / IN / OUT / CH | Grant MIDI access and select the source (one input or All inputs), destination and output channel |
| Output locked/enabled | Allow or stop outgoing parameter edits and audition notes |
| Follow | Off, display incoming controls without echo, or follow and forward incoming CCs once |
| Follow pages | Switch to the page of a followed control; values still update when this is off |
| Input values | Plain 0-127 values scaled for each control, or FZED messages (FZED values and CC10/CC11 pairs) passed through |
| Radio icon on a parameter | Learn an incoming CC for that control on the current view |
| MIDI actions | Separately confirm whether learned command CCs are allowed to run |
| Unlearn | Remove learned assignments from the current view |
| Send view | Confirm and send only stored, non-action values on the visible view |
| Save/Open settings | Export/import editor JSON; importing sends nothing and runs no actions |
| Notes / bend thru | Forward notes, bend, aftertouch and selected performance CCs to the selected output channel |
| Clock thru | Independently forward MIDI clock and transport messages |
| Keyboard / octave / velocity | Audition notes without automatic note triggering on startup |
| Panic | Release owned notes, turn sustain off, and send CC120 and CC123 |

MIDI Learn listens only on the chosen input. Parameter assignments operate on the visible page/view. Capture's recording and chord controls are all on the same page; assigning an incoming CC to a different capture control replaces its previous assignment on that page. Learning consumes its first assignment message without sending a parameter. A single learned CC can control an indexed FZ parameter: in **Follow and forward**, FZED sends the mapped CC10 parameter ID and CC11 value pair, and does not also forward the source CC. In **Display only**, the editor follows without sending anything.

Explicit command buttons also have their own MIDI Learn control next to each command choice. Learned commands are disabled by default. Turn on **MIDI actions** and confirm to allow learned command CCs; a rising value of 64 or higher triggers the chosen command once, and another trigger requires the CC to return below 64 first. This opt-in can start recording or change sample data, so keep Output locked until ready and turn MIDI actions off when finished. On-screen command buttons continue to ask for confirmation each time.

Changing a port or channel, or a MIDI device appearing or disappearing, locks output and releases notes and sustain at their original destination. ESC in the browser releases its notes and cancels Learn. It does not operate the FZ's physical ESC key. Avoid MIDI feedback and simultaneous indexed CC10/11 edits from two controllers on the same channel.

## 4. Menu Order

| Page | Name | Browser subviews |
| --- | --- | --- |
| 1 | Filter / Keys | One view |
| 2 | ADSR | One view |
| 3 | Envelope Stages | Stages 1-8 |
| 4 | LFO 1 | One view |
| 5 | LFO 2 | One view |
| 6 | Key / Velocity | One view |
| 7 | Controllers | Mod wheel / Foot / Aftertouch |
| 8 | Mod Matrix | Source / Destination / Amount |
| 9 | Play / Loop | One view |
| 10 | Stretch | One view |
| 11 | Record | One view |
| 12 | Capture | One page: recording, hold, chord and transition controls |
| 13 | Chop / Pattern | One view |
| 14 | Slices | One view |
| 15 | FX | Effect-dependent controls |
| 16 | Bank Builder | One view, with the build sequence |
| 17 | User Presets | Preset list |

Page navigation changes the controls you see, **not the FZ's recording/capture state**. In particular, selecting Capture does not start recording, and selecting Record does not leave capture.

## 5. Filter / Keys

| Function | What it does |
| --- | --- |
| DCF Cutoff | Sets the voice filter's cutoff. Use high values for an open starting point |
| DCQ Resonance | Sets the filter resonance/Q; high settings can make the sound much louder or more concentrated |
| Tape Speed (CC71) | Changes how fast the FZ reads the sample already stored in memory: 36K, 18K, 9K or 4.5K words per second. It changes the voice playback-rate setting only; the sample data is untouched. |
| Original Key | Sets the sample's reference/root key (named notes, C2 = 36) |
| Highest / Lowest Key | Set the playable range. The firmware keeps it within three octaves of the original key; the browser cannot read back any clamping |

Choosing a voice to edit, bank selection and bank adds are on **Bank Builder** (section 20). Play Mode is on Play / Loop.

**Tape Speed (CC71)** is playback speed, not recording quality. Each step down halves playback speed, so the sample plays one octave lower, lasts twice as long and sounds duller. Each step up doubles speed, raising it one octave and halving its duration. The four CC71 bands are 0-31 = 36K, 32-63 = 18K, 64-95 = 9K and 96-127 = 4.5K words per second. Changing Tape Speed does not rewrite or resample the stored audio.

## 6. ADSR

There is one simplified envelope for amplitude (DCA) and one for the filter (DCF).

| Function | Meaning |
| --- | --- |
| Attack | Time/rate control for reaching the initial peak after note-on |
| Decay | Time/rate control for moving from peak to sustain |
| Sustain Level | Level maintained while a note is held, subject to the voice's envelope state |
| Release | Time/rate control for moving towards the final level after note-off |
| Velocity > Amp Level | Signed sensitivity of amplitude level to note velocity |
| Velocity > Filter Level | Signed sensitivity of filter-envelope level to note velocity |

Lower time controls are faster and higher controls slower. Sustain is a level, not a duration. These controls arrange the underlying eight-stage envelope into a simpler shape; they are not an independent envelope layered over the stage editor. FZED's ADSR handling establishes sustain at stage 2 and end at stage 3.

The browser graph is a local schematic, not measured envelope timing or audio. Changing an envelope's sustain/end stages after setting ADSR can change how note release behaves. Do not send an ADSR view and a contradictory raw-stage view expecting both to coexist independently.

## 7. Envelope Stages

Choose stage 1-8, then edit its DCA rate/level and DCF rate/level. The other controls choose the sustain and end stages for each envelope.

| Function | Meaning |
| --- | --- |
| Amp Rate / Filter Rate | How quickly the envelope travels during this stage; FZED presents a time-oriented control, preserving the stored direction bit |
| Amp Level / Filter Level | Target level for that stage |
| Amp / Filter Sustain Step | Stage used as the held-note sustain point |
| Amp / Filter End Step | Stage at which that envelope ends |

Displayed stages 1-8 are transmitted as indexes 0-7. A stage rate sent through FZED is not a raw memory byte: the firmware preserves direction, reverses the control's rate encoding and prevents the zero-movement endpoint in this path. Do not infer that an arbitrary byte value zero in an old voice is a safe release.

For a dependable amplitude release, arrange a final target of zero and a reachable end stage after the sustain stage. Conflicting stage order, levels or direction can create sustained/looping behaviour even when MIDI note-offs arrive correctly. Changing a stage may require a fresh note to assess it reliably.

## 8. LFO 1

| Function | Meaning |
| --- | --- |
| Rate | Speed of the FZ's first LFO |
| Waveform | Sine, saw up, saw down, triangle, square or random |
| Pitch Depth | Amount applied to oscillator pitch |
| Amp Depth | Amount applied to amplitude |
| Filter Depth | Amount applied to DCF |
| Resonance Depth | Amount applied to resonance |
| Delay | Wait after note-on before the LFO envelope develops |
| Attack | LFO depth build-up control |

Controller assignments can add wheel, foot or aftertouch influence to these destinations. They are separate from setting a fixed LFO depth. Voices can carry different modulation behaviour: test with a known-working voice rather than assuming every imported sample has the same setup.

## 9. LFO 2

LFO 2 is FZED's additional modulation source. It can drive one direct destination and an additional matrix-based destination. Its **Warble** shape attempts to emulate tape warble.

| Function | Meaning |
| --- | --- |
| Rate / Division | Free-running rate, or a MIDI-clock division when Mode is set to MIDI Clock |
| Depth | Amount applied to the primary destination |
| Shape | Triangle, sine, saw up, saw down, square, random sample-and-hold, one-shot ramp or warble |
| Destination | Off, cutoff, pitch, LFO1 pitch depth, LFO1 amp depth, LFO1 filter depth, tremolo, or bend/Cue scrub |
| Mode | Free, note retrigger, or MIDI clock |
| Delay | Time after note-on before modulation starts |
| Fade-in | Time for the modulation to grow |
| Destination 2 | An additional destination implemented using matrix route 10 |
| Depth 2 | Signed amount for route 10 |

When Mode is set to Free or Note Retrigger, Rate / Division sets the free-running speed. In MIDI Clock mode, it selects 4 bars, 2 bars, 1 bar, half, quarter, eighth or sixteenth. MIDI clock must actually reach the FZ. Enabling a clock label does not generate clock in the browser.

**Destination 2 reserves matrix route 10:** it sets that route's source to LFO 2 and changes its destination. Editing route 10 directly changes the same routing. It is not an eleventh matrix slot. The browser shares the local state between these controls.

## 10. Key / Velocity

These controls change how a sound responds across the keyboard and to playing strength.

| Function | Meaning |
| --- | --- |
| Velocity > Resonance | Velocity influence on resonance |
| Amp Key Follow | Amplitude-envelope level change with key position |
| Amp Rate Scale | Amplitude-envelope speed change with key position |
| Filter Key Follow | Filter-envelope level change with key position |
| Filter Rate Scale | Filter-envelope speed change with key position |
| Velocity > Amp Level / Rate | Velocity influence on amplitude-envelope level/speed |
| Velocity > Filter Level / Rate | Velocity influence on filter-envelope level/speed |

The signed controls use raw 64 as neutral; below and above it request opposite directions. The FZED browser editor displays the FZ scaling, twice the offset from 64, rather than an unsigned 0-127 percentage. The raw-0 edge displays -128; that edge remains a known range caveat rather than a newly calibrated musical unit. Large sensitivities can make particular keys or velocities nearly silent. Use moderate values when checking for missed notes.

## 11. Controllers

Select Mod Wheel, Foot or Aftertouch. Each view provides the same seven destinations:

| Assignment | Effect |
| --- | --- |
| LFO Pitch / Amp / Filter / Resonance | Controller influence on LFO1 depth to that destination |
| Amp Offset | Controller influence on amplitude offset |
| Filter Offset | Controller influence on filter offset |
| Resonance Offset | Controller influence on resonance offset |

Mod wheel is CC1, foot is CC4, and aftertouch is MIDI pressure. Breath CC2 is also a modulation-matrix source. Do not confuse a controller-to-LFO assignment with changing the LFO's base depth.

The remaining controls are:

| Function | Meaning |
| --- | --- |
| Glide Time | Speed/time of FZED's mono pitch transition |
| Glide Mode | Off, legato (overlapping notes), or always |
| Voice INIT | Deliberately initialise the current voice's settings; this is not the User bank's INIT preset |

Glide uses the FZ bend path. FZED temporarily expands the bend range for it and scales the player's bend contribution. It is not independent polyphonic portamento. Voice INIT can replace useful voice settings; save first and use its confirmation.

## 12. Mod Matrix: Source, Destination, Amount

There are ten routes. In the FZED browser editor, select Source, then Destination, then Amount. Each view presents the same ten numbered routes: the control for route 1 always edits route 1, through route 10.

### Sources

| Source | Meaning |
| --- | --- |
| Off | Disable the route |
| Velocity | Note-on velocity |
| Aftertouch | MIDI pressure |
| Mod Wheel | CC1 |
| LFO 2 | Bipolar LFO2 signal |
| LFO 2 Unipolar | One-sided LFO2 signal |
| Random | Random modulation |
| Key | Played note/key position |
| Pitch Bend | Player's bend input |
| Breath / CC3 / Foot | CC2, CC3, CC4 respectively |
| Pattern | Rhythmic pattern signal |
| Pattern + | Pattern-derived positive/ramping signal |
| Remaining Off bands | Reserved/off, not extra active sources |

### Destinations

| Destination | What changes |
| --- | --- |
| Off | No destination |
| Cutoff / Resonance / Level / Pitch | Filter, Q, amplitude or pitch |
| LFO1 > Pitch / Amp / Filter | LFO1 depth to the named target |
| Sample Start | Sample start-position modulation |
| Loop Window | Position of the loop window |
| Loop Start / Capture Length | Loop start normally; capture duration while capture runs |
| Loop End / Capture Rate | Loop end normally; capture rate while capture runs |
| LFO2 Rate / Depth | Modulate the second LFO itself |
| FX Mix / Resonance | Effect mix, or the filter effect's corresponding resonance control |
| FX Parameter / Cutoff | Effect parameter, or filter effect cutoff |

Amount is signed, with raw 64 neutral. The display uses -64 to +63 as controller units, not semitones, milliseconds or a universal percentage. Several routes can influence a target, so begin with one route and small amounts. Avoid self-modulation or overlapping routes until the basic result is understood.

Capture length and rate are relatively slow destinations. Their updates now take turns: with LFO 2 moving both over one second, the earlier scheduler produced 49 length updates and 3 rate updates; the current scheduler produced 25 and 19. If three or more slow routes move together, a later route can still be kept waiting. Capture widens the voice key range before playing chord notes; the FZ still applies its own generator limits.

## 13. Play / Loop

| Function | Meaning |
| --- | --- |
| Sample Start / End | Requested sample playback bounds, scaled to the voice's available data |
| Loop Mode | One-shot, original voice behaviour, or loop; the FZ shows ONE-SHOT, ORIGINAL or LOOP. Original puts the voice's own loops back exactly as they were when FZED took the voice: loop points, loop times and the sustain / end loop, so a preset wave's perfect loop returns after Loop Start / End have moved it. One-shot stays one-shot when Sample End, Loop Start / End or the window move afterwards; those positions are remembered for Loop |
| Loop Start / End | Requested loop bounds |
| Loop Crossfade | The FZ sample crossfade setting, useful for changing loop/playback character; not the capture fade or an external audio crossfader |
| Window Position | Move the loop window while retaining its window relationship |
| Window Snap | Free movement, zero-cross snapping, or whole frames |
| Play Mode | Original, Reverse or Cue; the FZ shows ORIGINAL, REVERSE or CUE. Cue enables the bend/Cue sample-position scrub path; it is not an extra sample slot |
| Preset Wave | Select one of the seven original waveforms: Saw, Square, Pulse 25%, Pulse 12%, Triangle, Sine or Double Sine |
| Load Selected Wave | Deliberately replace/generate the selected preset wave. FZED reads the wave generator from its disk when needed, so keep the FZED disk in the drive (on an HxC, keep FZED selected); otherwise the FZ shows TOOLS NOT LOADED |

These position controls are not absolute sample-number entry or a waveform editor with point readback. Firmware may constrain the result, and sample/loop validity matters. Zero-cross snapping can reduce discontinuities but cannot guarantee an inaudible edit in every sample. Capture guards refuse loop-window position/snap changes during capture.

CC111 selects in bands of eight values: 0-7 Off, then Saw, Square, Pulse 25%, Pulse 12%, Triangle, Sine and Double Sine up to 63. Off (and any value from 64 up) selects nothing, so nothing is loaded; it does not load a silent sample.

In the FZED browser editor, choose a wave, click Load Selected Wave and confirm replacement. The editor sends CC111 for the wave, then CC9 = 0 to arm the load and CC9 = 127 to load it. FZED refuses the load with Live FX on, in bank mode, with chop slices, while recording, or when the voice is shorter than 1800 words. Wave selection alone never replaces the sample. Back up a valuable sound first.

## 14. Stretch

Stretch cuts the voice's play range (start to end) into 2-8 back-to-back segments and gives each one of the FZ's loops. Each loop holds for its loop time, then the note moves on to the next; the last segment is the end loop. Nothing is copied or recorded, so it uses no memory. Loop changes are heard from the next note.

| Function | Meaning |
| --- | --- |
| Segments | 2-8 segments |
| Stretch (Time) | How long each segment holds: 32 steps from 0.02 s to 19.5 s (about 19.8 ms per loop-time step, the same on every key) |
| Grain | The length of each segment's loop, as a share of the segment. Each hold also includes roughly one and a half passes of the grain, which follow the key played |
| Crossfade | The loops' crossfade |
| Snap | Loop points at the nearest zero crossing |
| Sustain At | The segment that holds while the key is down. The choices follow Segments: the lowest position is NO SUSTAIN, then HOLD SEGMENT 1 up to the last segment (9 positions at 8 segments, 3 at 2) |
| Next / Lead-In | TRACE: after a loop's time, play on through the material to the next loop. SKIP: jump straight to it. A loop earlier in the sample is always a jump. CUT LEAD-IN: start the note at the first loop instead of the sample start |
| Order | Forward, Reverse, There + Back (for example 1 3 5 7 8 6 4 2) or Shuffle 1-8 (each one a fixed order) |
| Skew | Even in the middle. Below: earlier segments hold longer and later ones shorter (speeding up); above: the reverse |
| Stretch On/Off | On builds the loops. Off puts the loops back as they were before Stretch: your loop points as you last set them, with the voice's own loop times and sustain / end loop (and its start, if Cut Lead-In moved it). Loop Mode Original then gives the voice's own loop points |

With Cut Lead-In and Reverse or Shuffle, the voice's start point moves to the first loop. The software keeps your own start point and works the segments out from it; it is put back by Play, Forward or Stretch Off. If you move the start yourself meanwhile, that becomes the new start. Leaving with ENTER (Keep Sound) while Stretch is on keeps the stretch loops, but puts the voice's own start and end back, so after Cut Lead-In the saved voice plays the lead-in before the loops. To save it exactly as heard, leave with Keep All Of Edit Voice or Keep All.

## 15. Record

Record contains ordinary recording controls. The next page, Capture, contains the alternating record/play engine.

| Function | Meaning |
| --- | --- |
| Record Rate (CC102) | Selects the rate/quality at which new audio is recorded: 36K, 18K, 9K or 4.5K |
| Record Length | Requested allocation/duration; display depends on recording rate |
| Input Gain | 0 dB or -20 dB input gain state |
| Auto Trigger Level | Threshold for armed auto-trigger recording |
| Record Arm | Prepare recording. On a voice that already has a sample, only 120-127 arms (replacing it); lower shows USED: ARM 120+ |
| Record Start | Start an armed recording |
| Record Auto | Armed: wait for the input threshold. Not armed: shows NOT ARMED (capture is entered from the Capture page) |
| Record Stop | Stop ordinary recording |
| Norm Filter | Select filter bypass or one of four recording-input cutoff choices with CC110 |
| Exit FZED | Leave the optional software: Discard (as ESC: edits are put back), Keep Sound (as ENTER: sound edits kept, loops, start / end and play mode put back), Keep All Of Edit Voice, or Keep All (bank voices too) |

Ordinary length uses `(raw + 1) x 0.1 seconds`, doubled for each halving of the recording rate. This is different from Capture's fixed 16-duration menu.

### Norm Filter: Recording-Input Anti-Aliasing

The FZ's normal recording setup **bypasses the switchable anti-aliasing filter at 36 kHz** and **applies it at both 18 kHz and 9 kHz**. **18 kHz has been checked explicitly:** its record-start ROM path enables the filter and programs its cutoff; it is not treated like the 36 kHz bypass path. This describes the switchable recording filter, not an assertion that the analogue input has no other bandwidth limits.

| Recording rate | Normal recording-input filter state |
| --- | --- |
| 36 kHz | Bypassed |
| 18 kHz | Enabled |
| 9 kHz | Enabled, with a lower cutoff setting than 18 kHz |
| 4.5 kHz extension | Enabled; FZED additionally lowers the programmed cutoff. This is an extension, not a stock recording rate |

**CC110 selects both the input-filter state and cutoff at every recording rate.** The five value bands are:

| CC110 value | Display | Filter and cutoff |
| --- | --- | --- |
| 0-63 | OFF | Filter bypassed; rate's cutoff is left as set by recording setup |
| 64-79 | ON 18K CUT | Filter on; 18 kHz cutoff (7Ch) |
| 80-95 | ON 9K CUT | Filter on; 9 kHz cutoff (6Ch) |
| 96-111 | ON 4.5K CUT | Filter on; 4.5 kHz cutoff (5Ch) |
| 112-127 | ON RATE CUT | Filter on; cutoff selected by the recording rate |

The named cutoffs can be selected at any recording rate. The 4.5 kHz cutoff is an FZED extension. The categories do not mean that every intermediate cutoff value is available.

This affects audio **as it is recorded**, not PCM already stored in a sample. It is not sample normalisation, the playable voice's DCF cutoff, or the FX-page software filter.

For ordinary recording:

1. Select the recording rate and length.
2. Activate **Record Arm** and confirm that recording is armed.
3. After arming, set the desired **Norm Filter** choice with CC110.
4. Activate **Record Start**, or **Record Auto** if you want threshold-triggered recording.

Once CC110 has been set, the optional software reapplies that choice after record setup and each automated capture take. It remains active through ordinary recording and capture until you leave FZED; it is not a persistent override after exit. The browser provides this control on Record only; it is not part of the Capture page. Before the first CC110 message, the FZ's rate-dependent defaults apply. A live change affects audio recorded after the change; it cannot alter PCM already recorded.

The browser has no hardware readback. Its selected CC110 value records the last value sent by this editor, not an independently confirmed FZ state.

**Record Auto never enters capture.** Without an armed recorder it only shows NOT ARMED. Capture On (on the Capture page) enters capture; it is refused while an ordinary recording is armed or running. Leave capture explicitly before returning to ordinary recording.

## 16. Capture

Capture records a short take, stops recording, restores playback/output, plays it as a note or chord, waits, and records again. It is **alternating recording and playback**, not simultaneous input recording with uninterrupted output. Very short takes are subject to service-loop overhead; requested milliseconds are not a guarantee of exact hardware timing.

The Capture page groups recording settings, playback hold, chord arrangement and transition controls. Use Capture On/Off to enter or leave capture. Opening the page only displays its controls; it does not start recording.

### Recording And Hold

| Function | Meaning |
| --- | --- |
| Rate | Rate for the next capture |
| Length | Duration of the next take |
| Input Gain | Input gain setting, applied safely for the next capture |
| Hold | How long the captured audio/chord plays before another take |
| Transpose | -24 to +24 semitones, raw centre near zero |
| Sync | Free running, or align captures to incoming MIDI-clock divisions |
| Capture On/Off | Enter with the ordinary recorder idle, or explicitly leave capture |
| Recapture | End the current hold and request the next take, subject to sync |

Lengths: **10, 20, 30, 50, 75, 100, 150, 200, 300, 500, 750 ms, 1, 1.5, 2, 3, 4 seconds**.

Hold: **1, 2, 4 or 8 passes; 2, 4 or 8 seconds; until recapture**. Sync: free, 1/16, 1/8, 1/4, 1/2, 1 bar, 2 bars or 4 bars.

Transpose uses CC23 and Sync uses CC33. These safe aliases do not arm/start ordinary recording outside capture. Length, rate and other shared controls still depend on capture state. A rate/gain change during a take is queued for the next capture; changing the length during a take does not retroactively change that take's latched hold calculation.

### Chord And Transition

| Function | Meaning |
| --- | --- |
| Intervals | Chord/interval set played from each take |
| Velocity | Same velocity (100), random, falling or rising across chord notes |
| Stagger | Delay between chord-note starts |
| Fade | Wait after note-offs before recording again so the release can play |
| Release | TOGETHER or TOP FIRST note-off order for the current chord |

Intervals: original only; octaves +12/-12; root/fifth/octave; major; minor; major seventh; minor seventh; fifth/octave below; wide spread.

Stagger: together, **20, 40, 60, 80, 120, 160, 200, 300, 400, 500, 600, 800 ms, 1.2, 1.8 or 2.4 s**. The FZED optional software latches stagger per chord, so changing it during a chord affects the next chord rather than moving already scheduled notes.

Chord notes always start in ascending pitch order, from the lowest note to the highest, when Stagger is enabled. This also means OCTAVES and 5TH + OCT BELOW now start on the lowest note rather than the root.

Release (CC41): **TOGETHER** releases every chord note at once. **TOP FIRST** releases the highest note first, then steps down through the chord at the selected Stagger interval. The wait set by Fade begins after the final note-off, allowing each note's amp release to sound.

Fade: cut, **50, 100, 200, 400, 800 ms, 1.2 or 1.6 s**. It uses safe alias CC34, not the destructive ordinary Chop action. Fade provides release time before recording; it is not simultaneous crossfading of recorded input and playing output.

Capture widens the voice key range before playing a chord, reducing silent notes caused by a narrow preset range. The FZ's own generator limits still apply. Capture reuses allocations where possible and explicitly stops shorter takes within a larger allocation; timing still has polling overhead. Many normal FX, wave-load and loop operations are refused during capture.

For PASSES holds, FZED rounds the transpose to the nearest octave when calculating hold duration. This does not change pitch; octave transposes retain the same hold behaviour as before. Other transposes can make a pass hold slightly shorter or longer than an exact whole number of sample loops.

Leave capture explicitly before returning to ordinary recording or sample-processing operations. A selected page is not a recording-state indicator.

## 17. Chop / Pattern

| Function | Meaning |
| --- | --- |
| Chop Sensitivity | Detection sensitivity for transient-based slicing |
| Chop Mode / Snap | Even slices, even slices with snapping, or transient detection |
| Slice Count | 4, 8, 16 or 32 requested slices |
| Create Slices | Deliberately generate the slice arrangement |
| Play Slices | Switch to the created slice playback arrangement |
| Return to Voice | Leave slice playback and restore ordinary voice playback |
| Output (Choke) | Off: slices overlap. 1-8: every slice on that mono output, so each slice cuts off the last |
| Chop Into | Own Bank: a chop goes into its own CHOP bank. Target Bank: into the bank being built, after its places, on the editor's MIDI channel |
| Freeze Chop | Let the chop go: its slices stay as ordinary bank voices and the next chop starts new |
| DCF Cutoff | The voice filter cutoff (CC74), also here so slices can be shaped while chopping |
| Pattern | Choose a rhythmic gate/pattern source |
| Pattern Rate | Raw 0-63 selects free speed in milliseconds per step; raw 64-127 selects a MIDI-clock division |
| Pattern Smooth | Slew between pattern changes, approximately 1-152 ms in the source mapping |

Patterns: Open/No Gate, Eighths, Sixteenth Pulse, Quarters, 3-3-2, Offbeats, Trance, Gallop, Half Bar, Stutter End, Syncopated, Build, Sparse, Broken, Ramp Up and Ramp Down.

Pattern is a rhythmic sequence of steps that can trigger or modulate sound; select a pattern, set its rate (free milliseconds per step or a MIDI-clock division), and route it where wanted in the Mod Matrix. Pattern Rate uses raw 0-63 for free speed and raw 64-127 for MIDI-clock divisions: 1/32, 1/16 triplet, 1/16, 1/8 triplet, 1/8, 1/4 triplet, 1/4 or 1/2.

The pattern signal can feed the modulation matrix; selecting a pattern alone is not a guarantee of an audible amplitude gate without the relevant route. MIDI-clock timing requires clock to reach the FZ.

The browser confirms destructive actions and rearms slice creation before repeating it. Samples and voices need enough available memory and valid bounds. A normalised sample is not recovered merely by lowering the volume afterwards.

## 18. Slices

Slices edits the result of the last chop.

| Function | Meaning |
| --- | --- |
| Slice | Choose a slice (follows the slice count) |
| Slice Move | Move the slice's original key: named notes C-1 to B3 |
| Slice Lowest / Highest | The slice's key range, in semitones below / above its original key (0-36) |
| Slice Output | This slice's output (Off or 1-8) |
| Output (Choke) | Every slice's output, as on Chop / Pattern |
| Filter / Env / LFO1 | Shared: filter, envelope and LFO 1 edits go to every slice. Per Slice: to the slice chosen with Slice |
| Loop Mode | The slices' loop mode |
| Copy Voice | Copy the edit voice into the first empty voice, sharing its sample memory; the copy becomes the edit voice |

Slices stay on one MIDI channel. A shared sample is protected: Delete Unused is refused on it, and recording into a copy gives it new memory.

## 19. FX

Choose the effect before editing its context-dependent controls. The FZED browser editor changes labels and MIDI bindings with the selected effect. Because there is no device readback, select the effect explicitly if it has been changed outside the editor.

Common controls are effect selection, resolution/crush, frequency reduction, two effect-specific controls, wet mix, live enable, supplementary ring/filter controls and render. Some controls are unused or render-only for certain algorithms. Live effects are constrained sample-memory processing, not a modern unlimited streaming plug-in rack.

Delete Unused and Normalise are separate FX-page commands, not parameters of the selected effect. They change sample data. Each command can be used from its on-screen button or learned to a CC; learned command triggers require the separate MIDI actions confirmation described above.

### Live FX And Sample Rate

**Live FX may not work reliably on samples above 9 kHz.** Treat 9 kHz and 4.5 kHz as the practical starting points for live processing, not a guarantee that every effect or workload will succeed. At 18 kHz or 36 kHz the processing may not keep up or may have no useful audible result.

**Short samples may still work at higher sampling rates.** Sample length as well as rate matters, so the warning is not an absolute ban above 9 kHz. A short sample working does not prove that a longer file at the same rate will work. Test the actual sample and algorithm before relying on them live.

**Render is more reliable than Live FX, but it is destructive.** It processes the sample rather than depending on the live processing workload keeping up. When Live FX is ineffective or unreliable, use Render on a saved copy and audition the processed result. Rendering does not offer guaranteed undo, so keep an untouched sample or disk backup. More reliable does not mean every algorithm or setting is guaranteed to succeed.

| Effect | Purpose and principal controls |
| --- | --- |
| TapeHack | Coloured nonlinear sample processing; input drive and output level |
| Wavefolder | Fold the waveform for added harmonics; fold drive and output |
| Xover Fuzz | Crossover dead-zone/fuzz character; threshold and crossover-to-fuzz blend. At the crossover end the threshold is a dead zone, so material quieter than it drops out; at the fuzz end it is the clip point, so a lower threshold gives more fuzz and quiet material is never silenced |
| Rectifier | Partial/full half- or full-wave rectification; rectify and DC trim |
| Decimator | Sample-and-hold style coarsening; hold in sample words; second effect control unused |
| Linear Crush | Reduce effective amplitude resolution; bits control; frequency reduction (DeFreq) works live and on render; two effect controls unused |
| Bit Mangle | XOR masks applied to high and low sample bits; intentionally abrupt/digital results |
| Echo / Comb | Delayed/reflected sample combination; delay in words, signed gain; one echo or three reflections |
| Position | Reorder sample windows; reverse, stutter or scramble, plus window size |
| Ring Mod | Multiply by a modulation waveform; ring frequency and sine/square shape |
| Tube2 | Nonlinear saturation character; pad and tube amount (Amount has most effect at lower Pad settings, about 30-60%: higher Pad drives more of the signal into Tube2's output clamp, which sounds the same whatever the Amount); the slew stage, which adds bite on fast-moving, bright material, is render-only, so Tube2 live is a little smoother than its render |
| Karplus-Strong | Resonant/feedback processing; KS note and feedback |
| Filter | Software effect filter, separate from the FZ DCF; cutoff, resonance, low/band/high-pass type and filter mix |
| TapeHack > Pockey2 | Combined processing chain; render-only live setting |
| Pockey2 | Resolution/frequency-reduction character; render-only live setting; two effect controls unused |

### Remaining FX Controls

| Function | Meaning |
| --- | --- |
| Bits / DeRez / Crush | Effective bit resolution; the scale depends on algorithm |
| DeFreq | Hold/reduce sample changes; its displayed effective rate depends on the locally known sample-rate setting |
| Tape Input / Output | Drive and output gains for applicable algorithms; extreme drive can clip strongly |
| Dry/Wet Mix | Balance/control for the effect result, with algorithm-specific behaviour |
| Live FX | Enable incremental processing where supported; may not work above 9 kHz, although short samples may work; unavailable for render-only modes |
| Ring Frequency / Shape | Supplementary ring controls; on Ring and KS, the effect-specific controls also use the corresponding CC94/95 bindings |
| Render | More reliable than Live FX, but destructively processes the sample; save an untouched copy first |

Echo delay and window sizes are shown in **sample words**, not universal milliseconds. Their audible timing changes with sample rate and pitch. KS feedback and resonant/comb settings can be loud or persistent. Start with low mix and conservative feedback; protect your monitoring level.

Changing a live effect or rendering can alter sample memory. There is no promised non-destructive undo or unlimited CPU headroom. The current engine may not respond like a high-rate modern effects unit, particularly while multiple modulation routes are active.

## 20. Bank Builder

Bank Builder gathers the controls for building a bank of sounds without leaving the optional software, in the order you use them.

| Function | Meaning |
| --- | --- |
| Voice Pick | Preview a voice (the FZ shows it); Voice Select makes it the edit voice |
| New Voice | Move editing to the first empty voice, so voices already in a bank are kept |
| Copy Voice | Copy the edit voice into the first empty voice (sharing its sample memory) |
| Bank Select | Voice mode, or play bank 1-8. The bank chosen is also the target for adds |
| Bank Add / Clear | Add This Voice: put the edit voice in the target bank on the editor's MIDI channel, with its own key range. Clear This MIDI Channel: remove that channel's place |
| Chop Into / Freeze Chop | As on Chop / Pattern: chops into the target bank, and letting a chop go |

### Build Sequence

1. **Choose the target bank (optional).** Bank Select plays a bank and makes it the target. Return it to Voice Mode before recording or editing. With no bank chosen, adds go to a bank named FZED BANK, created in the first empty bank if needed.
2. **Set the MIDI channel.** CH in the top bar is the channel the voice is added on. One voice per channel: adding again on that channel replaces its place.
3. **Make a sound.** New Voice, then record, load a preset wave or chop. Or Copy Voice, or Voice Pick and Voice Select for an existing voice.
4. **Shape it** on the other pages.
5. **Add it** with Add This Voice.
6. **Chops into the bank:** Chop Into Target Bank, chop, then Freeze Chop before the next one.
7. **Repeat** with another channel and New Voice.
8. **Play and keep it.** Bank Select plays the bank. Leave with Exit FZED: Keep All keeps every edit, bank voices included.

Recording, New Voice and capture are refused while a bank is playing. A bank holds 64 places.

## 21. User Presets And Saving

The editor keeps a preset bank in the same format as `USER_FZ.BIN`: 100 slots. It starts with the supplied 26 whole-voice presets (INIT, modulation examples, effects, echo / position and pattern examples) and 21 page presets: seven stretches, five patterns, six effects and three LFO 1 settings. These are **parameter presets**, not samples or complete FZ voice dumps.

**Page presets.** Every editing page has a Presets bar: the presets that hold only that page's settings (a pattern preset may bring its matrix route), with Open, Send and **Save as preset…**. A page preset changes only its own page's settings, so it layers onto the current sound.

**Saving.** Save as preset asks for a name (12 characters, shown in capitals), a slot and what to save: this page only, the pattern only (on Chop / Pattern), or the whole voice (every page). Only settings that have a value in the editor are saved. Commands are never stored: record, render, chop, bank actions and preset wave replacement.

| Operation | Meaning |
| --- | --- |
| Open | Apply a preset to the editor's controls only; nothing is sent (use Send to put it on the FZ). Output stays enabled, so the next control you move goes to the FZ on its own |
| Send | Confirm, then replay the settings to the current voice (the matrix is cleared first when the preset asks for it) |
| Save as preset… | Store the editor's settings in a slot |
| Rename / Delete | Change a slot's name, or empty it |
| Open USER_FZ.BIN | Read another compatible bank; nothing is sent |
| Download USER_FZ.BIN | Save the editor's bank as a file, to keep, move to another browser or share |
| Bundled bank / New empty bank | Go back to the supplied bank, or start from 100 empty slots |
| Save Settings | Save edited values and Learn assignments as JSON (a different format) |

The editor's bank lives in this browser until you download it; changing it does not change a file until then. **Stretch settings** are stored in a part of each slot that older banks do not have; a preset without them simply leaves stretch as it is. BIN replay never sends wave replacement, recording, voice INIT, bank routing, chop, normalise or render. Parameter 120, which clears the current voice's matrix, is kept and sent first.

**User preset INIT** resets FZED additions such as matrix routes, LFO2 and effects; it intentionally does not reset all the sample's envelopes, filter or bounds. **Voice INIT** is a separate explicit voice-initialisation command. **Startup Init/Retain** is another decision on the FZ itself. These three operations are not interchangeable.

Use the FZ's Enter/ESC workflow to accept and leave the FZED optional software as appropriate, then verify the voice in the normal OS and save it normally. Browser JSON does not preserve sample audio. Additional FZED facilities such as LFO2/matrix/live-engine state are not ordinary FZ voice fields and should not be assumed to survive as part of a stock voice file. Save the FZED browser editor's settings separately.

## 22. Three Practical Starting Points

### Playable Looped Instrument

1. Load a voice that sounds reliably, then retain it at startup.
2. Establish its root key and a sensible range. Confirm the loop sounds before adding modulation.
3. Use ADSR for an immediate attack, audible sustain and finite release.
4. Choose one modulation route, for example wheel to cutoff, or use the wheel's LFO-filter assignment.
5. Test note-on and note-off from both the FZ keyboard and your external keyboard before adding more routes.

### Lower-Rate Texture For Resampling

1. Keep a backup of the original sample.
2. Explore playback rate, pitch/bend, loop mode and crossfade on a known-working voice.
3. Add one effect with a low mix before increasing its drive or feedback.
4. Above 9 kHz, do not rely on Live FX without testing the actual sample. Short samples may work; otherwise use the more reliable, destructive Render on a backup copy.
5. Record the FZ audio output into your other sampler. The browser does not record that audio.

### Repeating Capture Texture

1. Stop ordinary recording; begin with a conservative monitor level.
2. On Capture choose a moderate length such as 500 ms, free sync and a short fixed hold.
3. Enter capture explicitly and verify the record/play cycle before shortening it.
4. On that same page add intervals, stagger and a finite fade. Check the voice's key range.
5. Leave capture explicitly before trying ordinary chop, preset waves or render.

## 23. Troubleshooting And Limits

| Symptom | Check |
| --- | --- |
| Nothing reacts | Correct software running, output enabled, port/channel selected, pickup waiting, or command refused in capture |
| Browser shows a value but sound differs | Local value is not readback; voice may have clamped a bound or another controller changed it |
| Note missing at certain velocities/keys | Key range, velocity sensitivity, envelope level, generator use and chord transposition |
| Note sustains after release | Sustain pedal, envelope sustain/end/target settings, feedback effects and note routing; do not assume note-off velocity is the cause |
| Browser note sticks after changing ports | Use Panic; note ownership/release is tracked at the original endpoint, but disconnected hardware cannot receive a release |
| One-shot still loops | Turn Loop Mode once more; the current software keeps one-shot through end and loop moves |
| Stretch starts with silence | The first segments may be the silent start of the sample: trim the start, or use a shorter hold |
| Capture timing is longer than requested | Record polling/service-loop overhead and allocation; short takes are not exact hardware timers |
| Capture sync waits | Incoming clock/transport absent or not forwarded |
| FX/wave/loop changes refused | Many are intentionally blocked during capture |
| Live FX ineffective above 9 kHz | Try a shorter sample or a lower rate; short high-rate samples may work. Render is more reliable, but destructive: use a saved copy |
| Need to recover a valuable sample | Reload a backup; processing and recording do not provide guaranteed undo |

Do not treat successful menu or MIDI tests as proof of an audible hardware result. For a new sound path, use one change at a time, a known-good sounding voice, and a verified clean exit. Keep a known-working FZED optional-software disk and backups of your samples available as a fallback.

## Appendix A: MIDI CC Reference

Every FZED control, page by page in menu order and, within a page, in the order the editor shows it. All messages go on the FZ's MIDI channel. The **Message** column uses three forms:

- **CCn**: an ordinary MIDI control change n carrying the value.
- **Pn**: FZ parameter n. Send CC10 = n, then CC11 = the value. Further CC11 messages keep editing parameter n until another CC10 arrives.
- **FZED k**: FZED's own control k. Send CC10 = 88, CC11 = k, then CC10 = 89, CC11 = the value.

The **Values** column gives the value FZED receives and what it means. Where a range is shown for each setting, any value in the range selects it; the editor sends the middle of the range. A few CCs mean different things on different pages: CC96, 97 and 99 are Chop controls until capture is on, then chord controls; CC102-110 are Record controls until capture is on, then capture controls; CC113-116 and CC94/95 follow the effect chosen with CC112. Commands (Make Slices, Render, Record Start and similar) act when their value enters the command range and must return to the re-arm range before they act again.

### A.1 Filter / Keys

| Control | Message | Values |
| --- | --- | --- |
| DCF Cutoff | CC74 | 0-127 |
| DCQ Resonance | CC75 | 0-127 |
| Tape Speed | CC71 | 36K 0-31; 18K 32-63; 9K 64-95; 4.5K 96-127 |
| Original Key | CC68 | 36-96 (C2 to C7) |
| Lowest Key | CC67 | 36-96 (C2 to C7) |
| Highest Key | CC66 | 36-96 (C2 to C7) |

### A.2 ADSR

| Control | Message | Values |
| --- | --- | --- |
| DCA Attack | CC78 | 0-127 |
| DCA Decay | CC79 | 0-127 |
| DCA Sustain Level | CC80 | 0-127 |
| DCA Release | CC81 | 0-127 |
| Vel > Amp Level | P62 | 0-127 (-128 to +126) |
| DCF Attack | CC82 | 0-127 |
| DCF Decay | CC83 | 0-127 |
| DCF Sustain Level | CC84 | 0-127 |
| DCF Release | CC85 | 0-127 |
| Vel > Filter Level | P64 | 0-127 (-128 to +126) |

### A.3 Envelope stages

| Control | Message | Values |
| --- | --- | --- |
| Amp Rate Step 1-8 | P14-P21 (step n = P13+n) | 0-127 (RATE 000 to RATE 127) |
| Amp Level Step 1-8 | P22-P29 (step n = P21+n) | 0-127 (LEVEL 000 to LEVEL 254) |
| Amp Sustain Step | CC12 | STEP 1 0; STEP 2 1; STEP 3 2; STEP 4 3; STEP 5 4; STEP 6 5; STEP 7 6; STEP 8 7 |
| Amp End Step | CC13 | STEP 1 0; STEP 2 1; STEP 3 2; STEP 4 3; STEP 5 4; STEP 6 5; STEP 7 6; STEP 8 7 |
| Filter Rate Step 1-8 | P32-P39 (step n = P31+n) | 0-127 (RATE 000 to RATE 127) |
| Filter Level Step 1-8 | P40-P47 (step n = P39+n) | 0-127 (LEVEL 000 to LEVEL 254) |
| Filter Sustain Step | CC30 | STEP 1 0; STEP 2 1; STEP 3 2; STEP 4 3; STEP 5 4; STEP 6 5; STEP 7 6; STEP 8 7 |
| Filter End Step | CC31 | STEP 1 0; STEP 2 1; STEP 3 2; STEP 4 3; STEP 5 4; STEP 6 5; STEP 7 6; STEP 8 7 |

### A.4 LFO 1

| Control | Message | Values |
| --- | --- | --- |
| LFO Rate | CC73 | 0-127 |
| LFO Waveform | CC50 | SIN 0; SAW UP 1; SAW DWN 2; TRI 3; SQR 4; RND 5 |
| LFO1 Delay | P0 | 0-127 (0.00 S to 10.75 S) |
| LFO Attack | CC51 | 0-127 |
| LFO Pitch Depth | CC53 | 0-127 |
| LFO Amp Depth | CC54 | 0-127 |
| LFO Filter Depth | CC55 | 0-127 |
| LFO Res Depth | CC56 | 0-127 |

### A.5 LFO 2

| Control | Message | Values |
| --- | --- | --- |
| LFO2 Rate Div | CC89 | 0-127 (RATE/DIV 000 to RATE/DIV 127) |
| LFO2 Shape | CC91 | TRIANGLE 0-15; SINE 16-31; SAW UP 32-47; SAW DOWN 48-63; SQUARE 64-79; RANDOM S&H 80-95; ONE-SHOT RAMP 96-111; WARBLE 112-127 |
| LFO2 Delay | P1 | 0-127 (0.00 S to 9.95 S) |
| LFO2 Fade-in | P2 | 0-127 (0.00 S to 9.95 S) |
| LFO2 Mode | CC93 | FREE 0-42; RETRIGGER 43-85; MIDI CLOCK 86-127 |
| LFO2 Dest | CC92 | OFF 0-15; FILTER CUTOFF 16-31; PITCH +/-2 ST 32-47; LFO>PITCH 48-63; LFO>AMP 64-79; LFO>FILTER 80-95; TREMOLO 96-111; BEND (CUE SCRUB) 112-127 |
| LFO2 Depth | CC90 | 0-127 |
| LFO2 Dest 2 | P99 = 32, then P119 | OFF 0-7; CUTOFF 8-15; RESONANCE 16-23; LEVEL 24-31; PITCH 32-39; LFO1 > PITCH 40-47; LFO1 > AMP 48-55; LFO1 > FILTER 56-63; SAMPLE START 64-71; LOOP WINDOW 72-79; LOOP ST/CAP LEN 80-87; LOOP END/CAP RATE 88-95; LFO2 RATE 96-103; LFO2 DEPTH 104-111; FX MIX/RESO 112-119; FX PARAM/CUT 120-127 |
| LFO2 Depth 2 | P109 | 0-127 (-064 to +063) |

### A.6 Key / Velocity

| Control | Message | Values |
| --- | --- | --- |
| Vel > Amp Level | P62 | 0-127 (-128 to +126) |
| Vel > Amp Rate | P63 | 0-127 (-128 to +126) |
| Vel > Filter Level | P64 | 0-127 (-128 to +126) |
| Vel > Filter Rate | P65 | 0-127 (-128 to +126) |
| Vel > Res | P57 | 0-127 (VALUE 000 to VALUE 127) |
| Amp Key Follow | P58 | 0-127 (-128 to +126) |
| Amp Rate Scale | P59 | 0-127 (-128 to +126) |
| Filter Key Follow | P60 | 0-127 (-128 to +126) |
| Filter Rate Scale | P61 | 0-127 (-128 to +126) |

### A.7 Controllers

| Control | Message | Values |
| --- | --- | --- |
| LFO Pitch | P66 mod wheel, P73 foot, P80 aftertouch | 0-127 (DEPTH 000 to DEPTH 127) |
| LFO Amp | P67 mod wheel, P74 foot, P81 aftertouch | 0-127 (DEPTH 000 to DEPTH 127) |
| LFO Filter | P68 mod wheel, P75 foot, P82 aftertouch | 0-127 (DEPTH 000 to DEPTH 127) |
| LFO Res | P69 mod wheel, P76 foot, P83 aftertouch | 0-127 (DEPTH 000 to DEPTH 127) |
| Glide Time | P5 | 0-127 (VALUE 000 to VALUE 127) |
| Voice Init | P7 | REARM 0-63; INACTIVE 64-119; INIT VOICE 120-127 |
| Amp Offset | P70 mod wheel, P77 foot, P84 aftertouch | 0-127 (DEPTH 000 to DEPTH 127) |
| Filter Offset | P71 mod wheel, P78 foot, P85 aftertouch | 0-127 (DEPTH 000 to DEPTH 127) |
| Res Offset | P72 mod wheel, P79 foot, P86 aftertouch | 0-127 (DEPTH 000 to DEPTH 127) |
| Glide Mode | P6 | GLIDE OFF 0-42; LEGATO 43-85; ALWAYS 86-127 |

### A.8 Mod matrix

| Control | Message | Values |
| --- | --- | --- |
| Route 1-10 Source | P90-P99 (route n = P89+n) | OFF 0-7, 112-127; VELOCITY 8-15; AFTERTOUCH 16-23; MOD WHEEL 24-31; LFO 2 32-39; LFO 2 UNIPOLAR 40-47; RANDOM 48-55; KEY 56-63; PITCH BEND 64-71; CC2 BREATH 72-79; CC3 80-87; CC4 FOOT 88-95; PATTERN 96-103; PATTERN + 104-111 |
| Route 1-10 Destination | P110-P119 (route n = P109+n) | OFF 0-7; CUTOFF 8-15; RESONANCE 16-23; LEVEL 24-31; PITCH 32-39; LFO1 > PITCH 40-47; LFO1 > AMP 48-55; LFO1 > FILTER 56-63; SAMPLE START 64-71; LOOP WINDOW 72-79; LOOP ST/CAP LEN 80-87; LOOP END/CAP RATE 88-95; LFO2 RATE 96-103; LFO2 DEPTH 104-111; FX MIX/RESO 112-119; FX PARAM/CUT 120-127 |
| Route 1-10 Amount | P100-P109 (route n = P99+n) | 0-127 (-064 to +063) |

### A.9 Play / Loop

| Control | Message | Values |
| --- | --- | --- |
| Sample Start | CC76 | 0-127 |
| Sample End | CC77 | 0-127 |
| Play Mode | CC70 | ORIGINAL 0-31; REVERSE 32-63; CUE 64-127 |
| Window Position | P4 | 0-127 (POSITION 000 to POSITION 127) |
| Window Snap | P3 | FREE 0-42; ZERO-CROSS 43-85; WHOLE FRAMES 86-127 |
| Loop Mode | CC86 | ONE-SHOT 0-42; ORIGINAL 43-84; LOOP 85-127 |
| Loop Start | CC87 | 0-127 |
| Loop End | CC88 | 0-127 |
| Loop Crossfade | CC72 | 0-127 |
| Preset Wave | CC111 | OFF 0-7; SAW 8-15; SQUARE 16-23; PULSE 25% 24-31; PULSE 12% 32-39; TRIANGLE 40-47; SINE 48-55; DOUBLE SINE 56-63 |

### A.10 Stretch

| Control | Message | Values |
| --- | --- | --- |
| Segments | FZED 0 | 2 SEGMENTS 0-18; 3 SEGMENTS 19-36; 4 SEGMENTS 37-54; 5 SEGMENTS 55-73; 6 SEGMENTS 74-91; 7 SEGMENTS 92-109; 8 SEGMENTS 110-127 |
| Stretch (time) | FZED 1 | 0-127 (HOLD 0.02 S to HOLD 19.5 S) |
| Grain | FZED 2 | 0-127 (GRAIN 000% to GRAIN 100%) |
| Crossfade | FZED 3 | 0-127 (XFADE 0000 to XFADE 1000) |
| Snap | FZED 4 | SNAP OFF 0-63; ZERO-CROSS 64-127 |
| Sustain At | FZED 5 | 0-127 in Segments + 1 equal bands: the lowest is NO SUSTAIN, then HOLD SEGMENT 1 to the last segment (at 8 segments: NO SUSTAIN 0-14, HOLD SEGMENT 1 15-28, 2 29-42 ... 8 114-127) |
| Next / Lead-in | FZED 16 | TRACE 0-31; TRACE, CUT LEAD-IN 32-63; SKIP 64-95; SKIP, CUT LEAD-IN 96-127 |
| Order | FZED 17 | FORWARD 0-31; REVERSE 32-63; THERE + BACK 64-95; SHUFFLE 01 96-99; SHUFFLE 02 100-103; SHUFFLE 03 104-107; SHUFFLE 04 108-111; SHUFFLE 05 112-115; SHUFFLE 06 116-119; SHUFFLE 07 120-123; SHUFFLE 08 124-127 |
| Skew | FZED 18 | 0-127 (FIRST LONGER 100% to LAST LONGER 98%) |
| Stretch ON/OFF | FZED 9 | OFF (OWN LOOPS) 0-63; STRETCH ON 64-127 |

### A.11 Record

| Control | Message | Values |
| --- | --- | --- |
| Record Rate | CC102 | RATE 36K 0-31; RATE 18K 32-63; RATE 9K 64-95; RATE 4.5K 96-127 |
| Record Length | CC103 | 0-127 (0.1 S to 12.8 S at 36K; 2x at 18K, 4x at 9K, 8x at 4.5K) |
| Input Gain | CC104 | GAIN 0 DB 0-63; GAIN -20 DB 64-127 |
| Auto Trig Level | CC105 | 0-127 (LEVEL 000 to LEVEL 254) |
| Norm Filter | CC110 | OFF 0-63; ON 18K CUT 64-79; ON 9K CUT 80-95; ON 4.5K CUT 96-111; ON RATE CUT 112-127 |
| Record Arm | CC106 | INACTIVE 0-63; TRIGGER 64-127 |
| Record Start | CC107 | INACTIVE 0-63; TRIGGER 64-127 |
| Record Auto | CC108 | INACTIVE 0-63; TRIGGER 64-127 |
| Record Stop | CC109 | INACTIVE 0-63; TRIGGER 64-127 |
| Exit FZED | FZED 14, then FZED 13 | FZED 13 = 0-63 leaves as ESC (edits put back). To leave as ENTER, first set FZED 14 to what is kept (0-42 the sound edits, 43-85 all of the edit voice, 86-127 everything, bank voices too), then FZED 13 = 64-127 |

### A.12 Capture

| Control | Message | Values |
| --- | --- | --- |
| Capture ON/OFF | FZED 7 to enter, CC108 to leave | FZED 7 = 64-127 enters capture; CC108 = 0-63 leaves it |
| Recapture | CC109 | INACTIVE 0-63; CAPTURE NOW 64-127 |
| Sync | CC33 | FREE 0-15; 1/16 CLOCK 16-31; 1/8 CLOCK 32-47; 1/4 CLOCK 48-63; 1/2 CLOCK 64-79; 1 BAR CLOCK 80-95; 2 BARS CLOCK 96-111; 4 BARS CLOCK 112-127 |
| Capture Rate | CC102 | RATE 36K 0-31; RATE 18K 32-63; RATE 9K 64-95; RATE 4.5K 96-127 |
| Capture Length | CC103 | 10 MS 0-7; 20 MS 8-15; 30 MS 16-23; 50 MS 24-31; 75 MS 32-39; 100 MS 40-47; 150 MS 48-55; 200 MS 56-63; 300 MS 64-71; 500 MS 72-79; 750 MS 80-87; 1.0 S 88-95; 1.5 S 96-103; 2.0 S 104-111; 3.0 S 112-119; 4.0 S 120-127 |
| Input Gain | CC104 | GAIN 0 DB 0-63; GAIN -20 DB 64-127 |
| Hold | CC105 | 1 PASS 0-15; 2 PASSES 16-31; 4 PASSES 32-47; 8 PASSES 48-63; 2 SECONDS 64-79; 4 SECONDS 80-95; 8 SECONDS 96-111; UNTIL RECAPTURE 112-127 |
| Transpose | CC23 | 0-127 (-24 SEMITONES to +24 SEMITONES) |
| Amp+flt Release | CC81 + CC85 (same value) | 0-127 |
| Intervals | CC96 | ORIGINAL ONLY 0-14; OCTAVES +12 -12 15-28; ROOT 5TH OCTAVE 29-42; MAJOR 43-56; MINOR 57-71; MAJOR 7TH 72-85; MINOR 7TH 86-99; 5TH OCT BELOW 100-113; WIDE SPREAD 114-127 |
| Velocity | CC97 | SAME (100) 0-31; RANDOM 32-63; FALLING 64-95; RISING 96-127 |
| Stagger | CC99 | TOGETHER 0-7; 20 MS APART 8-15; 40 MS APART 16-23; 60 MS APART 24-31; 80 MS APART 32-39; 120 MS APART 40-47; 160 MS APART 48-55; 200 MS APART 56-63; 300 MS APART 64-71; 400 MS APART 72-79; 500 MS APART 80-87; 600 MS APART 88-95; 800 MS APART 96-103; 1.2 S APART 104-111; 1.8 S APART 112-119; 2.4 S APART 120-127 |
| Fade | CC34 | OFF (CUT) 0-15; 50 MS FADE 16-31; 100 MS FADE 32-47; 200 MS FADE 48-63; 400 MS FADE 64-79; 800 MS FADE 80-95; 1.2 S FADE 96-111; 1.6 S FADE 112-127 |
| Release | CC41 | TOGETHER 0-63; TOP FIRST 64-127 |

### A.13 Chop / Pattern

| Control | Message | Values |
| --- | --- | --- |
| Chop Sensitivity | CC96 | 0-127 (SENS 000 to SENS 127) |
| Chop Mode Snap | CC97 | EVEN 0-42; EVEN + SNAP 43-85; TRANSIENT 86-127 |
| Chop Slice Count | CC99 | SLICES 004 0-31; SLICES 008 32-63; SLICES 016 64-95; SLICES 032 96-127 |
| Chop Make Play | CC98 | VOICE 0-63; PLAY SLICES 64-119; MAKE SLICES 120-127 |
| Output (choke) | P121 | OFF (OVERLAP) 0-14; OUT 1 (CHOKE) 15-28; OUT 2 (CHOKE) 29-42; OUT 3 (CHOKE) 43-56; OUT 4 (CHOKE) 57-71; OUT 5 (CHOKE) 72-85; OUT 6 (CHOKE) 86-99; OUT 7 (CHOKE) 100-113; OUT 8 (CHOKE) 114-127 |
| Pattern | P8 | OPEN (NO GATE) 0-7; 8THS 8-15; 16TH PULSE 16-23; QUARTERS 24-31; 3-3-2 32-39; OFFBEATS 40-47; TRANCE 48-55; GALLOP 56-63; HALF BAR 64-71; STUTTER END 72-79; SYNCOPATED 80-87; BUILD 88-95; SPARSE 96-103; BROKEN 104-111; RAMP UP 112-119; RAMP DOWN 120-127 |
| Pattern Rate | P9 | 0-127 (FREE 012 MS/STEP to MIDI CLOCK 1/2) |
| Pattern Smooth | P87 | SLEW 001 MS 0-15; SLEW 002 MS 16-31; SLEW 004 MS 32-47; SLEW 010 MS 48-63; SLEW 019 MS 64-79; SLEW 038 MS 80-95; SLEW 076 MS 96-111; SLEW 152 MS 112-127 |
| Chop Into | FZED 6 | OWN BANK 0-63; TARGET BANK 64-127 |
| Freeze Chop | FZED 15 | 64-127 lets go of the current chop; its slices stay in the bank as plain voices |
| DCF Cutoff | CC74 | 0-127 |

### A.14 Slices

| Control | Message | Values |
| --- | --- | --- |
| Slice | P122 | SLICE 01 OF 08 0-15; SLICE 02 OF 08 16-31; SLICE 03 OF 08 32-47; SLICE 04 OF 08 48-63; SLICE 05 OF 08 64-79; SLICE 06 OF 08 80-95; SLICE 07 OF 08 96-111; SLICE 08 OF 08 112-127 |
| Slice Move | P123 | 0-47 (C-1 to B2) |
| Slice Lowest | P124 | 0-36 (-00 SEMITONES to -36 SEMITONES) |
| Slice Highest | P125 | 0-36 (+00 SEMITONES to +36 SEMITONES) |
| Slice Output | P127 | OFF (OVERLAP) 0-14; OUT 1 (CHOKE) 15-28; OUT 2 (CHOKE) 29-42; OUT 3 (CHOKE) 43-56; OUT 4 (CHOKE) 57-71; OUT 5 (CHOKE) 72-85; OUT 6 (CHOKE) 86-99; OUT 7 (CHOKE) 100-113; OUT 8 (CHOKE) 114-127 |
| Output (choke) | P121 | OFF (OVERLAP) 0-14; OUT 1 (CHOKE) 15-28; OUT 2 (CHOKE) 29-42; OUT 3 (CHOKE) 43-56; OUT 4 (CHOKE) 57-71; OUT 5 (CHOKE) 72-85; OUT 6 (CHOKE) 86-99; OUT 7 (CHOKE) 100-113; OUT 8 (CHOKE) 114-127 |
| Filter/Env/LFO1 | FZED 10 | SHARED 0-63; PER SLICE 64-127 |
| Loop Mode | CC86 | ONE-SHOT 0-42; ORIGINAL 43-84; LOOP 85-127 |
| Copy Voice | P126 | REARM 0-63; WAIT 64-119; COPY VOICE 120-127 |

### A.15 FX

| Control | Message | Values |
| --- | --- | --- |
| FX Type | CC112 | TAPEHACK 0-8; WAVEFOLDER 9-17; XOVER FUZZ 18-25; RECTIFIER 26-34; DECIMATOR 35-42; LINEAR CRUSH 43-51; BIT MANGLE 52-59; ECHO / COMB 60-68; POSITION 69-76; RING MOD 77-85; TUBE2 86-93; KARPLUS-STRONG 94-102; FILTER 103-110; TAPEHACK > POCKEY2 111-119; POCKEY2 120-127 |
| Dry/Wet Mix | CC117 | 0-127 (WET 000% to WET 100%) |
| Live FX | CC119 | LIVE OFF 0-63; LIVE ON 64-127 |
| Render | CC118 | REARM 0-63; INACTIVE 64-119; RENDER 120-127 |
| Delete Unused (button) | CC100 | REARM 0-63; INACTIVE 64-119; DELETE UNUSED 120-127 |
| Normalise (button) | CC101 | REARM 0-63; INACTIVE 64-119; NORMALISE 120-127 |

Effect parameters, by effect (in FX Type order):

| Effect | Control | Message | Values |
| --- | --- | --- | --- |
| Tapehack | Tape Input | CC115 | 0-127 (-INF DB to +20.0 DB) |
| Tapehack | Tape Output | CC116 | 0-127 (-INF DB to -0.7 DB) |
| Wavefolder | Fold Drive | CC115 | 0-127 (-INF DB to +20.0 DB) |
| Wavefolder | Fold Output | CC116 | 0-127 (-INF DB to -0.7 DB) |
| Xover Fuzz | Xover Threshold | CC115 | 0-127 (THRESHOLD 000% to THRESHOLD 098%) |
| Xover Fuzz | Xover > Fuzz | CC116 | 0-127 (CROSSOVER to FUZZ) |
| Rectifier | Rectify | CC115 | OFF 0-3; PART HALF-WAVE 4-59; HALF-WAVE 60-67; PART FULL-WAVE 68-123; FULL-WAVE 124-127 |
| Rectifier | DC Trim | CC116 | 0-127 (100% TRIM to 000% TRIM) |
| Decimator | Hold | CC115 | 0-127 (HOLD 001 WORDS to HOLD 064 WORDS) |
| Linear Crush | Bits Derez Crush | CC113 | 2 BITS 0-33; 3 BITS 34-48; 4 BITS 49-58; 5 BITS 59-67; 6 BITS 68-75; 7 BITS 76-83; 8 BITS 84-89; 9 BITS 90-96; 10 BITS 97-101; 11 BITS 102-107; 12 BITS 108-112; 13 BITS 113-117; 14 BITS 118-122; 15 BITS 123-126; 16 BITS 127 |
| Linear Crush | Defreq | CC114 | 0-127 (DEFREQ CC 000 to DEFREQ CC 127) |
| Bit Mangle | Mangle High Bits | CC115 | 0-127 (XOR 0000 to XOR FE00) |
| Bit Mangle | Mangle Low Bits | CC116 | 0-127 (XOR 0000 to XOR 01FC) |
| Echo / Comb | Echo Taps | CC114 | ONE ECHO 0-63; 3 REFLECTIONS 64-127 |
| Echo / Comb | Echo Delay | CC115 | 0-127 (DELAY 001 WORDS to DELAY 8002 WORDS) |
| Echo / Comb | Echo Gain | CC116 | 0-127 (-100% to +100%) |
| Position | Position Type | CC115 | REVERSE 0-42; STUTTER 43-85; SCRAMBLE 86-127 |
| Position | Window | CC116 | 0-127 (WINDOW 016 WORDS to WINDOW 3968 WORDS) |
| Ring Mod | Ring Frequency | CC94 | 0-127 (RING CC 000 to RING CC 127) |
| Ring Mod | Ring Shape | CC95 | SINE 0-63; SQUARE 64-127 |
| Tube2 | Tube Pad | CC115 | 0-127 (000% to 100%; 127 = no pad) |
| Tube2 | Tube Amount | CC116 | 0-127 (000% to 100%) |
| Karplus-strong | KS Note | CC94 | 0-127 (C-1 to G9) |
| Karplus-strong | KS Feedback | CC95 | 0-127 (000% FEEDBACK to 100% FEEDBACK) |
| Filter | Filter Type | CC94 | LOW-PASS 0-42; BAND-PASS 43-85; HIGH-PASS 86-127 |
| Filter | Cutoff | CC115 | 0-127 (CUTOFF 000 to CUTOFF 127) |
| Filter | Resonance | CC116 | 0-127 (RESONANCE 000 to RESONANCE 127) |
| Tapehack > Pockey2 | Bits Derez Crush | CC113 | 4 BITS 0-9; 5 BITS 10-19; 6 BITS 20-29; 7 BITS 30-39; 8 BITS 40-49; 9 BITS 50-59; 10 BITS 60-68; 11 BITS 69-78; 12 BITS 79-88; 13 BITS 89-98; 14 BITS 99-108; 15 BITS 109-118; 16 BITS 119-127 |
| Tapehack > Pockey2 | Defreq | CC114 | 0-127 (DEFREQ CC 000 to DEFREQ CC 127) |
| Tapehack > Pockey2 | Tape Input | CC115 | 0-127 (-INF DB to +20.0 DB) |
| Tapehack > Pockey2 | Tape Output | CC116 | 0-127 (-INF DB to -0.7 DB) |
| Pockey2 | Bits Derez Crush | CC113 | 4 BITS 0-9; 5 BITS 10-19; 6 BITS 20-29; 7 BITS 30-39; 8 BITS 40-49; 9 BITS 50-59; 10 BITS 60-68; 11 BITS 69-78; 12 BITS 79-88; 13 BITS 89-98; 14 BITS 99-108; 15 BITS 109-118; 16 BITS 119-127 |
| Pockey2 | Defreq | CC114 | 0-127 (DEFREQ CC 000 to DEFREQ CC 127) |

### A.16 Bank builder

| Control | Message | Values |
| --- | --- | --- |
| Voice Pick | FZED 11 | 0-127, spread over the voices that have sound; the picked voice shows on line 2 |
| Voice Select | FZED 12 | 64-127 selects the picked voice (voice mode only) |
| New Voice | CC16 | REARM 0-63; WAIT 64-119; NEW VOICE 120-127 |
| Copy Voice | P126 | REARM 0-63; WAIT 64-119; COPY VOICE 120-127 |
| Bank Select | CC14 | VOICE MODE 0-14; PLAY BANK 1 15-28; PLAY BANK 2 29-42; PLAY BANK 3 43-56; PLAY BANK 4 57-71; PLAY BANK 5 72-85; PLAY BANK 6 86-99; PLAY BANK 7 100-113; PLAY BANK 8 114-127 |
| Bank Add/Clear | CC15 | ADD THIS VOICE 0-31; REARM 32-95; CLEAR CHANNEL 96-127 |
| Chop Into | FZED 6 | OWN BANK 0-63; TARGET BANK 64-127 |
| Freeze Chop | FZED 15 | 64-127 lets go of the current chop; its slices stay in the bank as plain voices |

## Appendix B: What Changes Live

**Live** means a note that is already sounding changes as you move the control. **Next note** means the setting is stored straight away, but you hear it from the next note you play; a held note keeps what it started with. Commands act at once when triggered.

| Page | Live | Next note | Notes |
| --- | --- | --- | --- |
| Filter / Keys | DCF Cutoff, DCQ Resonance, Tape Speed | Original Key, Lowest Key, Highest Key | Tape Speed shifts held notes by octaves |
| ADSR | DCA and DCF Attack, Decay, Sustain Level, Release | Vel > Amp Level, Vel > Flt Level | A rate change is heard while that stage is still running; once a stage has finished there is nothing left to change |
| Envelope Stages | Amp and Flt Rate and Level for every step, Sustain Step, End Step | | Held notes that haven't been released re-enter their sustain step |
| LFO 1 | Rate, Waveform, Attack, Pitch, Amp, Filter and Res Depth | LFO1 Delay | The delay is counted from the start of each note |
| LFO 2 | Rate / Division, Shape, Mode, Destination, Depth, Destination 2, Depth 2 | Delay, Fade-In | Delay and fade-in start again with each note (or each retrigger) |
| Key / Velocity | | Every control | Velocity, key follow and rate scaling are worked out when a note starts |
| Controllers | | | Mod wheel, foot and aftertouch depths and the Amp, Filter and Res offsets take effect the next time that wheel, pedal or aftertouch moves. Glide Time and Glide Mode apply to the next glide |
| Mod Matrix | Every source, destination and amount | | |
| Play / Loop | Sample End, Loop Start, Loop End, Loop Crossfade, Window Position | Sample Start, Play Mode, Loop Mode | Window Snap applies to later window moves. Preset Wave is a command: it replaces the sample |
| Stretch | | Every setting, and Stretch On/Off | A stretch is a set of loops, and like any loop-mode change it is heard from the next note |
| Record | | Rate, Length, Input Gain, Auto Trig Level, Norm Filter | They apply to the next recording. Arm, Start, Auto and Stop are commands |
| Capture | Amp+Flt Release | Rate, Length, Input Gain, Hold, Transpose, Sync, the chord settings and Fade | Capture settings apply to the next take. Capture On/Off and Recapture are commands |
| Chop / Pattern | Pattern, Pattern Rate, Pattern Smooth, DCF Cutoff | Output (Choke) | Sensitivity, Mode/Snap and Slice Count apply when you next make slices. Make / Play, Chop Into and Freeze Chop are commands |
| Slices | | Slice Move, Lowest, Highest, Output, Loop Mode | Slice chooses which slice the other controls edit; Filter/Env/LFO1 chooses where those edits go. Copy Voice is a command |
| FX | Every effect setting, while Live FX is on | | With Live FX off, the settings are used when you Render. Render, Normalise and Delete Unused are commands that change the sample |
| Bank Builder | | | Voice Pick, Voice Select, New Voice and Bank Add/Clear are commands; bank selection changes what the next note plays |

## Software And Data

**FZED optional software** runs on the FZ hardware and performs the sound, editing, modulation and capture operations. **The FZED browser editor** runs on the computer and sends MIDI instructions to it. Both parts are needed for the browser controls to operate the hardware as described.

The optional-software disk, audio samples, FZ voice files, browser settings JSON and USER_FZ.BIN preset bank are different resources. A browser settings file is not a replacement for a saved sample or voice. Keep separate backups of the sounds and the settings needed to recreate them.

## Credits And Licence

### Airwindows

FZED's Airwindows-derived effects processing, including the adapted Pockey2 and Tube2 algorithms, credits **Chris Johnson / Airwindows**. The FZED optional software adapts that processing for the Casio hardware; these are not unmodified desktop plug-ins, and identical output is not guaranteed. The FZED browser editor controls the hardware over MIDI and does not run these audio algorithms itself.

Airwindows publishes its code under the **MIT License**. The repository licence is copyright (c) 2018 Chris Johnson. The Pockey2 and Tube2 processing files additionally state: **Copyright (c) 2016 airwindows, Airwindows uses the MIT license**. Both attributions are retained here. This is not an official Airwindows release and does not imply endorsement.

Sources: [Airwindows licence](https://github.com/airwindows/airwindows/blob/master/LICENSE), [Pockey2 source](https://github.com/airwindows/airwindows/blob/master/plugins/WinVST/Pockey2/Pockey2Proc.cpp), [Tube2 source](https://github.com/airwindows/airwindows/blob/master/plugins/WinVST/Tube2/Tube2Proc.cpp).

The complete upstream repository licence follows. It is also supplied as `LICENSE_AIRWINDOWS.txt`. Its copyright and permission notice must accompany copies or substantial portions of the Airwindows-derived software. This notice applies to those portions; it does not declare all unrelated FZED code to be MIT-licensed.

```text
MIT License

Copyright (c) 2018 Chris Johnson

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```
