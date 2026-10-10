# DAET: Ang Pamana

> A first-person Filipino psychological horror game, built in Godot 4.x and designed for Android mobile.

Daet (named after the town in Camarines Norte) places the player as an **apo** — a grandchild — visiting their lolo and lola's ancestral house for a few days. The house looks familiar at first: wooden floors, family photographs, a quiet altar, the hum of insects after sundown. By the second night, familiarity turns into something older and more deliberate: a locked room nobody will discuss, footsteps upstairs when nobody is upstairs, and a name whispered through an empty hallway. Finding the truth means searching the house, talking to Lolo and Lola with care and skepticism, solving puzzles pulled from the family's past, and ultimately deciding what to do with what the player uncovers.

The horror is deliberately quiet — it's about buried family memory, local folklore, and the uncomfortable question of whether the people who raised you have been honest with you.

---

## What this archive contains

```
Daet_Filipino_Horror/
├── project.godot                 — main engine configuration (Godot 4.x, Mobile renderer)
├── README.md                     — this file
├── icon.svg                      — original app icon (hand-authored SVG)
├── export_presets.cfg            — Android + Linux + Windows export templates
├── assets/
│   ├── audio/                    — 27 original WAV files generated procedurally
│   │   ├── music/                — menu / ambient drone / ending themes
│   │   ├── ambience/             — night insects, night wind, rain
│   │   └── sfx/                  — footsteps, doors, whispers, radio static, etc.
│   └── materials/default_env.tres — fallback 3D environment
├── data/
│   └── dialogue/                 — JSON dialogue trees (Filipino + English subtitles)
├── scripts/
│   ├── autoload/                 — Settings, SaveSystem, Inventory, MissionManager,
│   │                              DialogueManager, HorrorManager, AudioManager,
│   │                              GameState, SceneLoader (9 singletons)
│   ├── player/                   — first-person CharacterBody3D controller
│   ├── interaction/              — reusable Interactable, Door, Pickup, Note,
│   │                              Photograph, Drawer, LightSwitch, DialogueTrigger
│   ├── missions/                 — mission trigger area + ending zone
│   ├── puzzles/                  — 4-digit CodeLock + FuseSlot electrical puzzle
│   ├── horror/                   — base HorrorEvent + Silhouette, Door, Radio scares,
│   │                              entity AI
│   ├── environment/              — HouseBuilder (procedural level) + GameController
│   └── ui/                       — HUD, mobile joystick & camera area, dialogue box,
│                                  inventory, journal, note viewer, code lock UI,
│                                  pause menu, main menu, settings, credits, ending
└── scenes/                       — 16 .tscn scenes (gameplay, menus, environment,
                                     player, HUD panels)
```

## System requirements

- **Engine:** Godot **4.2** or newer (mobile renderer).
- **Mobile target:** Android 6.0+ (API 23+), arm64-v8a.
- **Desktop:** Linux, Windows, macOS — any version Godot 4.2 supports.

## Opening the project

