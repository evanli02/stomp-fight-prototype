# Overstomp — Session Handoff

Written 2026-07-26, updated through the M5 close-out. This file exists so a **fresh session can pick the
project up cold**. It is the "what happened and what will bite you" document; it is *not* a
spec. Precedence when they disagree:

`CLAUDE.md` (binding rules) → `docs/DESIGN.md` (authoritative game spec) →
`docs/IMPLEMENTATION.md` (architecture) → `assets/STYLE_GUIDE.md` (art) → this file.

Read `CLAUDE.md` first regardless. Everything below assumes you have.

---

## 1. Where the project actually is

Milestones M1–M5 from `docs/IMPLEMENTATION.md` §7 are **done and playable end to end**:

| Milestone | Contents | State |
|---|---|---|
| M1 | Movement state machine, config resources, playground | done |
| M2 | Stomp resolution, lives, stun/grace, duels | done |
| M3 | Rosters, swap, cooldowns, ult economy, HUD, round loop, hero select | done |
| M4 | Four hero kits + Rooftop Rumble stage | done, then reworked twice |
| M5 | Eight terrain elements + `PoleClimb`, two stages, stage select | done |
| — | Art overhaul: chibi proportions, 8 heroes, VFX, UI pass | done |
| M6 | 2v2/3v3, lobby, Windows export | playable; **audio/HUD/stages outstanding** |

You can boot `src/main.tscn` and play a full match at 1v1, 2v2 or 3v3: lobby (format, match
length, who is sitting where) → hero select → stage select → rounds → results. There is still
no audio, the HUD is laid out for two players, and netcode is out of scope by design — remote
play is covered by streaming instead (`docs/PLAYTEST.md`).

All four harnesses are green — **movement 78, combat 41, match 226, terrain 74 = 419 checks**,
zero script errors. (This line goes stale easily; re-count it rather than trusting it.)

---

## 2. Environment and commands

Godot 4.7.1, **console** build (the non-console one swallows stdout, which makes the harnesses
useless):

```bash
~/Downloads/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64_console.exe --headless --path . tests/movement_harness.tscn
```

Substitute `combat`, `match`, `terrain`. Each prints `PASS …` lines and ends with
`ALL CHECKS PASSED` or a `FAIL`. Run **all four** before committing; they are fast (seconds).

Re-import after adding any `class_name` or any new PNG, or Godot will not see them:

```bash
~/Downloads/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64_console.exe --headless --path . --import
```

Regenerate character art (stdlib-only Python, no deps), then re-import, then verify:

```bash
python assets/tools/generate_characters.py
```

```bash
~/Downloads/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64_console.exe --headless --path . tests/verify_frames.gd
```

Human-playable scenes:

- `src/main.tscn` — the real shell: lobby → hero select → stage select → match → results.
- `src/stage/duel.tscn` — Rooftop Rumble, two players, straight into a fight. **This is the
  scene to use for feel-testing.**
- `src/stage/cryo_lab.tscn` — the second stage: ice, a timed laser grid, a portal pair.
- `src/stage/playground.tscn` — flat debug box with the state/velocity overlay.

Booting a stage directly (F6) skips the select screens by design: `start_match`'s
`use_stage_select` defaults to false, so a stage that is already loaded never asks which stage
to load.

---

## 3. Roster (8 heroes)

Heroes are identical in movement and hitboxes. Identity is ability + ultimate + cosmetics only.
Cooldown order is Sai < Fei < Deadeye < Cerebelle < Slip < Kid < Terra < Mason. The
Fei-shortest ordering the owner set applies to the original four; Sai's grapple was cut to
4.7 s afterwards and is now the shortest in the game.

