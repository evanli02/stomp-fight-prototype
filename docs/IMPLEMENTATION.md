# IMPLEMENTATION.md — Architecture & Maintenance Guide

How Overstomp is structured in Godot 4.4+, how the pieces talk to each other, the order to build them in, and how to keep this document truthful.

---

## 1. Repository layout

```
overstomp/
├── project.godot              # Godot project (input map, autoloads, physics tick)
├── CLAUDE.md                  # Agent rules — read first
├── SKILL.md                   # Agent workflows for this repo
├── docs/
│   ├── DESIGN.md              # Authoritative game spec
│   ├── IMPLEMENTATION.md      # This file
│   ├── SETUP.md               # Environment install guide
│   └── OPUS_PROMPT.md         # Kickoff prompt for implementation sessions
├── src/
│   ├── autoload/              # GameManager, MatchState, InputConfig (singletons)
│   ├── config/                # movement_config.tres, combat_config.tres (created M1)
│   ├── player/                # player.tscn/.gd + states/ (movement state machine)
│   ├── heroes/                # HeroData resources + abilities/ components
│   ├── stage/                 # Stage scenes + terrain/ element scenes
│   └── ui/                    # HUD, hero select, stage select, lobby
├── assets/                    # Pixel art (characters/<hero>/, abilities/, stages/, palettes/)
│   ├── STYLE_GUIDE.md
│   └── tools/                 # pixel.py canvas + the two generators (stdlib only)
└── tests/                     # GUT unit tests for pure-logic systems
```

## 2. Autoloads (singletons)

| Autoload | Responsibility |
|---|---|
| `GameManager` (`src/autoload/game_manager.gd`) | Match lifecycle: lobby config → round loop (hero select → stage select → combat → results). Owns the seeded RNG, the hero roster registry (`hero_data(id)`, cached), and the results countdown. **Ticks ability cooldowns, and only during `ROUND_ACTIVE`** — so nothing burns down behind a results banner. Holds no scene references. |
| `MatchState` (`src/autoload/match_state.gd`) | Single source of truth for: per-player rosters, active hero, per-hero lives, eliminations, **per-hero ability cooldowns**, ultimate availability, round wins, coinflip/stage-pick ownership. Pure data + signals; no scene refs. Fully testable without a tree. |
| `InputConfig` (`src/autoload/input_config.gd`) | Per-seat action namespaces (`p0_jump`, `p1_jump`, … — always via `action(player_id, base)`), device assignment (`assign_device`, seat 0 KBM / seat 1 pad by default), the R2+L2 ultimate chord resolver, and the shared aim-vector provider. `poll(player_id, body)` returns an `InputFrame` (`src/autoload/input_frame.gd`) — the one place gameplay reads inputs, so a rollback layer can swap the source (§9) — and is memoised per tick, so the chord state advances exactly once a frame. Rebind persistence to `user://input.cfg` lands with the rebind UI (M6). |

**Rule:** scenes read `MatchState` and connect to its signals; only `GameManager` and combat-event emitters mutate it.

## 3. Player architecture

`player.tscn` (CharacterBody2D) — one instance per *player* (not per hero). Hero swaps re-skin and re-equip this body; they never respawn it (preserves position/velocity/stun per DESIGN §2.4).

```
Player (CharacterBody2D)            player.gd — public API + physics integration
├── Sprite (AnimatedSprite2D)       SpriteFrames swapped per hero by set_hero()
├── StateMachine (Node)             state_machine.gd
│   ├── Idle / Run / Skid
│   ├── Crouch / Slide              half-height body; slide bleeds speed, jumps flat
│   ├── Air (jump, fall, variable height, coyote, buffer, b-hop check)
│   ├── Dash                        charges, surface-parallel vs omni, air-consecutive lock
│   ├── WallSlide / WallJump        consecutive decay, aim tilt, perfect window
│   ├── PoleClimb
│   └── Stunned                     unified stun; exits into Grace timer on player.gd
├── BodyShape / BodyShapeCrouch     one enabled at a time; crouch is half height,
│                                   bottom-aligned, swapped via set_deferred
├── HeadHurtbox (Area2D)            top 25%; disabled during grace
│   └── HeadShape / HeadShapeCrouch  the crouched box is the top 25% of the short body
├── StompBox (Area2D)               bottom 20% + 6px past the feet; relative fall speed
│                                   (bodies stop on contact, so at exactly the
│                                   design box the two rects meet on a line)
├── BodyShape (CollisionShape2D)    also what makes players terrain to each other
├── AbilitySlot (Node)              current hero's Ability component (re-parented on swap)
└── AimPivot (Node2D)               live aim vector from InputConfig
```

