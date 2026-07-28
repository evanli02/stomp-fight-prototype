# Overstomp — Session Handoff

Written 2026-07-26; updated 2026-07-28 through the stage rebuilds, audio, pause, and the team
HUD. This file exists so a **fresh session can pick the project up cold**. It is the "what happened and what will bite you" document; it is *not* a
spec. Precedence when they disagree:

`CLAUDE.md` (binding rules) → `docs/DESIGN.md` (authoritative game spec) →
`docs/IMPLEMENTATION.md` (architecture) → `assets/STYLE_GUIDE.md` (art) → this file.

Read `CLAUDE.md` first regardless. Everything below assumes you have.

---

## 1. Where the project actually is

Milestones M1–M5 from `docs/IMPLEMENTATION.md` §7 are complete; M6 is most of the way there:

| Milestone | Contents | State |
|---|---|---|
| M1 | Movement state machine, config resources, playground | done |
| M2 | Stomp resolution, lives, stun/grace, duels | done |
| M3 | Rosters, swap, cooldowns, ult economy, HUD, round loop, hero select | done |
| M4 | Four hero kits + Rooftop Rumble stage | done, then reworked twice |
| M5 | Eight terrain elements + `PoleClimb`, three stages, stage select | done |
| — | Art overhaul: chibi proportions, 8 heroes, VFX, UI pass | done |
| M6 | 2v2/3v3, lobby, Windows export, audio, pause, HUD | **settings persistence, RNG seeding, 2 stages left** |
| M7 | Second hero wave: Voodoo, Saint, Vesper, Siku | done and rostered; human feel pass outstanding |

You can boot `src/main.tscn` and play a full match at 1v1, 2v2 or 3v3: lobby (format, match
length, who is sitting where) → hero select → stage select → rounds → results, on any of three
stages, with sound and a pause menu. Netcode is out of scope by design — remote play is covered
by streaming instead (`docs/PLAYTEST.md`), and §9 of `docs/IMPLEMENTATION.md` holds the posture
that keeps a real implementation possible later.

All four harnesses are green — **movement 78, combat 54, match 305, terrain 74 = 511 checks**,
zero script errors. (This line goes stale easily; re-count it rather than trusting it.)

---

## 2. Environment and commands

### Repo and branch state — read this before touching git

- Remote: `origin` → `https://github.com/evanli02/stomp-fight-prototype`.
- **The working branch is `rooftop-rumble-layout-pass`**, pushed to origin. `main` exists but
  is strictly behind it (audio, pause, KBM_ALT and the team HUD are only on the branch).
  Merging to `main` is an open thread, not something to do unprompted.
- History quirk: commit `80d29fa "Initial Commit for game"` mid-history added
  `.claude/settings.local.json` and a 38MB `build.zip` (a GitHub-publish artifact); the zip was
  removed and gitignored one commit later. Harmless, but don't be confused by the name.
- **Two sessions have edited this repo in parallel before.** Git was fine; the sessions'
  pictures of the code were not. If the log shows commits you don't recognise, catch up from
  `git log --stat` before editing anything — do not trust a summary of the code over the code.

### Godot

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
- `src/stage/duel.tscn` — Rooftop Rumble, straight into a fight. **This is the scene to use
  for feel-testing.** Rebuilt: one wide roof with a 160px channel down each side; one-way
  teleporters are the only quick way back out of a channel.
- `src/stage/cryo_lab.tscn` — rebuilt: every surface is ice, no hazards, three colour-coded
  portal pairs; the middle gap is crossed on a pole or through a portal, never by jump.
- `src/stage/sunken_court.tscn` — two solid mesas over a five-spring trench with no standing
  room; the roof platform costs a dash to reach.
- `src/stage/playground.tscn` — flat debug box with the state/velocity overlay.

**F3** in any stage toggles the design overlay (grid coordinates, spawns, the reach envelope).

Booting a stage directly (F6) skips the select screens by design: `start_match`'s
`use_stage_select` defaults to false, so a stage that is already loaded never asks which stage
to load.

---

## 3. Roster (8 live heroes + 4 designed)

Heroes are identical in movement and hitboxes. Identity is ability + ultimate + cosmetics only.
Cooldown order is Sai 4.7 < Deadeye 5.2 < Fei 5.6 < Cerebelle 6.7 < Slip 8 < Kid 8.5 <
Terra 9 < Mason 10 (Deadeye was cut under Fei in the 2026-07-28 rework pass).