| Hero | Colour | Ability (CD) | Ultimate |
|---|---|---|---|
| Deadeye | red | Bolt — stunning projectile (6.4) | Rapid Fire — resets CD; next bolt +50% velocity, 5.5 s stun |
| Fei | jade green | Double Trouble — a stronger-than-normal extra jump (5.6) | 8 s window where the ability's CD is 0.3 s |
| Cerebelle | purple | Burst — near-instant radial knockback, 2× force (6.7) | Supernova — one map-wide ring that expands slowly; caught players are stunned, lose all horizontal velocity, and fall |
| Sai | pink | Grapple — visible hook; swing on the rope (5 redirects), recast to reel in (4.7) | Slash — dashing multi-hit arc |
| Slip | aqua | Slip Back — drop a **visible** anchor, recast to blink instantly back to it (8.0) | Teleport — a linked pad pair; enemies arrive slowed, allies hasted |
| Terra | brown | Slam — hover, then rocket straight down (9.0) | Fracture — wide slab that drags, trails, and detonates |
| Kid | orange | Wind Cannon — pushing beam (8.5) | EMP — telegraphed wave that disrupts |
| Mason | gold | Bumper Block — solid block with lingering vector reflection (10.0) | Keystone — allies pass through, enemies freeze then drop |

**Terra's Slam can end in a life loss and that is not a rule-1 violation.** A slam is a very
fast fall, and falling onto a head *is* the stomp system: it goes through `receive_stomp` with
grace, anti-chain and victim authority intact. `combat_harness.gd` asserts both halves. Do not
"fix" it; do not copy the pattern into an ability that is not literally a fall.

---

## 4. Architecture, in one screen

- **Autoloads.** `GameManager` (phases, seeded RNG, hero registry, ticks benched cooldowns),
  `MatchState` (single source of truth for lives/rosters/ults), `InputConfig` (per-seat
  namespaced actions, R2+L2 ult chord, memoised per-tick polling).
- **Movement** is a state machine in `src/player/states/`: `Idle, Run, Skid, Air, Crouch,
  Slide, WallSlide, WallJump, Dash, Stunned, PoleClimb, Swing + Reel (Sai), Slam (Terra),
  Recall (Slip)`. Each state owns its own animation via `animation()`. New movement behaviour is a new
  state or transition — never an `if` ladder in `player.gd`.
- **Abilities** are `Ability` subclasses in `src/heroes/abilities/`, attached at spawn from
  `HeroData` `.tres` files. The base class exposes the hooks the reworked kits needed:
  `_can_fire()`, `_cooldown_after_fire()`, `_is_free_recast()`, `grant_cooldown_override()`,
  `reset_cooldown()`. Abilities touch the player only through its public API.
- **Effects** are self-contained scenes/scripts in `src/heroes/effects/` that draw themselves
  in `_draw()`. No art assets involved.
- **Terrain** implements the `TerrainElement` contract (`tick`, `on_body_entered`, …) —
  ice, pole, portal, speed pad, jump spring, stun line, wind zone, explosion. `StunLine` also
  takes an optional duty cycle, which is what makes Cryo Lab's grid a rhythm rather than walls.
- **Stages** are `MatchStage` (`src/stage/match_stage.gd`) plus a subclass supplying layout,
  terrain and palette only — the base owns seats, the round loop, respawns and the overlay.
  Seating is format-driven: the scene ships two bodies, `_seat_players()` clones up to
  `GameManager.seat_count()`, and `spawns()` returns one anchor **per team** with the base
  spreading teammates around it.
  Registered in `GameManager.STAGE_ROSTER`, which also carries the name/blurb/features/accent
  the select screen draws, so a menu never has to instantiate a stage to describe it.
- **Debuffs** are a small shared system on `Player`: `apply_slow`, `apply_impairment`,
  `apply_disrupt`, `apply_freeze`, each taking a **source tag**. `src/ui/debuff_marks.gd`
  renders one badge per active tag, distinguished by **shape first** (slash / bolt / chain /
  ring), colour second — so it stays readable for colour-blind players and in a busy frame.

### Where the numbers live

`src/config/combat_config.tres` carries explicit overrides. **`movement_config.tres` currently
carries none** — the live movement values are the `@export` defaults in
`src/config/movement_config.gd`, where each one has a comment explaining *why* it is what it is.
That is intentional and readable, but be aware of it: tune by editing the defaults there **or**
by adding overrides to the `.tres`, never both, or you will chase a number that isn't the one
in effect.

---

## 5. What this session changed, and why

Ordered as it happened. The "why" matters more than the diff — the user's reasoning is the part
that isn't recoverable from git.