### Player public API (what abilities/terrain may call)
```gdscript
apply_impulse(v: Vector2)                 # additive
set_velocity_override(v: Vector2)         # e.g. springs, portals
apply_stun(duration: float)               # refresh rule: max(remaining, new)
request_state(state_name: StringName)     # e.g. Skyla double-jump requests Air with params
grant_speed_buff(mult: float, dur: float)
set_head_hurtbox_enabled(on: bool)        # grace / Wisp ult only
set_hero(data: HeroData)                  # re-skin in place; never respawns, never touches movement
equip_hero(hero_id: StringName)           # skin + ability components for that hero
try_swap() / try_ability() / try_ultimate()   # all three refuse while stunned
play_elimination()                        # one-shot confetti pop, holds the sprite until it ends
set_crouched(on: bool)                    # half-height body + matching head box
start_spawn_protection()                  # head hurtbox off until timeout OR first action
respawn_at(pos: Vector2)                  # body + movement bookkeeping only; lives are MatchState's
```
Abilities and terrain never touch state internals or velocity fields directly.

### Animation
Each `PlayerState` returns an animation name from `animation()`; `StateMachine.current_animation()` forwards the running state's answer and `player.gd` plays it in `_process`. The state machine already owns what the body is doing, so it owns how the body looks doing it — no state-name-to-animation lookup table anywhere.

Two cases resolve on the player instead, both because they outlive the state that caused them: the landing squash (`land`, first `LAND_ANIM_TIME` after a landing, while the state is already Idle/Run) and one-shots like `pop`, which hold the sprite until they finish. `Air` shows a launch pose (`wall_jump` / `slide_jump`) passed in as a param while rising, then falls back to `rise`/`fall`.

Art and its SpriteFrames are generated together (`assets/tools/generate_characters.py`) so sheets and frame counts cannot drift apart. See `assets/STYLE_GUIDE.md`.

### Tick ownership
`Player._physics_process` drives the frame: sample `InputFrame` → tick timers →
`StateMachine.tick(delta)` (states set velocity) → `move_and_slide()` → post-move
surface bookkeeping. The machine deliberately has **no** `_physics_process` of its
own so the body moves exactly once, after the running state has finished with
`velocity`. `StateMachine.setup(player)` wires child states and enters the initial
state; it is called from `Player._ready()` so the player's `@onready` refs are live.

### Movement helpers (shared, in `player.gd`)
- `perfect_window_check(time_since_contact, window)` — one implementation backing b-hop **and** perfect wall jump.
- `momentum` model: `velocity.x` plus a `momentum_charge: float` (0..1) that scales the run-speed cap; built on ground time, preserved by perfect windows, decayed by normal landings/skids.
- `speed_cap()` — `run_speed_base..run_speed_cap` by momentum, times the dash boost while it lasts.
- `ground_accel()` (startup, from `ground_accel_time`) vs `ground_redirect_accel()` (flips and skid braking, from `ground_redirect_time`). `Run` picks between them by whether the input opposes current velocity. `air_accel()` scales the *redirect* rate, so making startup heavier did not quietly weaken air control.
- `begin_wall_jump()` — claims the wall jump and returns the chain index for that wall face (collider id + side). A different face resets to zero; landing clears the owner entirely.
- `can_dash()` / `consume_dash_charge()` — charge count plus the airborne-consecutive lock.
- `has_buffered_jump()` / `consume_jump_buffer()`, `wall_is_jumpable(normal)`, `build_momentum(delta)`.
- Contact bookkeeping the states read: `time_since_landing`, `time_since_wall_contact`, `wall_normal`, `wall_player` (the other player being used as a wall, if any), `wall_jump_chain`, `coyote_remaining`, `landing_settled`.
- `fall_speed_memory` — downward speed carried into the current contact, held for `stomp_fall_memory_time` and only charged while airborne. Stomp detection reads it instead of `velocity.y`, because the collision that ends a fall zeroes the velocity a frame before the feet/head areas report their overlap.

## 4. Terrain contract

Every element in `src/stage/terrain/` extends `TerrainElement` (`terrain_element.gd`):

```gdscript
class_name TerrainElement extends Node2D
## Override any that apply. Elements are self-contained scenes.
func on_body_entered(player: Player) -> void: pass
func on_body_exited(player: Player) -> void: pass
func physics_effect(player: Player, delta: float) -> void: pass  # wind, conveyor, ice
```
Elements express themselves exclusively through the Player public API (§3). Stun values and forces are `@export` vars pre-set in each scene, sourced from `combat_config.tres` defaults.

