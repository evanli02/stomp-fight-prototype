# Remote playtesting

How to get Overstomp in front of friends who are not in the room. Nothing here
involves publishing to Steam, a Steamworks account, or an app ID.

**Read this before picking a route.** Both options below stream the game from
your machine and forward guests' controllers back as extra local gamepads, which
is exactly what Overstomp needs and why it works with no netcode. They differ in
how reliably they will start at all:

| | Works with our build? | Notes |
|---|---|---|
| **Parsec** | Yes, by design | Free. Guests join by link, each gets a virtual gamepad. Use this first. |
| **Steam Remote Play Together** | Maybe | Officially gated on a game carrying Steam's "Remote Play Together" store category. A non-Steam shortcut has no store metadata, so Steam may never offer the option. Try it if you prefer, but do not plan an evening around it. |

## Route A: Parsec (recommended)

1. Install Parsec on your machine and have each friend install it (or use the
   web client - they do not need an account for a hosted session link).
2. Build the exe (below), then just run it. No Steam shortcut needed.
3. In Parsec, start hosting and send each friend the invite. Their controllers
   appear on your machine as virtual gamepads as they connect.
4. Everyone joins seats in the lobby exactly as described under "Running a
   session" - the game cannot tell a Parsec pad from one plugged into your desk.

Guests need controllers for the same reason they do under Steam: see "Why
guests need gamepads" below.

## Route B: Steam Remote Play Together

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

If PowerShell refuses to run it at all, it is the execution policy, not the
script — the `-ExecutionPolicy Bypass` above is what handles that, so run it
exactly as written rather than double-clicking the file.

Output is `build/Overstomp.exe` (~105 MB), self-contained — the `.pck` is embedded, so it
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
   pads only exist once they have joined the stream. (Same on Parsec.)
4. In the lobby: host sets the format (1v1 / 2v2 / 3v3) and match length with
   WASD; everyone presses **Space** (keyboard) or **R1 / A** (pad) to take a
   seat. The screen shows which device landed in which seat, so people can tell
   each other apart.
5. When every seat for the chosen format is filled, the host presses
   **ability** (LMB / L1) to start. Unclaimed seats are not allowed — an
   undriven body on the stage is a free life for the other team.
6. Hero select (3 heroes each; **no timer** - it waits until everyone has picked, and names who it is waiting on) → stage select (round 1: coinflip winner;
   later rounds: whoever just lost) → fight.

## Why guests need gamepads

Each guest's **controller** arrives as its own virtual pad with its own device
id, which is what lets `InputConfig.claim_seat()` bind them to separate seats.
Guest **keyboard and mouse** input is injected into your machine's single system
keyboard and mouse - one cursor, one key stream, shared by everyone. Nothing
downstream can tell two keyboard guests apart, and Godot has no multi-keyboard
support to lean on even if the input were tagged. So one keyboard seat is the
honest maximum, and it belongs to whoever is sitting at the host machine.

You can also run an all-pad session: `claim_seat` fills the lowest free seat
regardless of device, so if the host takes a controller too, seat 0 is simply a
pad and nobody needs the keyboard.

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
- **Steam does not offer Remote Play Together.** In order of likelihood: the
  game was not launched from the Steam library entry (your own friends-list
  status must read *In-Game - Overstomp*, not *Online*); you hovered the friend
  instead of clicking them; Remote Play is disabled in Steam settings; or Steam
  is refusing it because a non-Steam shortcut has no Remote Play Together store
  category, which is not something you can fix. Switch to Parsec.

## What is not ready

Honest list, so feedback lands on real problems:

- **No audio at all.** Not a bug.
- The HUD is laid out for two players; 2v2 and 3v3 will look cramped.
- Only two stages: Rooftop Rumble and Cryo Lab.
- No rebinding, no options screen, no pause.
- **No timers on the select screens.** Nothing advances until every player has
  acted, so one person going to get a drink stalls the lobby. Say so before you
  start rather than after.
- Feel has been verified by harness, not by humans. The jump height, Cryo Lab's
  laser cadence, and Sai's reel are the three most likely to be wrong — those
  are the ones worth asking about directly.