1. Download and install Godot 4.2+ from [godotengine.org](https://godotengine.org).
2. Extract this archive anywhere on disk.
3. Open Godot, click **Import** on the project manager, and pick `project.godot` inside the extracted folder.
4. Godot will scan assets on first open — this takes 30–90 seconds (it generates `.import` files for the WAV audio and the SVG icon). The console may print a few lines about reimporting; wait until the import queue is empty.
5. Press **F5** (or the Play button) to run. The main menu scene (`scenes/main_menu.tscn`) opens first.

## Running on Android

To build an APK you need the Android export tools in addition to Godot itself. Godot's docs walk through the full install:

1. **Install the editor templates.** In Godot: `Editor → Manage Export Templates → Download and install`. Pick the templates matching your Godot version.
2. **Install Java and Android SDK.**
   - JDK 17 (OpenJDK or Oracle).
   - Android Studio or the standalone **command-line tools** → install the Android SDK, build-tools 34+, and platform-tools.
3. **Configure Godot.** `Editor → Editor Settings → Export → Android`:
   - **Android SDK Path:** point to your Android SDK root.
   - **Debug Keystore:** the project ships without one; Godot auto-generates a debug keystore on first use.
4. **Open the Export dialog:** `Project → Export → Android`. The project ships with a pre-filled preset (`Daet: Ang Pamana`, package `com.daet.pamana`, arm64-v8a only).
5. **Press "Export Project" → choose an `.apk` filename.** Godot runs Gradle and produces an installable APK.
6. **Install on your device** with `adb install path/to/daet_ang_pamana.apk` or sideload it in any way you prefer.

### Release signing

Release builds need a release keystore. Generate one with:

```bash
keytool -v -genkey -keystore daet.keystore -alias daet -keyalg RSA -validity 10000
```

Then point the Android preset at that file and fill in the alias + passwords.

## Controls

### Desktop

| Action | Key |
| --- | --- |
| Move | W / A / S / D |
| Sprint | Shift |
| Crouch | Ctrl |
| Interact | E |
| Flashlight (once collected) | F |
| Inventory | I |
| Journal | J |
| Advance dialogue | Space or Left Click |
| Pause | Esc |

The mouse controls the camera (click once on the game window to capture the cursor).

### Mobile

- **Lower-left corner:** virtual joystick (anywhere in the pad area). Drag to walk / strafe.
- **Right side:** drag to look around. The right half of the screen is the camera pad.
- **Lower-right buttons:** Sprint (hold), Flashlight, Crouch (toggle), Interact.
- **Top-right buttons:** Inventory, Journal, Pause.
- **During dialogue:** the Interact button advances the line; or tap anywhere outside the controls.

Multitouch is fully supported — you can move and look at the same time.

## Gameplay

The player progresses through 13 ordered missions that cover arriving at the house, meeting Lolo and Lola, discovering the family's buried secret, and choosing one of three endings:

| Ending | Trigger |
| --- | --- |
| **I. Patawad** (Forgiveness) | Speak Tala's name aloud. |
| **II. Ibinaong Pangalan** (The Name Reburied) | Close the box and leave. |
| **III. Nawala sa Lagusan** (Lost in the Passage) | Hold the necklace. |

A one-page story-recap is intentionally omitted — the game surfaces its own narrative through notes, photographs, and dialogue.

## Save system

- Saves live in Godot's `user://` folder (Android: internal app data; desktop: `~/.local/share/godot/app_userdata/Daet: Ang Pamana/`).
- Save with **Pause → Save Game**. Saves cover: current mission, completed objectives, story flags, inventory, triggered horror events, player position, and chosen ending.
- The main menu's **Continue** button is enabled only when a valid save exists; corrupt saves fall back to the auto-written `.bak` file before refusing.

## Settings

- Audio: master / music / ambience / SFX sliders.
- Input: separate sensitivity sliders for mouse and touch, plus invert-Y.
- Display: subtitles toggle, English subtitles toggle, reduce motion (lowers camera shake / screen flash), mobile controls visibility.

All settings persist to `user://settings.cfg` and are applied in real time.

## Technical notes

- **Rendering method:** `mobile`. MSAA disabled on mobile for perf; shadows at 1024 on mobile vs. 2048 desktop.
- **Procedural everything:** the entire ancestral house (walls, floors, furniture, doors, lights, interactables, horror events, mission triggers, altar, hidden passage) is built in a single GDScript at runtime — see `scripts/environment/house_builder.gd`. This keeps the scene file small, keeps everything data-driven, and makes modifying the layout a one-line change.
- **Procedural audio:** every .wav in `assets/audio/` was generated by `tools/generate_audio.py` using only the Python standard library. The script is included for reproducibility — re-running it rebuilds the whole audio library deterministically from the same seed (1973).
- **Mobile input architecture:** virtual joystick and touch-camera area live on a `CanvasLayer` HUD and feed their vectors directly to the player's `joystick_input` and `apply_touch_look()` entry points. No polling, no shared Input state — switching between keyboard and touch mid-game is seamless.
- **Autoload order matters** and is set in `project.godot`: Settings → SaveSystem → Inventory → MissionManager → DialogueManager → HorrorManager → AudioManager → GameState → SceneLoader.

## Credits

Everything in this archive — code, scene layout, dialogue, audio synthesis — was built from the ground up for this game. No third-party assets are included or required. The visual language and mission structure take cues from Filipino provincial life (specifically Camarines Norte) but no real family, person, or community is represented. The folklore element is treated as a story device, not as a factual claim about any community.

Para sa mga nagmamahal sa kanilang mga lolo at lola — at para sa mga pamilya kung saan walang nagsasabi ng totoo.

## Troubleshooting

- **"Script does not exist" on import** — Godot occasionally fails to resolve the autoload order on a fresh clone. Restart the editor once; this clears the issue.
- **No sound on first launch** — the WAV files must finish importing. Watch the import queue in the bottom status bar; wait for it to drain, then press Play again.
- **Blurry text on mobile** — the display stretch is `canvas_items` with aspect `keep_height`. Rotate the device to landscape (the project forces landscape orientation but splash screens may briefly show in portrait on first boot).
- **"Continue" is greyed out** — no valid save exists yet. Press New Game first; subsequent runs will enable Continue once you save from the pause menu.

## License

The player (that's you) may study, modify, redistribute, or build on this project freely. Please credit the project if you ship something based on it.