Implemented (stub) elements: pole, ice, stun_line, jump_spring, speed_pad, portal, wind_zone, explosion. Extras from DESIGN §6.2 (conveyor, crumble, sticky wall, one-way, rotator, bumper) follow the same contract.

## 5. Combat event flow (signal map)

```
StompBox overlap + fall-speed check (attacker's player.gd, post-move, in player_id order)
  → victim.receive_stomp(attacker)        # authoritative on victim
    → MatchState.lose_life(player_id, hero_id)
    → victim: apply_stun(stomp_stun), bounce impulse, start grace
    → attacker: on_stomp_landed → Air with an impulse override (hold-extendable),
                air-dash lock and wall-jump chain cleared, stomp_landed emitted
  → MatchState emits:
       life_lost → HUD
       hero_eliminated (2nd life) → GameManager (auto-swap or spectate)
       round_won (all heroes of a team dead) → GameManager (results → next round)
```
A stomp landed while the attacker is stunned applies the bounce but does not return control. `lose_life` on an already-empty hero is a no-op.

Hero elimination continues into the swap flow (DESIGN 3.3): the arena hears `hero_eliminated`, plays the confetti pop, waits `RESPAWN_DELAY`, then brings in `MatchState.next_living_hero()` at that seat's spawn with protection. If the trio is empty instead, `round_won` is already on its way.

Ultimates: `InputConfig` resolves the input → the equipped ultimate asks `MatchState.try_spend_ultimate(player_id)` → only on `true` does it fire. Abilities read and write cooldowns through `MatchState`, keyed by player **and hero**, because the ability node is freed the moment its hero is swapped out and cannot be the thing remembering. Swap, ability, and ultimate are all refused while stunned (CLAUDE.md checklist).

Wall-jump duels (`player.gd`, `claim_wall_duel`): jumping off another player opens a claim stamped with the physics frame. If the other player answers within `duel_window_frames`, both are juiced (`duel_juice_mult`) and nobody is stunned — the earlier jumper is paid as an impulse delta. Unanswered, the claim resolves at the end of the window with `other.apply_stun(stun_duel_loss)`. The stun is deferred precisely so a tie is reachable; applying it with the jump would stun the loser out of the input that ties it. Resolution is by frame number, never by contact order (§9).

Movement also emits `perfect_window_hit(kind)` (`&"bhop"` / `&"walljump"` / `&"duel"`) — consumed by the debug overlays today, by VFX/SFX in M6.

## 6. Match flow (GameManager FSM)

`LOBBY → HERO_SELECT → STAGE_SELECT → ROUND_ACTIVE → ROUND_RESULTS → (loop | MATCH_RESULTS)`

- Stage pick ownership: round 1 = seeded coinflip winner; later = loser of previous round (`MatchState.stage_picker()`).
- Round reset: lives → 2×3, cooldowns cleared, ultimate restored, active hero back to the first pick.
- **Who calls what:** the arena owns the bodies and calls `GameManager.end_round()` when it has shown the result; GameManager holds `RESULTS_TIME`, then either starts the next round (`round_started`) or ends the match (`match_won`). GameManager never touches a node — that separation is what lets the match harness drive whole rounds without a stage.
- Implemented as of M3: hero select, `start_match`, the round loop, results countdown, best-of resolution. **Not yet: stage select** — it needs more than one stage to mean anything, so it lands with M5.
- **Scene ownership**: `main.tscn` (`src/main.gd`) is the shell that turns phases into scenes — hero select, then the arena. It is deliberately tiny, and nothing else routes through it: arenas and harnesses instantiate their own scenes directly. An arena finding `MatchState.players` empty starts its own match from a fallback roster, which is what keeps F6-into-a-stage and the harnesses working without a shell.
- **Hero select** (`src/ui/hero_select.tscn`) polls per-seat input on the *physics* tick, because `InputConfig` memoises one `InputFrame` per physics tick and polling from `_process` would replay the same "just pressed" edge once per rendered frame. A `SELECT_TIME` countdown auto-fills any seat that has not finished — which is also what covers a seat with no controller plugged in.

## 7. Milestone order (build in this order)

