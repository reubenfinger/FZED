# FZED ReMOTE SL templates (build)

- `build_sl_templates.py BASE.syx profile.json OUTDIR` writes `FZED_SL_1_SOUND.syx`, `FZED_SL_2_MOD.syx`, `FZED_SL_3_SAMPLE.syx` and `FZED_SL_LAYOUT.json`. The profile is the editor's `profile.js` data as JSON.
- `make_sl_doc.py FZED_SL_LAYOUT.json` prints the layout tables used in the manual and `FZED_REMOTE_SL.md`.
- `base_MIDI_CC_Learn.syx` is the base template (keyboard zones, pedals, pads, template settings). It comes from the sl-template-editor project by Leonardo López Chavira, https://github.com/leonardolopezchavira/sl-template-editor, licensed GPL-3.0; it is included unmodified. The template format follows that project's `Docs/FORMAT.md`.