| Hero | Colour | Ability (CD) | Ultimate |
|---|---|---|---|
| Deadeye | red | Bolt — stunning projectile (5.2) | Rapid Fire — resets CD; next bolt 2× velocity, **through terrain**, 6.5 s stun |
| Fei | jade green | Double Trouble — a stronger-than-normal extra jump, with a wind-puff VFX (5.6) | 8 s window where the ability's CD is 0.3 s; wears a wind aura |
| Cerebelle | **dark violet** | Burst — near-instant radial knockback, 210 px radius, ring lingers (6.7) | Supernova — one map-wide ring at 250 px/s; caught players are stunned, lose all velocity, and fall |
| Sai | pink | Grapple — visible hook at **any range** (the aim decides, not a range cap); swing (5 redirects), recast to reel in; jump-off ×1.35 (4.7) | Slash — instant line **through terrain**, 104 px corridor; lands at the furthest body-fits-and-inside-the-box point (see sai_slash.gd) |
| Slip | **deep blue** | Slip Back — drop a **visible** anchor, recast to blink instantly back to it (8.0) | Teleport — a linked pad pair; enemies arrive slowed, allies hasted |
| Terra | brown | Slam — hover, then rocket straight down (9.0) | Fracture — **instant 180px-wide wave**, stops at first terrain, victims stunned 2 s and hurled into that surface, long slow/impair |
| Kid | orange | Wind Cannon — pushing beam (8.5) | EMP — telegraphed wave that disrupts for 9 s |
| Mason | gold | Bumper Block — solid block that is a **four-sided spring**: fixed 470 launch out of the touched face, tangential speed kept, 6.5 s life (10.0) | Keystone — allies pass through; enemies freeze 0.45 s, fall, re-freeze — 3-4 freezes on the way through a block |

**The second wave is in and rostered** (2026-07-28) — twelve heroes now:

| Hero | Colour | Ability (CD) | Ultimate |
|---|---|---|---|
| Voodoo | bright purple | Soul Ignition — 8 s empower window (1.32× run), purple aura; touching an enemy knocks them back and slows their whole kit 3 s (18.0) | Phantom — 1.6× run + 1.45× dash, **jump untouched**, **green** aura, phases through bodies (2 s stun on pass-through), fully inverted skin, mask included. **Supersedes the ability**: ends it, cooldowns it, locks it out. A fall through a head is still a stomp |
| Saint | white | Cleanse — strip all debuffs/stuns from the team; casts **while stunned or slept** (11.0) | Benediction — cleanse, then empower + debuff immunity + one stomp ward each |
| Vesper | black / neon pink | Sleep Dart — fast dart (780), slow + a stack; 3 stacks sleeps them ~6.5 s (3.5) | Deep Sleep — huge slow sphere through everything; drops and sleeps ~9.75 s |
| Siku | ice blue | Pillar — ground only; 80px ice column launches everyone in the footprint, refused under a low ceiling (10.0) | Frostbite — five fast pulses with a frost aura on her, 1.5 s stun and a drop each |

**Sleep rules after the owner pass:** a sleep ends on expiry, a stun, or a fresh debuff —
and on nothing else. Terrain launches throw the sleeper without waking them
(`Player.request_state` redirects to `Sleeping` while asleep — a sleeper on a jump spring
was getting a free wake-up), but the launch itself still moves them: `Sleeping` only pins
`velocity.y` for a body that is resting or falling, or the throw would be erased on the floor. A stun or any `apply_*` debuff calls `_wake()`, so stomping a
sleeper wakes them. Saint casts through his own sleep; only the EMP locks him.

`docs/NEW_HEROES.md` is still their detailed reference: the shared Player systems they
introduced (impulse buff, contact scan, phasing, cleanse, stomp ward, the sleep stack
system + `Sleeping` state), the interaction table, and what the build taught.

**Terra's Slam can end in a life loss and that is not a rule-1 violation.** A slam is a very
fast fall, and falling onto a head *is* the stomp system: it goes through `receive_stomp` with
grace, anti-chain and victim authority intact. `combat_harness.gd` asserts both halves. Do not
"fix" it; do not copy the pattern into an ability that is not literally a fall.

---

## 4. Architecture, in one screen

- **Autoloads.** `GameManager` (phases, seeded RNG, hero + stage registries, ticks benched
  cooldowns), `MatchState` (single source of truth for lives/rosters/ults), `InputConfig`
  (per-seat namespaced actions, three device profiles, R2+L2 ult chord, memoised per-tick
  polling, and the one non-namespaced action: pause), `Audio` (every sound; named cues).
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
  ice, pole, portal, speed pad, jump spring, stun line, wind zone, explosion. `StunLine` takes
  an optional duty cycle (no stage currently uses it); `Portal` supports one-way pairs and
  accent colour-coding; `JumpSpring` replaces velocity **along its launch axis** only, so a
  wall-mounted spring flings you sideways without eating your fall; poles are **vertical
  ground** — down rides them, down+jump lets go, dash is a boosted drop.
