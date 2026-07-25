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
├── assets/                    # Pixel art (characters/, abilities/, stages/, palettes/)
│   └── STYLE_GUIDE.md
└── tests/                     # GUT unit tests for pure-logic systems
```

## 2. Autoloads (singletons)

| Autoload | Responsibility |
|---|---|
| `GameManager` (`src/autoload/game_manager.gd`) | Match lifecycle: lobby config → round loop (hero select → stage select → combat → results). Owns the seeded RNG and the hero roster registry. |
| `MatchState` (`src/autoload/match_state.gd`) | Single source of truth for: per-player rosters, per-hero lives, eliminations, ultimate availability, round wins, coinflip/stage-pick ownership. Pure data + signals; no scene refs. Fully unit-testable. |
| `InputConfig` (`src/autoload/input_config.gd`) | Device detection (KBM vs controller), rebinding persistence (`user://input.cfg`), the R2+L2 ultimate chord resolver, and the shared aim-vector provider. `poll(player_id, body)` returns an `InputFrame` (`src/autoload/input_frame.gd`) — the one place gameplay reads inputs, so a rollback layer can swap the source (§9). |

**Rule:** scenes read `MatchState` and connect to its signals; only `GameManager` and combat-event emitters mutate it.

## 3. Player architecture

`player.tscn` (CharacterBody2D) — one instance per *player* (not per hero). Hero swaps re-skin and re-equip this body; they never respawn it (preserves position/velocity/stun per DESIGN §2.4).

```
Player (CharacterBody2D)            player.gd — public API + physics integration
├── Sprite/AnimatedSprite2D         swapped per hero skin
├── StateMachine (Node)             state_machine.gd
│   ├── Idle / Run / Skid
│   ├── Air (jump, fall, variable height, coyote, buffer, b-hop check)
│   ├── Dash                        charges, surface-parallel vs omni, air-consecutive lock
│   ├── WallSlide / WallJump        consecutive decay, aim tilt, perfect window
│   ├── PoleClimb
│   └── Stunned                     unified stun; exits into Grace timer on player.gd
├── HeadHurtbox (Area2D)            top 25%; disabled during grace
├── StompBox (Area2D)               bottom 20%; checks relative downward velocity
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
```
Abilities and terrain never touch state internals or velocity fields directly.

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
- `ground_accel()` / `air_accel()` — derived from `ground_redirect_time` so accel and redirect stay one knob.
- `can_dash()` / `consume_dash_charge()` — charge count plus the airborne-consecutive lock.
- `has_buffered_jump()` / `consume_jump_buffer()`, `wall_is_jumpable(normal)`, `build_momentum(delta)`.
- Contact bookkeeping the states read: `time_since_landing`, `time_since_wall_contact`, `wall_normal`, `wall_jump_chain`, `coyote_remaining`, `landing_settled`.

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
StompBox overlap + relative-velocity check (attacker's player.gd)
  → victim.receive_stomp(attacker)        # authoritative on victim
    → MatchState.life_lost(player_id, hero_id)
    → victim: apply_stun(stomp_stun), bounce impulse, start grace
    → attacker: stomp bounce (jump-height, hold-extendable)
  → MatchState emits:
       life_lost → HUD
       hero_eliminated (2nd life) → GameManager (auto-swap or spectate)
       round_won (all heroes of a team dead) → GameManager (results → next round)
```
Ultimates: `InputConfig` resolves the input → `AbilitySlot` asks `MatchState.try_spend_ultimate(player_id)` → only on `true` does the ult fire.

Wall-jump duels: contact window tracked in `player.gd` (`duel_window` frames); first `WallJump` input wins → `other.apply_stun(duel_stun)`; simultaneous → both get juiced impulse.

Movement also emits `perfect_window_hit(kind)` (`&"bhop"` / `&"walljump"`) — consumed by the playground overlay today, by VFX/SFX in M6.

## 6. Match flow (GameManager FSM)

`LOBBY → HERO_SELECT → STAGE_SELECT → ROUND_ACTIVE → ROUND_RESULTS → (loop | MATCH_RESULTS)`

- Stage pick ownership: round 1 = seeded coinflip winner; later = loser of previous round (`MatchState.stage_picker()`).
- Round reset: lives → 2×3, cooldowns cleared, ultimate restored, stage reloaded.

## 7. Milestone order (build in this order)

1. **M1 — Movement core**: player + state machine + configs + playground stage with flat ground/walls. Exit: b-hop chains and wall-jump chains feel good with debug overlay. *Implemented; awaiting the in-editor feel pass that closes the exit criteria.*
2. **M2 — Stomp loop**: stomp detection, lives, stun/grace/bounce, player-as-terrain + duels. Two local players, KBM + controller. Exit: a playable 1v1 with 1 dummy hero.
3. **M3 — Match structure**: MatchState, rounds, hero select (3 picks), swap, ult economy, HUD.
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

- All gameplay on the 60 Hz physics tick; no `_process` gameplay; no wall-clock time; seeded RNG only.
- Inputs are already abstracted through `InputConfig` — a future rollback layer replaces "read device" with "read input frame."
- Avoid physics interactions that depend on Godot's non-deterministic contact ordering where cheap (e.g., resolve duels by input frame, not contact callbacks order).

## 10. Testing

- **GUT** (Godot Unit Test addon) for: MatchState (lives/elim/round-win/ult economy), cooldown ticking incl. benched heroes, stun refresh rule, coinflip/stage-picker logic. Stubs in `tests/`.
- Feel is tested by humans in `playground.tscn` (debug overlay shows state, velocity, momentum charge, dash charges, perfect-window hits).