**Movement feel (2 passes, commits `ef9c44e` and earlier).** Dash and wall-jump direction moved
off the *aim* control onto the *movement* control — aiming a dash was fighting the player's
hands. Min jump halved. Gravity +25–30% because the max jump read as floating. Wall-jump
vertical −30%. Run startup 40% slower (getting moving is a commitment; changing direction is
not). Air dash: nerfed upward, buffed horizontally including all four diagonals. Wall-jump
chain decay now applies **per wall face** — moving to a different wall starts a fresh chain.
Added `Crouch` and `Slide`.

**M3/M4/M5 (`ba8894c`, `43aed5a`, `c030dfd`, `e737f5f`, `b60e90c`).** Match spine, hero select
shell, the first four kits on Rooftop Rumble, then the eight terrain elements and dressing the
stage with them.

**Playtest fix pass (`fac21e9`).** Facing bug on the controller seat, Fei's sprite flipped,
per-player dash/cooldown readout above the character, **ult economy changed from one per round
to two with a 10 s gap**, Mason's block walk-through, hitbox width reduced so two players
standing together look like they're touching, ground dash made shorter than the air dash.

**Kit reworks (`19cf0df`, `04b0d3c`).** Mason became a Smash-bumper (solid, lingering hitbox,
vector reflection) with a pass-through freeze ult. Fei's ability became a plain stronger jump
(it was being aimed, which nobody wanted). Cerebelle's knockback doubled and her ult became the
slow map-wide ring you can outrun. Deadeye's ult became a reset + empowered next shot. Slide
tuned: no dash out of it, holds speed for 0.3 s then bleeds gradually, faster slide jump.

**Art overhaul (`98f4e04`).** All models and hitboxes 30% shorter with much larger heads; the
style moved from cluttered-futurist to comic-book punk (Big Hero 6 / MHA with a cyberpunk
edge). Skyla → **Fei**, Nova → **Cerebelle**. Frames are 32×36, body 22×34, head hurtbox the
top 10 px, stompbox the bottom 14 px. The pose rig in `assets/tools/generate_characters.py`
still authors animations in the original 48-tall joint space and squashes them to the 36 px
body at draw time via `_shrink()` — so **edit poses in the old coordinate space**, not the new
one.

**Four new heroes + systems (`9b61092`).** Sai, Slip, Terra, Kid; the debuff system with source
tags; the stomp burst VFX in the attacker's colour; ability/ult animations; UI flair and
accessibility pass.

**Feel pass (`64e08b6`, then the follow-up below).** Slip's anchor made visible (a diamond, deliberately unlike every
circular effect in the game) and the rewind faster. Sai's range and swing speed up, scaling
with carried speed. Terra's ult slab wider, blast much bigger, with a visible travel trail.
Debuffs buffed across the board: stuns slightly up, non-stun durations dramatically up, slows
~30% more effective. Distinct visual indicator per debuff source. Straight-down air dash
nerfed hard (30% distance, no post-dash boost) — a cheap fast-fall was the strongest stomp
approach in the game — with diagonals explicitly untouched.

---

## 6. Traps. Read this section before debugging anything.

### GDScript / Godot 4

- **`signi()` takes an int.** `signi(0.7)` truncates to `0`. This silently broke sprite facing
  on analog sticks for an entire session — the keyboard seat was fine, so it looked like a
  per-hero bug. Use `1 if x > 0.0 else -1`.
- **No tuple literals.** `for t in (0.25, 0.5)` is a parse error. Use arrays, and often typed
  loop vars (`for t: float in [...]`) to get the inference you expect.
- **Lambdas capture locals by value.** A `bool` set inside a signal lambda never escapes. Use a
  one-element array.
- **`Color("ff2e88")` is invalid inside a `.tres`.** Write the float form. This bug sat unnoticed
  until something finally loaded the hero resources.
- **`body_entered` never fires for a body already inside the area.** Anything that must affect a
  resting or re-entering body has to re-scan overlaps every tick with a per-player re-trigger
  gap. `TerrainElement` and both Mason blocks do this.
- **A launch applied to a grounded body is erased next frame** — `Idle`/`Run` zero `velocity.y`
  while on the floor. The jump spring looked completely dead until it also called
  `request_state(&"Air")`.