- **Stages** are `MatchStage` (`src/stage/match_stage.gd`) plus a subclass supplying layout,
  terrain and palette only — the base owns seats, the round loop, respawns and the overlay.
  Seating is format-driven: the scene ships two bodies, `_seat_players()` clones up to
  `GameManager.seat_count()`, and `spawns()` returns one anchor **per team** with the base
  spreading teammates around it.
  Registered in `GameManager.STAGE_ROSTER`, which also carries the name/blurb/features/accent
  the select screen draws, so a menu never has to instantiate a stage to describe it.
- **Audio** (`src/autoload/audio.gd`) is the only thing that makes a sound. Cues are named, not
  paths, and wired to existing signals wherever one exists. `PROCESS_MODE_ALWAYS`, so it keeps
  working while the pause menu has the tree paused.
- **UI** lives in `src/ui/`: lobby → hero select → stage select, plus the HUD (laid out by team,
  scaling with the format), the pause menu (`ALWAYS`, so it can undo the pause it caused), the
  per-player status/aim/debuff overlays, and the F3 `StageGrid` design overlay.
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

## 5. What previous sessions changed, and why

Ordered as it happened, across several sessions. The "why" matters more than the diff — the
user's reasoning is the part that isn't recoverable from git.

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

**Sunken Court.** Third stage, built from a hand sketch against the reach envelope: two solid
mesas over a 320×128 trench. Then tuned to the owner's notes: **five springs tile the trench
wall to wall with no standing room** (springs must leave real standing room or none — anything
between is a seam you land in by accident), poles moved over the spawns, and the roof platform
raised one tile to 96px — deliberately *past* the 92px held jump, so the high ground costs a
dash. One tile is the smallest raise the grid allows, and it crossed a reach threshold.

---

**Movement fix pass.** Slide jumps no longer compound: the launch is clamped to
`run_speed_cap × slide_jump_speed_mult`, so chains flatline at 735 instead of running away.
Slide jump apex up a little (11.8 → 15.2px). **Landing into a slide inside the b-hop window
keeps all horizontal speed** — the third member of the perfect-window family, and what lets an
air dash convert into ground speed. Mason's block became a **four-sided spring** (fixed 390
launch out of the touched face, tangent kept): the old elastic reflection made one placement
behave as two different tools depending on approach speed.

---

**Select timers removed.** Hero select waits for every seat and names who it is waiting on;
stage select waits for the picking seat. Safe because the lobby means every seat has a real
device — there is no longer a seat that will never answer. Nothing advances on its own now.

---

**Both original stages rebuilt from sketches.** Cryo Lab: every surface ice, **no hazards**,
platforms climbing each half in 64px steps, and a 192px middle gap crossed only by pole or by
one of **three colour-coded portal pairs** (two diagonal escalators, one flat airborne-only
shortcut). Rooftop Rumble: one wide roof (800px of runway) with a 160px channel down each
side; falling into a channel costs — the only quick way back is a **one-way** teleporter to
the far top corner, and the channel portals fill the floor wall to wall so there is nowhere to
hide down there. Poles became **vertical ground** along the way: down rides the pole (fast),
down+jump lets go, jump leaps toward the stick, dash is a boosted straight drop.

---

**Audio and pause.** 18 procedurally generated cues (`assets/tools/generate_sfx.py`, stdlib `wave`
only — same bargain as the art pipeline) behind an `Audio` autoload with named cues, wired to
existing signals wherever one exists. Never touches gameplay: nothing on the physics tick,
unknown cues are silent no-ops, both asserted. A pause menu on Esc / Start from any seat gives
volume, restart and quit-to-lobby. `PROCESS_MODE_ALWAYS` on both the menu and `Audio` is what
makes it work: pausing the tree is what stops everything else, so the two nodes that must keep
running opt out of the pause they caused. Volume is in-session only; persisting it needs `user://`.

---

**Second keyboard seat + team HUD.** `Device.KBM_ALT` is a second keyboard profile on arrows +
a separate cluster, so one guest without a pad can join (mouse cannot be shared, so that seat
aims with keys). The HUD is laid out **by team** — team 0 stacks down the left, team 1 down
the right, blocks shrinking as the format grows — because the seat-based layout drew three
blocks on top of each other at 3v3.

---

