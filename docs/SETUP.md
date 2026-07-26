# SETUP.md — Environment & Tooling Guide

Everything needed to work on Overstomp on a personal machine (Windows / macOS / Linux).

## 1. Required

### Godot Engine 4.4+ (standard build, not .NET)
The project uses GDScript only, so the standard build is correct.
- **Download**: https://godotengine.org/download — grab 4.4.x or newer stable.
- **Windows**: unzip anywhere, run `Godot_v4.x-stable_win64.exe`. Optionally `winget install GodotEngine.GodotEngine`.
- **macOS**: `brew install --cask godot`, or download the .dmg and drag to Applications (first launch: right-click → Open to pass Gatekeeper).
- **Linux**: download the x86_64 binary and `chmod +x` it, or `flatpak install flathub org.godotengine.Godot`.
- Verify: open Godot → Import → select this repo's `project.godot` → the project opens without errors.

### Git
- **Windows**: `winget install Git.Git` (includes Git Bash).
- **macOS**: `xcode-select --install` or `brew install git`.
- **Linux**: `sudo apt install git` (or distro equivalent).
- Recommended `.gitattributes` is already committed; no LFS needed while assets stay as small PNGs (revisit if audio/large sheets land).

## 2. Strongly recommended

### Claude Code (for AI-assisted implementation)
- Install: `npm install -g @anthropic-ai/claude-code` (requires Node 18+), or use the desktop app.
- Run `claude` from the repo root — it will pick up `CLAUDE.md` automatically. Start sessions with the prompt in `docs/OPUS_PROMPT.md`.

### GUT (Godot Unit Test) addon — for `tests/`
- In Godot: AssetLib tab → search "GUT" → install (or clone https://github.com/bitwes/Gut into `addons/gut`).
- Enable: Project → Project Settings → Plugins → Gut → Enable.
- Run tests: the GUT panel appears at the bottom of the editor; point it at `res://tests/`.

### Pixel art tooling (assets iteration)
- **Nothing to install for the generated art.** `assets/tools/` is stdlib-only Python (3.9+), so `python assets/tools/generate_characters.py` and `generate_placeholders.py` work on a clean checkout. Run `Godot --headless --path . --import` afterwards so Godot picks up new PNGs, and `--script res://tests/verify_frames.gd` to confirm the hero SpriteFrames still load.
- **Aseprite** (~$20, the standard): https://www.aseprite.org — best animation timeline for sprite work. Free if you compile it yourself. Use it for hand-authored frames that replace generated ones; note that re-running a generator overwrites its own outputs.
- **Libresprite** (free fork) or **Piskel** (free, browser) work fine too.
- Import settings for this project: PNGs import with **Filter = Nearest** (already set project-wide via default texture filter). Never resave assets with interpolation.

### Editor niceties
- VS Code + the "godot-tools" extension if you prefer external editing (set VS Code as external editor in Godot: Editor Settings → Text Editor → External).

## 3. Controller support
- Godot ships SDL gamepad support; Xbox/PlayStation/Switch Pro pads work out of the box on all three OSes.
- On Linux, if a pad isn't detected: ensure your user is in the `input` group and `evdev` permissions allow it.
- Verify in-project with the input debug scene once M2 lands (`src/stage/playground.tscn` shows active device + bindings).

## 4. First run
1. Clone the repo, open `project.godot` in Godot.
2. Press F5 (Run Project). The placeholder main scene should load without script errors (it's a stub menu until M1).
3. Open `src/stage/playground.tscn` and press F6 (Run Current Scene) when working on movement.

## 5. Common problems
| Symptom | Fix |
|---|---|
| "Unable to load addon script" on open | GUT not installed yet — install it or ignore until you run tests. |
| Sprites look blurry | A texture got imported with filtering — select PNG → Import tab → Filter Nearest → Reimport. |
| Controller chord (R2+L2 ult) triggers dash/swap | Expected until `InputConfig` chord resolver is implemented (M2). |
| Project opens but scripts have errors on 4.3 or below | Upgrade Godot; the project targets 4.4+ syntax/features. |
