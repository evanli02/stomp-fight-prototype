# Remote playtesting with Steam Remote Play Together

How to get Overstomp in front of friends who are not in the room. Nothing here
involves publishing to Steam, a Steamworks account, or an app ID.

## What Remote Play Together actually does

It streams **your** running game to your friends and pipes their controller
input back to your machine as extra virtual gamepads. The game only ever runs on
your PC and only ever sees local controllers — which is exactly what Overstomp
already is. That is why this works with no netcode: there is none, and none is
needed.

Consequences worth knowing before you schedule an evening around it:

- **Everyone needs a gamepad.** Remote players' input arrives as virtual pads.
  Only the host can use mouse and keyboard, so the host takes the keyboard seat
  and every guest takes a pad seat. That maps onto the lobby exactly: seat 0 is
  mouse + keyboard, seats 1–5 are pads.
- **Up to 5 guests + you.** Enough for 3v3, which is the largest format.
- **Latency is theirs, not yours.** Their inputs make a round trip. Overstomp is
  a momentum game with 0.6 s stuns and tight b-hop windows, so expect guests to
  feel a step behind on a bad connection. Judge *their* feedback about feel with
  that in mind — it is the stream, not the game.
- **Your upload matters.** You are sending video to everyone. Wired is better.
- Steam must be running and the game must be launched **through Steam**, which
  is what the non-Steam shortcut below is for.

## One-time setup

### 1. Install Godot's export templates

They are a separate ~1 GB download and are deliberately not in this repo.

Godot → **Editor** → **Manage Export Templates** → **Download and Install**.
They land in `%APPDATA%\Godot\export_templates\4.7.1.stable\`.

### 2. Build the .exe

```bash
powershell -ExecutionPolicy Bypass -File tools/build_windows.ps1
```

It runs all four headless harnesses first and refuses to build if any fail — a
build that ships a broken stomp loop to five people costs an evening, and the
harnesses cost fifteen seconds. `-SkipTests` overrides that; `-Debug` builds a
debug export instead (slower, but it prints errors to a console window, which is
what you want the first time something goes wrong on someone else's input).

Output is `build/Overstomp.exe`, self-contained — the `.pck` is embedded, so it
is the only file you need. `build/` is gitignored.

### 3. Add it to Steam

Steam → **Games** → **Add a Non-Steam Game to My Library** → **Browse** →
pick `build\Overstomp.exe` → **Add Selected Programs**.

Rebuilding later overwrites the same path, so this is a one-time step.

## Running a session

1. Launch **Overstomp** from your Steam library (not by double-clicking the exe
   — Steam has to own the process for Remote Play to see it).
2. Steam overlay (Shift+Tab) → **Friends** → each friend → **Remote Play
   Together**.
3. Wait until everyone is connected *before* leaving the lobby. Their virtual
   pads only exist once they have joined the stream.
4. In the lobby: host sets the format (1v1 / 2v2 / 3v3) and match length with
   WASD; everyone presses **Space** (keyboard) or **R1 / A** (pad) to take a
   seat. The screen shows which device landed in which seat, so people can tell
   each other apart.
5. When every seat for the chosen format is filled, the host presses
   **ability** (LMB / L1) to start. Unclaimed seats are not allowed — an
   undriven body on the stage is a free life for the other team.
6. Hero select (3 heroes each, timed) → stage select (round 1: coinflip winner;
   later rounds: whoever just lost) → fight.

## Controls to paste into the group chat

| Action | Pad | Keyboard |
|---|---|---|
| Move / aim direction | Left stick | WASD |
| Aim | Right stick | Mouse |
| Jump (hold for height) | R1 | Space |
| Dash | R2 | Shift |
| Crouch / slide | Left stick down | S |
| Ability | L1 | Left click |
| Swap hero | L2 | Right click |
| Ultimate | **R2 + L2 together** | E |

The only way to take a life is to land on someone's head. Nothing else — no
ability, no ultimate, no hazard, no fall — can do it, and there are no pits.

## When something goes wrong

- **A guest's pad does nothing.** They joined the stream after the lobby was
  left. Back out to the lobby (restart the game) and re-seat everyone.
- **Two people driving one character.** Two devices claimed the same seat, which
  the lobby is supposed to prevent; note what they pressed and when, because
  that is a bug worth a report.
- **The build has no art / no stages.** The export ran without an import cache.
  Re-run the build script, which imports first.
- **Steam does not offer Remote Play Together.** The game was not launched from
  the Steam library, or the shortcut points at a stale path after a move.

## What is not ready

Honest list, so feedback lands on real problems:

- **No audio at all.** Not a bug.
- The HUD is laid out for two players; 2v2 and 3v3 will look cramped.
- Only two stages: Rooftop Rumble and Cryo Lab.
- No rebinding, no options screen, no pause.
- Feel has been verified by harness, not by humans. The jump height, Cryo Lab's
  laser cadence, and Sai's reel are the three most likely to be wrong — those
  are the ones worth asking about directly.
