# Tools

Helper scripts for the DAET project. Not required at runtime.

## generate_audio.py

Rebuilds every WAV file in `assets/audio/` using pure Python stdlib synthesis. Run from the project root:

```bash
cd /path/to/Daet_Filipino_Horror
python3 tools/generate_audio.py
```

The script is deterministic (seeded with 1973) so each run produces identical files. Use it to:

- Reproduce the audio library on a fresh clone without downloading binaries.
- Tweak sound parameters (filter cutoffs, envelope shapes, pitch) and re-render.
- Add new sound effects — follow the existing `sfx_*` / `amb_*` / `music_*` pattern.

Written entirely with the standard `wave`, `struct`, `math`, and `random` modules — no numpy or scipy required.
