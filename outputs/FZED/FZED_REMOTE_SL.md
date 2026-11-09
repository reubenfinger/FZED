# FZED templates for the Novation ReMOTE SL

FZED has three linked templates for the Novation ReMOTE SL (MkI): **FZED 1 SOUND**, **FZED 2 MOD** and **FZED 3 SAMPLE**. They put most of PERF on the SL's encoders, pots, sliders and buttons, with PERF's names on the SL's screens. FZED does the rest: it turns the SL's messages into what PERF expects and follows each move on screen. The SL needs FZED running.

**Setting up.**

1. Send `FZED_SL_1_SOUND.syx`, `FZED_SL_2_MOD.syx` and `FZED_SL_3_SAMPLE.syx` to the SL with a SysEx tool (for example SysEx Librarian on a Mac). Each arrives in the SL's temporary memory ("Template Dump Received").
2. After each one, press WRITE and save it. Use three consecutive locations, in order (for example 30, 31, 32). Memory Protect (Global menu) must be OFF. The three are already a template group, so a ROW-SELECT button steps through them.
3. Open the editor as `FZED.html?remotesl` (the Remote SL choice is hidden otherwise; the editor remembers it after that). Set **IN** = the SL's USB port 1, **INPUT VALUES** = Remote SL, **FOLLOW** = Follow and forward, **OUT** = the FZ's MIDI interface, **CH** = the FZ's channel. Turn on Notes / bend thru for the keys and the pads.

With INPUT VALUES set to Remote SL, FZED takes every controller message from the SL's port, on any channel, and sends it on the FZ's channel. The controls are routed to USB 1 only, so the FZ hears them only through FZED. (Up to this version they also went out of MIDI OUT 1. Any SL NRPN that reached the FZ that way carried CC99 = 0-7 and CC98 = 0-119 straight to FZED, which read them as chop slices = 4 and play slices: that is why MAKE SLICES chopped 4 whatever count was set.) The keys, pads, pedals and mod wheel still follow the template's keyboard port.

**What the controls send.** A control with a CC sends the real PERF CC with its FZED value. A control marked *param* sends PERF's parameter number as an NRPN (CC99 / CC98, then the value on CC6), and FZED sends the CC10 / CC11 pair. *PERF control* is a PERF control (parameter 88 / 89), such as the stretch settings. A few controls work on what is selected: the envelope step, the controller source (SRC MW / FOOT / AT), the matrix route (MX ROUTE 1-10) and the FX parameters of the current effect (FX P2-P5). These are marked *FZED NRPN*. Buttons step through the settings of a stepped control (each press is the next setting, then back to the first), switch it on and off, or send a command.

**Left to the editor's screen:** envelope stage rates and levels (the ADSR is on the sliders), capture INTERVALS, VELOCITY and STAGGER, and settings PERF only needs while setting up. The controller offsets, VEL > RES and the stepped settings are buttons: each press is the next step.

## FZED 1 SOUND

| Row | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Buttons above the encoders | TAPE SPD (CC71) | LFO WAVE (CC50) | VOX INIT (param 7) | FX TYPE (CC112) | FX LIVE (CC119) | FX DEL (CC100 (via NRPN)) | FX NORM (CC101 (via NRPN)) | RENDER (CC118) |
| Encoders | ORIG KEY (CC68) | LOW KEY (CC67) | HIGH KEY (CC66) | FX P2 (FZED NRPN 6/1) | FX P3 (FZED NRPN 6/2) | FX P4 (FZED NRPN 6/3) | FX P5 (FZED NRPN 6/4) | FX MIX (CC117) |
| Buttons below the encoders | AMP SUS (CC12) | AMP END (CC13) | FLT SUS (CC30) | FLT END (CC31) | - | - | - | - |
| Pots | CUTOFF (CC74) | RES (CC75) | LFO RATE (CC73) | LFO PTCH (CC53) | LFO AMP (CC54) | LFO FLT (CC55) | LFO RES (CC56) | LFO ATK (CC51) |
| Sliders | DCA ATK (CC78) | DCA DCY (CC79) | DCA SUS (CC80) | DCA REL (CC81) | DCF ATK (CC82) | DCF DCY (CC83) | DCF SUS (CC84) | DCF REL (CC85) |
| Right upper buttons | NEW VOX (CC16) | VOX SEL (PERF control 12) | COPY VOX (param 126) | BANK SEL (CC14) | BANK ADD (CC15) | BANK CLR (CC15) | - | - |
| Right lower buttons | - | - | - | - | - | - | - | - |

## FZED 2 MOD