**Kit rework + second-wave prep pass (2026-07-28).** Every existing hero except Slip got a
kit change from the owner's notes — the per-hero details are in §3's table and the
`tune:`/`feat:` commits. The ones with logic worth knowing about: **Sai's slash** now cuts
through terrain and finds its landing by walking back from the far end of the line until a
body-sized shape query fits AND a rays-up-and-down "enclosed in the sealed box" test passes
(that test is how it refuses to land in the void without knowing anything about the stage).
**Terra's Fracture** is no longer a projectile: it is an instant wind-cannon-shaped wave,
terrain-stopped, that hurls victims at the impact surface via velocity override (never a
teleport, so nobody can be pushed inside a wall). **Mason's Keystone** had a real bug — the
re-trigger gap (0.6) was shorter than the freeze (0.65), so anyone who fell in was re-frozen
forever; the gap is now derived (`freeze_time + FALL_GAP`) and paced to 3-4 freezes on a
straight fall-through. **Cerebelle and Slip changed colour** (dark violet / deep blue) to
clear the bright ends of their hue families for Voodoo and Siku. Fei got a cast puff and an
ult aura via the new reusable `HeroAura` effect (wind/surge/ward styles — the second wave's
buff windows are expected to reuse it). And the four new heroes exist as art + HeroData +
skeleton abilities, with `docs/NEW_HEROES.md` as their spec; `OPUS_PROMPT.md` gained the M7
kickoff line.

**Second wave built (2026-07-28, same session as the rework pass).** Systems before kits:
`grant_impulse_buff` (the buff-side twin of `impair_mult` — the two multiply at all three
launch sites, so buffed-and-impaired needs no special case), a `ContactSense` area with a
per-tick enemy scan, phasing as **per-pair collision exceptions** (not a layer edit — the
layer is also how terrain and every player-watching area finds the body), `clear_all_debuffs`,
`Ability.fires_while_stunned`, debuff immunity, the stomp ward, and the sleep stack system
with a real `Sleeping` state. Two rulings worth remembering: the stomp's own stun goes
through `_apply_stomp_stun` and **ignores immunity**, because nothing may make a body
unstompable; and the ward is consumed *inside* `receive_stomp` beside the grace early-out,
so victim authority stays the single path that decides a stomp. `StunBolt`'s flight was
extracted into a shared `BoltProjectile` rather than forked for Vesper's dart, and Voodoo's
phantom negative is a generated palette VARIANT of his own rig (a whole SpriteFrames swap,
because the grace blink already owns `modulate.a`).

**Owner playtest pass on the second wave + select screens (2026-07-28, later).** The pillar
bug was real and instructive: launch-first ordering did NOT stop the pillar's solid from
depenetrating Siku into the floor (one frame of launch is ~11px against an 80px column), so
launched bodies are now collision exceptions on the pillar until they physically clear it —
and the harness asserts her *position rises*, because her velocity was correct all through
the bug. Sleep got its final rules (see §3). Voodoo's windows and cooldown roughly doubled
with much bigger buffs; Phantom buffs run+dash but never the jump (a new dash-only buff on
Player), and his mask inverts with the rest of the skin. **Hero select was rebuilt
Smash-style** — one shared 12-tile grid with per-seat nested cursors, pick boxes with real
hero models flanking a VS mark, compressing at 3v3 — and **stage select draws hand-kept
layout miniatures** from new `preview` data in `STAGE_ROSTER` (drawing a card still never
instantiates a stage). `tools/screenshot_select.tscn` boots both screens and screenshots
them into `screenshots/` for eyeballing without a full match.

---

## 8. Open threads

Nothing is mid-edit; the tree is clean and green. Reasonable next moves, in the order that
makes sense:

1. **Feel-test all three stages** — the rebuilt Rooftop and Cryo layouts, Sunken Court's
   dash-gated roof platform, the taller jump, the perfect-slide window and Sai's kit all pass
   their harness checks, but only a human can say whether they're right.
2. **Merge `rooftop-rumble-layout-pass` into `main`** (or open a PR) once the owner has
   play-tested the branch — `main` is missing audio, pause, and the HUD rework.
3. **Settings persistence** (`user://`). Volume resets every run, and rebinding has nowhere to
   live; rebind UI + `user://input.cfg` belong in the same file. Per-match RNG seeding
   (`GameManager._ready`) is still a TODO.
4. **Feel-test the twelve-hero roster.** Every number in the rework pass and the second
   wave is a first implementation of the owner's notes. The ones most likely to be wrong:
   Voodoo's empowerment magnitudes, Vesper's stack timings (12-15s band) and how long
   6.5s of sleep actually *feels* on the receiving end, Siku's launch height, and whether
   Saint's ward reads as fair to the player who just landed a clean stomp.
5. The two remaining launch stages (Powerplant, Skyline Gardens) — `docs/MAPS.md` is the guide,
   and Sunken Court (§6b there) is the worked example of building one from a sketch.
6. `movement_config.tres` vs `movement_config.gd` defaults (§4) is worth resolving one way or
   the other before the numbers drift.
7. Sai's slash-through-terrain landing search wants human eyes on weird aims specifically
   (straight down through the roof, into a channel, at the outer wall).
8. One art follow-up left open: Vesper has no `sleep` pose (the Sleeping state reuses
   `stun`). The twelve-card hero select is resolved — it is a shared Smash-style grid now.