1. **M1 — Movement core**: player + state machine + configs + playground stage with flat ground/walls. Exit: b-hop chains and wall-jump chains feel good with debug overlay. *Mechanics implemented and verified headlessly (2026-07-25); the human feel pass in `playground.tscn` still has to sign off.*
2. **M2 — Stomp loop**: stomp detection, lives, stun/grace/bounce, player-as-terrain + duels. Two local players, KBM + controller. Exit: a playable 1v1 with 1 dummy hero. *Mechanics implemented and verified headlessly (2026-07-25) in `src/stage/duel.tscn`; the human 1v1 pass still has to sign off. Not yet done here: hero swap, abilities, and the auto-swap/respawn a 3-hero roster needs (all M3+).*
3. **M3 — Match structure**: MatchState, rounds, hero select (3 picks), swap, ult economy, HUD. *Done and verified headlessly (2026-07-26): 3-hero rosters, hero select with auto-fill, free swap, per-hero cooldowns ticking while benched, one-ult-per-round, auto-swap and respawn on elimination, the round/results/best-of loop, and an in-round HUD. Stage select is deferred to M5, when there is more than one stage to pick between. The human pass on the full flow still has to sign off.*
4. **M4 — Vertical-slice heroes**: Deadeye, Skyla, Mason, Nova.
5. **M5 — Terrain + 2 stages**: contract + 8 core elements; Rooftop Rumble, Cryo Lab.
6. **M6 — Formats & polish**: 2v2/3v3, stage select flow, Bo3/Bo5, VFX/SFX pass, remaining heroes/stages.

## 8. How to update this document

Update **in the same commit** as the code change:
- New/changed **autoload** → §2 table.
- New **state** or transition → §3 tree (and mention the exit conditions).
- New **public API** method on Player → §3 API list (abilities depend on this being complete).
- New **terrain element** → §4 implemented list.
- New **signal** in the combat/match flow → §5 map.
- Milestone reached or reordered → §7 (mark done with ✅ and date).
Keep sections terse; this doc is a map, not a manual. Detailed rationale belongs in DESIGN.md or commit messages. If a section exceeds ~40 lines, split into `docs/impl/<topic>.md` and leave a pointer.

## 9. Networking posture (future-proofing, not building yet)

- All gameplay on the 60 Hz physics tick; no `_process` gameplay; no wall-clock time; seeded RNG only. `GameManager._ready()` asserts the tick rate: `project.godot` states it explicitly, but the editor prunes settings that match the current engine default when it saves, so the file alone is not a guarantee.
- Inputs are already abstracted through `InputConfig` — a future rollback layer replaces "read device" with "read input frame."
- Avoid physics interactions that depend on Godot's non-deterministic contact ordering where cheap (e.g., resolve duels by input frame, not contact callbacks order).

## 10. Testing

- **GUT** (Godot Unit Test addon) for: MatchState (lives/elim/round-win/ult economy), cooldown ticking incl. benched heroes, stun refresh rule, coinflip/stage-picker logic. Stubs in `tests/`. GUT is a local install (`docs/SETUP.md`); until it is installed, `tests/test_match_state.gd` logs a parse error on project load and nothing else.
- Feel is tested by humans in `playground.tscn` (movement) and `duel.tscn` (1v1); both carry a debug overlay — state, velocity, momentum charge, dash charges, perfect-window hits, and in the duel stage lives, stun, grace, and a combat event log.
- **Headless harnesses** live in `tests/` and are the regression net under the physics code. Neither is GUT: both need a live scene tree, physics ticks, and real collision. Non-zero exit on failure.
  - `movement_harness.tscn` — DESIGN 4 numbers: jump heights, momentum decay, b-hop preservation, dash charges/air lock, wall-jump chain decay and aim tilt, ceilings. Run after touching `src/player/`.
  - `combat_harness.tscn` — DESIGN 3 rules: what does and does not register as a stomp, life/stun/grace/bounce, the anti-chain grace, elimination into auto-swap, and duel resolution. Run after touching stomp, stun, or duel code.
  - `match_harness.tscn` — DESIGN 2 rules: hero-select pick rules (no duplicates in one trio, duplicates across players, undo, auto-fill), rosters, swap validation and cycling, swap preserving position/velocity, stun blocking swap and ult, cooldowns ticking while benched, the one-ult-per-round economy, round win, and the reset between rounds. Run after touching MatchState, GameManager, hero select, or the swap path.
  - Teleporting a body into place inside a harness needs a settle frame. If whatever it was resting on has moved, the next `move_and_slide()` can depenetrate it across the arena with its velocity untouched — `combat_harness.place()` re-asserts the position a frame later for exactly this reason.
  - `Godot --headless --path . res://tests/<harness>.tscn`. A newly added `class_name` needs `Godot --headless --path . --import` first, or the harness cannot see the class.
- **Generated art** has a loader check: `Godot --headless --path . --script res://tests/verify_frames.gd` confirms every hero's SpriteFrames resource parses and holds every animation the states can ask for. Run it after regenerating characters. The movement harness separately asserts that no state names an animation the sheets lack.
- Harness inputs go through `InputConfig.action(player_id, base)`. The `aim_*` actions are unbound on KBM specifically so a harness can pin an exact aim; without that, aim falls back to a mouse pointer that headless leaves at the origin.