- **Depenetration teleports.** When a body's support vanishes (e.g. the head it was standing on
  is moved away), Godot can shove it ~100 px. Harness `place()` settles a frame and re-asserts
  position.

### This repo

- **The Godot editor prunes settings out of `project.godot` when it saves.** `GameManager._ready()`
  asserts the settings it needs so this fails loudly instead of mysteriously. If a run dies at
  startup complaining about a missing setting, restore `project.godot` — and never
  `git add -A` right after the editor has been open without reading the diff.
- **Bash working directory drifts between tool calls.** A stray `cd` once made `--path .` point
  at `src/heroes/abilities`, which reports as "no main scene defined". Always `cd` to the repo
  root or pass an absolute `--path`.
- **Use the Write tool for large files, not heredocs** — long `cat > f <<EOF` bodies failed with
  "unexpected EOF".
- **A `.replace()` without an assert fails silently.** Scripted doc edits that miss their anchor
  leave the file untouched and print success anyway — handoff.md's harness counts sat three
  commits stale that way. Assert every pattern, and check the result.
- **A script error inside a harness check does not fail the run.** The error aborts that check
  and the run still prints `ALL CHECKS PASSED`, because `_failures` never incremented. Always
  grep the output for `SCRIPT ERROR` as well as `FAIL`.
- **`String(x)` is a constructor, not a cast** — it rejects a value that is already a String.
  Use `str(x)`. This one showed up as exactly the silent-pass above.
- **Keep `.ps1` files pure ASCII.** Windows PowerShell 5.1 reads a script as the system ANSI
  codepage unless the file has a BOM, so one UTF-8 em-dash in a comment becomes mojibake and
  the parser dies on an unterminated string several lines later. `tools/build_windows.ps1` is
  ASCII-only for this reason.
- **Never `2>&1` a native exe in PowerShell 5.1.** It wraps each stderr line in an ErrorRecord
  and sets `$?` false even on exit code 0 — with `ErrorActionPreference = "Stop"` that aborts
  the script over nothing.
- **Keep non-ASCII out of match patterns in shell heredocs.** A `python - <<'EOF'` block is read with the locale encoding, not UTF-8, so an em-dash inside a string you are matching against a file arrives mangled and the match silently fails. Anchor on ASCII-only substrings.
- **`tests/test_match_state.gd` is a dead GUT stub.** GUT is not installed and is not used. It
  logs one harmless parse error on load. Ignore it, or delete it if it keeps causing confusion.

### Harness conventions

- **Park before placing** a trigger element — placing it on top of a body consumes the enter
  event you were about to assert on.
- **Settle a frame after teleporting** a body (see depenetration above).
- **Wait out in-flight effects before clearing state.** One test failure was purely test-side:
  it wiped debuff state 0.13 s *before* Kid's telegraphed EMP detonated, so a fresh 6 s disrupt
  landed after the wipe. Waiting 60 frames first fixed it.
- Stomp thresholds are tighter than they look: `stomp_min_relative_fall_speed` was 40, but two
  frames of gravity is 47 px/s, so merely *settling* onto a head registered as a stomp. It is
  120 now.

---

## 7. Documentation corrected alongside this file

`CLAUDE.md` and `SKILL.md` both still described the old one-ultimate-per-round economy, which a
fresh session would have read as binding and "fixed" back. Both now say two per round with a
~10 s gap. Also updated: the GUT-tests workflow rule (replaced with the four headless
harnesses), the note that Terra's slam is not a rule-1 exception, current hitbox geometry, the
directional air-dash taxes, and six new entries on the "things Claude gets wrong here"
checklist covering the traps above.

---

**Follow-up fix pass.** Slip's rewind stopped replaying her recorded path and became
a plain teleport to the anchor — the replay was too fragile to keep (see `recall.gd` for the
reasoning). Terra's ult travels 50% faster (480 → 720 px/s). Sai's grapple cooldown cut a third
(7.0 → 4.7 s). The jump got taller: full-hold apex 4.5 → 5.5 tiles (+23%), initial impulse
−268 → −285, gravity 1800 → 1900 so the extra height is not spent floating back down.