| Row | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Buttons above the encoders | SRC MW (FZED NRPN 2/2) | SRC FOOT (FZED NRPN 2/2) | SRC AT (FZED NRPN 2/2) | GLIDE MD (param 6) | LFO2 MOD (CC93) | LFO2 DST (CC92) | LFO2 DS2 (FZED NRPN 2/6) | VEL>RES (param 57) |
| Encoders | CT PTCH (FZED NRPN 4/0) | CT AMP (FZED NRPN 4/1) | CT FLT (FZED NRPN 4/2) | CT RES (FZED NRPN 4/3) | MX ROUTE (FZED NRPN 2/3) | MX SRC (FZED NRPN 5/0) | MX AMT (FZED NRPN 5/1) | MX DEST (FZED NRPN 5/2) |
| Buttons below the encoders | CT AOFS (FZED NRPN 4/4) | CT FOFS (FZED NRPN 4/5) | CT ROFS (FZED NRPN 4/6) | - | - | - | - | - |
| Pots | LFO2 RT (CC89) | LFO2 SHP (CC91) | LFO2 DLY (param 1) | LFO2 FAD (param 2) | LFO2 DPT (CC90) | LFO2 DP2 (param 109) | LFO1 DLY (param 0) | GLIDE (param 5) |
| Sliders | AMP KF (param 58) | AMP RSC (param 59) | FLT KF (param 60) | FLT RSC (param 61) | V>AMP LV (param 62) | V>AMP RT (param 63) | V>FLT LV (param 64) | V>FLT RT (param 65) |
| Right upper buttons | - | - | - | - | - | - | - | - |
| Right lower buttons | - | - | - | - | - | - | - | - |

## FZED 3 SAMPLE

| Row | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Buttons above the encoders | PLAY MD (CC70) | LOOP MD (CC86) | WIN SNAP (param 3) | LOAD WV (CC9) | ST ON (PERF control 9) | ST SNAP (PERF control 4) | ST SUS (PERF control 5) | ST NEXT (PERF control 16) |
| Encoders | PRESETWV (CC111) | ST TIME (PERF control 1) | ST SKEW (PERF control 18) | CAP TRNS (CC23) | SLC MOVE (param 123) | SLC LOW (param 124) | SLC HIGH (param 125) | VOX PICK (PERF control 11) |
| Buttons below the encoders | ST SEGS (PERF control 0) | REC RATE (CC102) | REC GAIN (CC104) | CAPTURE (FZED NRPN 2/8) | EXIT ESC (FZED NRPN 2/4) | EXIT SND (FZED NRPN 2/4) | EXIT VOX (FZED NRPN 2/4) | EXIT ALL (FZED NRPN 2/4) |
| Pots | REC LEN (CC103) | TRIG LVL (CC105) | NORM FLT (CC110) | SLICE (param 122) | CAP SYNC (CC33) | CHOP SNS (CC96) | PAT RATE (param 9) | ST ORDER (PERF control 17) |
| Sliders | SMP STRT (CC76) | SMP END (CC77) | LOOP STR (CC87) | LOOP END (CC88) | LOOP XFD (CC72) | WIN POS (param 4) | GRAIN (PERF control 2) | ST XFADE (PERF control 3) |
| Right upper buttons | CHOP MD (CC97 (via NRPN)) | CHOP CNT (CC99 (via NRPN)) | MAKE SLC (CC98 (via NRPN)) | PLAY SLC (CC98 (via NRPN)) | RET VOX (CC98 (via NRPN)) | CHOKE (param 121) | PATTERN (param 8) | SMOOTH (param 87) |
| Right lower buttons | CHOPINTO (PERF control 6) | FREEZE (PERF control 15) | CAP REL (FZED NRPN 2/9) | SLC OUT (param 127) | SLC FEL (PERF control 10) | CAP HOLD (CC105) | CAP FADE (CC34) | CAP RLS (CC41) |

## All three templates

| Control | Name | Sends |
| --- | --- | --- |
| Touchpad X1 | CUTOFF | CC74 |
| Touchpad Y1 | RES | CC75 |
| Touchpad X2 | LFO2 DPT | CC90 |
| Touchpad Y2 | FX MIX | CC117 |
| Transport Rewind | PAGE < | FZED NRPN 2/0 (Editor page back) |
| Transport Forward | PAGE > | FZED NRPN 2/0 (Editor page forward) |
| Transport Stop | REC STOP | CC109 (RECORD STOP) |
| Transport Play | REC STRT | CC107 (RECORD START) |
| Transport Record | REC ARM | CC106 (RECORD ARM) |
| Transport Loop | REC AUTO | CC108 (RECORD AUTO) |

The drum pads play notes (useful for slices), and the joystick sends pitch bend and mod wheel, on the SL keyboard's channel. The SL's screens show the value sent (0-127, or the FZED value); FZED's screen shows its meaning.

## Files

- `FZED_SL_1_SOUND.syx`, `FZED_SL_2_MOD.syx`, `FZED_SL_3_SAMPLE.syx`: one template each (4112-byte ReMOTE SL MkI template dumps, group of 3, positions 1-3). They are sent as single templates, into the SL's temporary memory; nothing is stored until you press WRITE.
- `FZED_SL_LAYOUT.json`: every control, what it sends and its range.
- Rebuild with `work/remote_sl/build_sl_templates.py` (from the editor profile).

Not yet tried on a ReMOTE SL here. Before writing, keep a backup of your SL templates (Global menu: Template dump, or the sl-template-editor app).