**M5 close-out.** Split `duel.gd` into `MatchStage` + Rooftop Rumble, built Cryo Lab on top of
it, gave `StunLine` a duty cycle, added the stage registry and the stage-select screen, and
wired the shell to route every round through it (round 1 to the coinflip winner, later rounds
to whoever just lost). Harness coverage came with it: the timed-line case that matters (a body
already standing in a line when it comes back on), Cryo Lab as a whole stage over several grid
cycles, the registry, and the phase order around `choose_stage`.

---

**Sai + aim guide pass.** The grapple hook became a real object with a ~0.14 s flight (it used
to raycast and swing on the same frame, so nothing about the ability was ever visible), and it
is now thrown on a miss too. Swing redirects 1 → 5. Recasting while roped hands Sai to the new
`Reel` state — a fast haul up the rope that stops `STOP_SHORT` (40 px) before the anchor,
because hooks land on ceilings and hauling all the way would end every reel inside the surface
it hung from. Every player now draws an `AimLine`: 6 hero-heights, dashed, clipped at terrain.

---

**M6 format plumbing.** `GameManager.team_size` is now the single input that makes the game
2v2 or 3v3: seat count, block seat→team allocation, per-team spawn anchors, six-seat input
bindings with real per-pad device indices, and both select screens all derive from it. Found
and fixed a robustness hole on the way — a stage indexed straight into its `players` array on
every MatchState signal, so any stage built for a smaller format than the one registered
crashed rather than ignoring seats it does not own (`MatchStage.body_for`).

---

**Lobby + export.** The lobby is now the first screen and the only one that decides seat count.
Players join by pressing a button on the device they want, and the lobby reads the **raw input
event** rather than a namespaced action — before a device has a seat it has no actions, and over
Steam Remote Play Together each guest's pad arrives with an id nobody can predict, so asking the
device which id it is at the moment it presses is the only mapping that survives. A Windows
export preset, a build script that runs the harnesses before it will build, and a playtest guide
ship with it.

---

**Stage-authoring tooling.** Stages are code, so the loop was edit-run-guess with no way to
know whether a gap was crossable. `tools/measure_reach.gd` now flies the real body and prints
the reach envelope (held jump 92px, capped-run gap 133px, jump+dash gap 275px, up-dash ceiling
103px, and the wall numbers), `docs/MAPS.md` is the guide built on those numbers, and **F3** in
any stage draws a coordinate grid, the spawn markers, and the envelope around player 1. The
overlay's constants come from the tool — re-run and update them together after a movement tune.

---

**Audio.** 18 procedurally generated cues (`assets/tools/generate_sfx.py`, stdlib `wave` only — same
bargain as the art pipeline) plus an `Audio` autoload. Cues are named rather than paths, and wired to
existing signals wherever one exists so a new way to lose a life keeps its sound. Never touches
gameplay: nothing on the physics tick, unknown cues are silent no-ops, both asserted.

---

**Audio and pause.** 18 procedurally generated cues (`assets/tools/generate_sfx.py`, stdlib `wave`
only — same bargain as the art pipeline) behind an `Audio` autoload with named cues, wired to
existing signals wherever one exists. A pause menu on Esc / Start from any seat gives volume,
restart and quit-to-lobby. `PROCESS_MODE_ALWAYS` on both the menu and `Audio` is what makes it work:
pausing the tree is what stops everything else, so the two nodes that must keep running opt out of
the pause they caused. Volume is in-session only; persisting it needs `user://`.

---

## 8. Open threads

Nothing is mid-edit; the tree is clean and green. Reasonable next moves, in the order that
makes sense:

1. **Feel-test both stages and the last tuning pass in `duel.tscn`** — the taller jump, the
   debuff buffs, the dive-dash nerf and Sai's swing speed all pass their harness checks, but
   only a human can say whether they're right. Cryo Lab's grid cadence (3 s cycle, 45% live)
   is the single most likely thing to be wrong by feel.
2. **Settings persistence** (`user://`). Volume resets every run, and rebinding has nowhere to live.
3. Rebind UI + `user://input.cfg` persistence (volume belongs in the same file); per-match RNG seeding (`GameManager._ready`);
   the two remaining launch stages (Powerplant, Skyline Gardens).
4. `movement_config.tres` vs `movement_config.gd` defaults (§4) is worth resolving one way or
   the other before the numbers drift.
