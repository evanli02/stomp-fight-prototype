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
│   ├── MAPS.md                # Stage-building guide: reach envelope, terrain catalog
│   ├── PLAYTEST.md            # Remote playtesting: streaming and online
│   ├── ITCH.md                # itch.io page, butler, the online support matrix
│   ├── NEW_HEROES.md          # Authoritative spec for the second hero wave (M7)
│   └── OPUS_PROMPT.md         # Kickoff prompt for implementation sessions
├── src/
│   ├── autoload/              # GameManager, MatchState, InputConfig (singletons)
│   ├── config/                # movement_config.tres, combat_config.tres (created M1)
│   ├── player/                # player.tscn/.gd + states/ (movement state machine)
│   ├── heroes/                # HeroData resources + abilities/ + effects/
│   ├── stage/                 # match_stage.gd base + stage scenes + terrain/ elements
│   └── ui/                    # HUD, lobby, hero select, stage select, per-player overlays
├── assets/                    # Pixel art (characters/, abilities/, stages/, palettes/) + sfx/
│   ├── STYLE_GUIDE.md
│   └── tools/                 # pixel.py canvas + character/placeholder/sfx generators (stdlib only)
├── tests/                     # Headless harnesses (movement, combat, match, terrain)
├── tools/                     # build_windows.ps1, build_itch.ps1, measure_reach, screenshot_*
└── export_presets.cfg         # Windows Desktop + Web exports (committed; no secrets)
```

## 2. Autoloads (singletons)

| Autoload | Responsibility |
|---|---|
| `GameManager` (`src/autoload/game_manager.gd`) | Match lifecycle: lobby config → round loop (hero select → stage select → combat → results). Owns the seeded RNG, the hero roster registry (`hero_data(id)`, cached), the stage registry (`STAGE_ROSTER`, `stage_ids()`, `stage_info()`, `stage_scene()`, `current_stage`), and the results countdown. **Ticks ability cooldowns, and only during `ROUND_ACTIVE`** — so nothing burns down behind a results banner. Holds no scene references. |
| `MatchState` (`src/autoload/match_state.gd`) | Single source of truth for: per-player rosters, active hero, per-hero lives, eliminations, **per-hero ability cooldowns**, ultimate availability, round wins, coinflip/stage-pick ownership. Pure data + signals; no scene refs. Fully testable without a tree. |
| `Audio` (`src/autoload/audio.gd`) | Every sound the game makes, and the only thing allowed to make one. Cues are **named**, not paths (`Audio.play(&"stomp")`), so retuning the mix or swapping a file is a change in one place. Wired to existing signals wherever one exists (`life_lost`, `round_won`, `ultimate_spent`, …) rather than to call sites, so a new way to lose a life keeps its sound. Fixed pool of 24 voices, 0.04s per-cue dedupe. **Never affects gameplay**: nothing runs on the physics tick and an unknown cue is a silent no-op, both asserted in `match_harness`. |
| `InputConfig` (`src/autoload/input_config.gd`) | Per-seat action namespaces (`p0_jump`, `p1_jump`, … — always via `action(player_id, base)`), three device profiles (`KBM`, `KBM_ALT` on arrows+numpad for streamed play, `PAD`) and assignment for up to six local seats (`assign_device(seat, device, pad_index)`; seat 0 KBM, seats 1-5 take pads 0-4, each event stamped with its joypad index so a third pad drives its own seat), the R2+L2 ultimate chord resolver, and the shared aim-vector provider. `poll(player_id, body)` returns an `InputFrame` (`src/autoload/input_frame.gd`) — the one place gameplay reads inputs, so a rollback layer can swap the source (§9) — and is memoised per tick, so the chord state advances exactly once a frame. Rebind persistence to `user://input.cfg` lands with the rebind UI (M6). |
| `Net` (`src/autoload/net.gd`) | Online play (§9a): ENet host/join, remote seat claiming, the client→host InputFrame relay, host→client snapshots and the MatchState mirror that re-emits its signals. OFFLINE is a hard no-op — every handler checks mode first, so local play never pays for it. |

**Rule:** scenes read `MatchState` and connect to its signals; only `GameManager` and combat-event emitters mutate it.

## 3. Player architecture

`player.tscn` (CharacterBody2D) — one instance per *player* (not per hero). Hero swaps re-skin and re-equip this body; they never respawn it (preserves position/velocity/stun per DESIGN §2.4).

Body is **22×34** (frames are 32×36). The sprite canvas is 32 wide but the character is drawn ~18px across inside it, and a 32-wide box left a visible gap between two players who were supposedly touching. Width is shared by the body, head hurtbox, and stompbox — heroes are identical here (CLAUDE.md rule 3).

```
Player (CharacterBody2D)            player.gd — public API + physics integration
├── Sprite (AnimatedSprite2D)       SpriteFrames swapped per hero by set_hero()
├── StateMachine (Node)             state_machine.gd
│   ├── Idle / Run / Skid
│   ├── Crouch / Slide              half-height body; slide bleeds speed, jumps flat
│   ├── Air (jump, fall, variable height, coyote, buffer, b-hop check)
│   ├── Dash                        charges, surface-parallel vs omni, air-consecutive lock
│   ├── WallSlide / WallJump        consecutive decay, aim tilt, perfect window
│   ├── Swing                       Sai's pendulum; 5 redirects then forced release
│   ├── Slam                        Terra: hover, plummet; head hits resolve as stomps
│   ├── Reel                        Sai: haul up the rope, stopping short of the hook
│   ├── Recall                      Slip: blink back to the anchor, brief settle
│   ├── PoleClimb                   ride down, down+jump to drop, dash to plummet
│   ├── Sleeping                    Vesper: walk-only crawl, momentum pinned at 0,
│   │                               head hurtbox LIVE; a stun suspends and returns
│   └── Stunned                     unified stun; exits into Grace timer on player.gd
├── BodyShape / BodyShapeCrouch     one enabled at a time; crouch is half height,
│                                   bottom-aligned, swapped via set_deferred
├── ContactSense (Area2D)           enemy-body sense, monitoring OFF unless a
│                                   window that cares about touching is running
│                                   (Voodoo); reaches past the body because
│                                   players are terrain and never overlap
├── HeadHurtbox (Area2D)            top 25%; disabled during grace
│   └── HeadShape / HeadShapeCrouch  the crouched box is the top 25% of the short body
├── Status (Node2D)                 dash pips + ability cooldown over the head;
│                                   sibling of Sprite so it does not flip
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
apply_slow(mult, dur)                     # speed-cap multiplier; strongest wins
apply_impairment(mult, dur)               # scales jump/dash/wall-jump; 0 disables
apply_disrupt(dur)                        # EMP: no dash, no ability, no ultimate
apply_freeze(dur)                         # pinned mid-air, gravity suspended
input_source: Callable                    # stands in for the device poll (dummies today, rollback later)
grant_impulse_buff(mult, dur)             # buff-side twin of impairment; launch_mult() multiplies both
grant_dash_buff(mult, dur)                # dash-only (Voodoo's Phantom: run+dash, never the jump)
grant_air_jumps(n, dur, accent, impulse)  # granted mid-air jumps, refreshed per airtime
can_air_jump() / consume_air_jump()       # spent by PlayerState.try_air_jump; pays for its own puff
grant_debuff_immunity(dur)                # Saint: every apply_* above becomes a no-op
grant_stomp_ward(dur)                     # Saint: next stomp spends the blessing, not the life
clear_all_debuffs()                       # Saint: stun/slow/impair/disrupt/freeze/sleep/stacks/tags
add_sleep_stack(life) -> int              # Vesper; stacks share one resettable timer
consume_sleep_stacks() / apply_sleep(dur) # the Sleeping state; head hurtbox stays LIVE
begin_phasing(dur) / end_phasing()        # Voodoo; per-pair collision exceptions, symmetric
begin_contact_debuff(...) / begin_contact_stun(...)  # Voodoo; per-tick enemy-overlap scan
apply_skin_override(frames) / clear_skin_override()  # Voodoo's phantom negative
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

## 3a. Stage architecture

Every playable stage is `MatchStage` (`src/stage/match_stage.gd`) plus a subclass that supplies **only** its layout, terrain and palette. The base owns the parts that are the same everywhere: seats and spawns, the round loop, respawn timers, the MatchState/GameManager signal wiring, the sealed-box draw, and the debug overlay.

Subclass hooks: `stage_id()`, `arena_size()`, `spawns()`, `arena_blocks()`, `build_terrain()`, `sky_bands()`, `horizon()`, `ground_fill()`, `ground_texture()`, `cap_color()`. `spawns()` returns **one anchor per team**, not one per player: the base spreads teammates around their team's anchor (`spawn_for(seat)`, centred so a team of one lands exactly on it), so adding a format never means editing a stage.

Every stage also carries a `StageGrid` child (`src/ui/stage_grid.gd`), hidden until **F3**: tile grid with coordinates, spawn markers, and the reach envelope drawn around player 1. Its constants come from `tools/measure_reach.gd` and must be re-run and updated together after a movement tune, or the overlay starts lying about what is reachable. See `docs/MAPS.md`.

**Seating is format-driven.** A stage file ships two Player nodes because 1v1 is the common case and the harnesses reach for `%Player1`/`%Player2` by name; `_seat_players()` clones the rest up to `GameManager.seat_count()`. A stage also guards every MatchState signal through `body_for(player_id)`, which returns null for a seat it has no body for — MatchState is global and a stage is not, so a stage built for a smaller format than the one registered receives signals for players it does not own. The base never reads a subclass field directly, so a stage may compute its layout however it likes. Two ship today — `duel.tscn` (Rooftop Rumble) and `cryo_lab.tscn` — and each is under 90 lines because of the split.

Stage collision is still a list of `Rect2` built in code by `Arena` (`arena.gd`) rather than a TileMap: the geometry stays retunable between runs without opening the editor, and the harnesses assert against a plain list. `Arena.sealed_box()` is what makes "stages are sealed" (DESIGN 6.1) true by construction rather than by inspection.

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

Two live TerrainElements ship in `src/heroes/effects/`, both placed by Mason. `BumperBlock` (ability) is a **solid** StaticBody2D wrapped in a slightly larger Area2D: the hitbox has to reach past the solid core, because once the core has stopped a player their velocity is already gone and there is nothing left to reflect. It bounces everyone, Mason included — terrain does not take sides. `FreezeBlock` (ultimate) is pass-through for its owner's team and freezes anyone else.

Both re-scan overlaps every physics tick with a per-player re-trigger gap rather than listening for `body_entered`. A player already inside an area cannot "enter" it again, which is exactly how the first version let people walk through.

**The base owns detection.** `TerrainElement` builds its own Area2D from an exported `size` and re-scans overlaps every physics tick, synthesising `on_body_entered` / `on_body_exited` / `physics_effect` from the scan. It does not use Godot's enter/exit signals: a body already inside an area cannot "enter" it again, and half these elements care about bodies sitting still inside them. Elements override behaviour only, plus `tick()` for logic that needs no body (explosion timers).

`StunLine` also carries an optional duty cycle (`cycle_time`, `on_ratio`, `phase_offset`, `warn_time`) that turns a tripwire into a timed laser — stagger phases across several to make a grid a rhythm rather than a set of walls. (Cryo Lab used this before its rebuild; no shipped stage currently does, but the harness still covers it.) A timed line applies its stun from `physics_effect` rather than `on_body_entered`, because the case that matters is the body that walked in while the line was dark and is still standing there when it comes back on. Always-on is the default.

All eight core elements are implemented (M5): pole, ice, stun_line, jump_spring, speed_pad, portal, wind_zone, explosion. Extras from DESIGN §6.2 (conveyor, crumble, sticky wall, one-way, rotator, bumper) follow the same contract.

Two things terrain authors need to know:
- **A launch must leave the grounded state.** `Idle` and `Run` set `velocity.y = 0` every frame a body is on the floor, so a spring that only writes velocity is erased before it moves anyone. `JumpSpring` calls `request_state(&"Air")` for exactly this reason.
- **Ice is one number.** It asserts `Player.apply_surface_slip()` every tick a body is on it; the player decays `surface_slip` on its own, so stepping off restores grip without the element noticing. Slip feeds ground acceleration, friction, the b-hop window, and the speed cap together.

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

Abilities spawn their effects through `Player.spawn_effect()`, which parents them to the **stage**, never to the player: a bolt or a placed block must not ride the body that made it, and a placed block outlives a hero swap (DESIGN 2.4). Targets come from the `players` group sorted by `player_id`, never from scene order (§9).

Two ultimates modify their hero's *basic* ability instead of doing anything themselves, through two small hooks on `Ability`: `grant_cooldown_override(value, duration)` (Skyla — her cooldown becomes 1 s for a window) and `reset_cooldown()` (Deadeye — refund, plus a one-shot empowerment stored on the bolt). Neither ultimate duplicates how the ability works.

Ultimates: `InputConfig` resolves the input → the equipped ultimate asks `MatchState.try_spend_ultimate(player_id)` → only on `true` does it fire. Abilities read and write cooldowns through `MatchState`, keyed by player **and hero**, because the ability node is freed the moment its hero is swapped out and cannot be the thing remembering. Swap, ability, and ultimate are all refused while stunned (CLAUDE.md checklist).

Wall-jump duels (`player.gd`, `claim_wall_duel`): jumping off another player opens a claim stamped with the physics frame. If the other player answers within `duel_window_frames`, both are juiced (`duel_juice_mult`) and nobody is stunned — the earlier jumper is paid as an impulse delta. Unanswered, the claim resolves at the end of the window with `other.apply_stun(stun_duel_loss)`. The stun is deferred precisely so a tie is reachable; applying it with the jump would stun the loser out of the input that ties it. Resolution is by frame number, never by contact order (§9).

Movement also emits `perfect_window_hit(kind)` (`&"bhop"` / `&"walljump"` / `&"duel"`) — consumed by the debug overlays today, by VFX/SFX in M6.

## 6. Match flow (GameManager FSM)

`LOBBY → HERO_SELECT → STAGE_SELECT → ROUND_ACTIVE → ROUND_RESULTS → (loop | MATCH_RESULTS)`

- Stage pick ownership: round 1 = seeded coinflip winner; later = loser of previous round (`MatchState.stage_picker()`).
- Round reset: lives → 2×3, cooldowns cleared, ultimate restored, active hero back to the first pick.
- **Who calls what:** the arena owns the bodies and calls `GameManager.end_round()` when it has shown the result; GameManager holds `RESULTS_TIME`, then either starts the next round (`round_started`) or ends the match (`match_won`). GameManager never touches a node — that separation is what lets the match harness drive whole rounds without a stage.
- Implemented: hero select, stage select, `start_match`, the round loop, results countdown, best-of resolution.
- **Stage registry**: `GameManager.STAGE_ROSTER` maps a stage id to its scene *and* its display name, blurb, feature list and accent. The metadata lives there rather than on the stage script so the select screen can describe a stage without instantiating it — instantiating one builds geometry, spawns two bodies and starts a match, which is not something a menu should do to draw a card. A stage script declares only its `stage_id()` and reads its name back out of the registry, so there is still one source of truth.
- **Lobby** (`src/ui/lobby.tscn`) is the first screen and the only one that decides how many seats exist. Players join by pressing a button on the device they want; the lobby reads the **raw event**, not a namespaced action, because before a device has a seat it has no actions — and over Steam Remote Play Together each guest's controller arrives as a virtual pad whose id nobody can predict. `InputConfig.claim_seat(device, pad_index)` binds by actual joypad id and refuses a device that is already seated. Every seat must be filled to start: an undriven body is a free life.
- **Format**: `GameManager.team_size` (1/2/3) is the whole of "play 2v2". Everything downstream derives from it — `seat_count()`, `team_of_seat()` (seats are allocated in **blocks**: 0..team_size-1 are team 0), `index_in_team()`, `seat_teams()`, and `stage_picker_seat()` (DESIGN 2.2 gives the pick to a *team*; the first seat on it holds the cursor). The lobby sets it before `begin_hero_select()`.
- **Stage select is opt-in**: `start_match(rosters, teams, use_stage_select)` defaults to *false*, which sends harnesses and F6-into-a-stage boots straight into a round — they are already sitting in a stage, so asking them which one to load would deadlock. The shell passes `true`, and from then on every round routes back through `STAGE_SELECT` before `start_round()`.
- **Scene ownership**: `main.tscn` (`src/main.gd`) is the shell that turns phases into scenes — hero select, stage select, then the stage. It is deliberately tiny, and nothing else routes through it: stages and harnesses instantiate their own scenes directly. A stage finding `MatchState.players` empty starts its own match from a fallback roster, which is what keeps F6-into-a-stage and the harnesses working without a shell. The shell swaps the stage in on `round_started`, **not** on the `ROUND_ACTIVE` phase change: a stage's `_ready` spawns the round itself when it finds the signal has already gone out, and arriving one step later is what makes that the branch it takes.
- **Pause** (`src/ui/pause_menu.tscn`) is added once by the shell and never swapped out - it outlives every screen and must not be what `_show()` frees. It runs `PROCESS_MODE_ALWAYS`, which is the whole trick: pausing the tree is what stops the bodies, the cooldowns and the results countdown, so the node that has to undo that pause must opt out of it. `Audio` is ALWAYS for the same reason, so the volume slider is audible while you drag it. Pause is the one action that is **not** per seat (`InputConfig.PAUSE`, Escape + Start on device -1), and any seat can drive the menu - six people share one screen and making everyone wait on whoever holds the pausing pad is worse than the occasional argument over the cursor. Restart goes through `GameManager.restart_match()` rather than a fresh `start_match` so it does not silently drop stage-select routing; quit goes through `return_to_lobby()`, which takes the rosters with it.
- **Stage select** (`src/ui/stage_select.tscn`) polls only the picking seat, on the physics tick for the same reason hero select does, and has no countdown either. Its cursor starts on the stage already loaded, so "keep playing here" is the zero-input answer and the timeout never feels like it stole a pick.
- **Hero select** (`src/ui/hero_select.tscn`) polls per-seat input on the *physics* tick, because `InputConfig` memoises one `InputFrame` per physics tick and polling from `_process` would replay the same "just pressed" edge once per rendered frame. Neither select screen has a countdown right now: hero select waits until every seat has its three and stage select waits for the picking seat. The lobby is what makes that safe - a seat only exists once a real device claimed it, so there is no longer such a thing as a seat that will never answer. Hero select names who it is still waiting on, so a stalled pick does not read as a hang.

## 7. Milestone order (build in this order)

1. **M1 — Movement core**: player + state machine + configs + playground stage with flat ground/walls. Exit: b-hop chains and wall-jump chains feel good with debug overlay. *Mechanics implemented and verified headlessly (2026-07-25); the human feel pass in `playground.tscn` still has to sign off.*
2. **M2 — Stomp loop**: stomp detection, lives, stun/grace/bounce, player-as-terrain + duels. Two local players, KBM + controller. Exit: a playable 1v1 with 1 dummy hero. *Mechanics implemented and verified headlessly (2026-07-25) in `src/stage/duel.tscn`; the human 1v1 pass still has to sign off. Not yet done here: hero swap, abilities, and the auto-swap/respawn a 3-hero roster needs (all M3+).*
3. **M3 — Match structure**: MatchState, rounds, hero select (3 picks), swap, ult economy, HUD. *Done and verified headlessly (2026-07-26): 3-hero rosters, hero select with auto-fill, free swap, per-hero cooldowns ticking while benched, two ults per round with a 10 s gap, auto-swap and respawn on elimination, the round/results/best-of loop, and an in-round HUD. Stage select landed with M5, when there was more than one stage to pick between. The human pass on the full flow still has to sign off.*
4. **M4 — Heroes**: the first EIGHT implemented and verified headlessly (2026-07-26): Deadeye, Fei, Mason, Cerebelle, Sai, Slip, Terra, Kid (the second wave is M7 below). Two ultimates use free-recast (`Ability._is_free_recast`), one ability is multi-stage (`_cooldown_after_fire`), one is air-gated and one ground-gated (`_can_fire`). Terra's slam kill routes through the ordinary stomp system — no exception to rule 1 exists anywhere. Several kits were reworked on 2026-07-28 (see DESIGN §5.2); the human pass is outstanding.
5. **M5 — Terrain + stages**: contract + 8 core elements; three stages; stage select. *Complete and verified headlessly. All 8 elements plus the PoleClimb state they needed (poles later became "vertical ground": down rides, down+jump releases, dash is a boosted drop). The generic half of a stage lives in `MatchStage` (§3a), so a stage is layout and palette only. All three shipped stages were later rebuilt or built from the owner's hand sketches (2026-07-27/28): **Rooftop Rumble** — one wide roof, a 160px channel down each side, one-way teleporters as the only quick way back up; **Cryo Lab** — every surface ice, no hazards, three colour-coded portal pairs crossing a jump-proof middle gap; **Sunken Court** — two mesas over a five-spring trench with no standing room, roof platform dash-gated at 96px. Human feel pass on all three outstanding.*
6. **M6 — Formats & polish**: 2v2/3v3, Bo3/Bo5 lobby options, VFX/SFX pass, remaining heroes/stages. *Format plumbing done and verified headlessly (2026-07-26): seat count, block seat→team allocation, per-team spawn anchors with teammates spread around them, six-seat input bindings with per-pad device indices, hero select and stage select both seat-count driven, and the round-win rule exercised at 2v2 (one player down is not a team down). The lobby screen landed with it, so 2v2 and 3v3 are reachable from the UI. *Audio landed (2026-07-28): 18 procedurally generated cues and an `Audio` autoload.* *Pause menu landed (2026-07-28): volume, restart, quit to lobby.* *HUD laid out for every format (2026-07-28): blocks group by team and scale down as the format grows.* **Outstanding: rebind UI + `user://input.cfg`, volume persistence, per-match RNG seeding, and the remaining two stages.** A Windows export preset and build script ship alongside (`tools/build_windows.ps1`, `docs/PLAYTEST.md`) for remote playtesting over Steam Remote Play Together.*
7. **M7 — The second hero wave** (Voodoo, Saint, Vesper, Siku): `docs/NEW_HEROES.md` holds the detailed spec. *Complete and verified headlessly (2026-07-28). Shared systems first — impulse buff, contact debuff + `ContactSense`, phasing via per-pair collision exceptions, `clear_all_debuffs`, `fires_while_stunned`, debuff immunity, the stomp ward, and the sleep stack system with its `Sleeping` state — then the eight kits, then the harness cases, then registration in `HERO_ROSTER`. `StunBolt`'s flight was extracted into a shared `BoltProjectile` so Vesper's dart is a payload swap rather than a fork, and Voodoo's phantom negative is generated as a palette VARIANT of his own rig. Human feel pass outstanding for all four.*

## 8. How to update this document

Update **in the same commit** as the code change:
- New/changed **autoload** → §2 table.
- New **stage** → register it in `GameManager.STAGE_ROSTER` (with name/blurb/features/accent) and add a row to DESIGN §6.3; §3a if the `MatchStage` hooks changed.
- New **state** or transition → §3 tree (and mention the exit conditions).
- New **public API** method on Player → §3 API list (abilities depend on this being complete).
- New **terrain element** → §4 implemented list.
- New **signal** in the combat/match flow → §5 map.
- Milestone reached or reordered → §7 (mark done with ✅ and date).
Keep sections terse; this doc is a map, not a manual. Detailed rationale belongs in DESIGN.md or commit messages. If a section exceeds ~40 lines, split into `docs/impl/<topic>.md` and leave a pointer.

## 9. Networking posture

- All gameplay on the 60 Hz physics tick; no `_process` gameplay; no wall-clock time; seeded RNG only. `GameManager._ready()` asserts the tick rate: `project.godot` states it explicitly, but the editor prunes settings that match the current engine default when it saves, so the file alone is not a guarantee.
- Inputs are already abstracted through `InputConfig` — a future rollback layer replaces "read device" with "read input frame."
- Avoid physics interactions that depend on Godot's non-deterministic contact ordering where cheap (e.g., resolve duels by input frame, not contact callbacks order).

### 9a. Online play v1 (`src/autoload/net.gd`) — host-authoritative

The model is the one local multiplayer always used: **one machine simulates everything**. Locally that machine reads six devices; online, some of those devices are remote.

- **Input path**: a client polls its own seat-0 devices each tick and ships the `InputFrame` to the host (reliable — a dropped press edge is an eaten jump). The host stores it per seat, and `InputConfig.poll()` returns it for any seat whose device is `Device.NET` — the exact seam this section always promised. Edges are latched (consumed once per host tick) and OR-ed on receive, so client/host tick skew can neither double a press nor drop one.
- **State path**: the host broadcasts a per-tick snapshot (unreliable_ordered): every body's position/velocity/facing/animation/grace/stun, plus a mirror of the MatchState numbers the HUD reads. Life/elimination/round/match events go as reliable RPCs, and the client **re-emits MatchState's own signals**, so the HUD, event log, stomp pop and audio react on a client with zero changes — the mirror speaks the same signal language as the real thing.
- **Clients do not simulate.** `MatchStage` in client mode turns bodies into puppets (`Player.make_puppet()` — physics processing off, pose streamed) and stops terrain ticking; a terrain element that shoved a puppet would be fighting the host over where the body is. Only the authority calls `GameManager.end_round()` — a client's next round arrives as a Net event.
- **Flow (v1)**: online matches skip the select screens — `GameManager.start_quick_match()` hands every seat a fallback trio on the host's current stage. Lobby has HOST ONLINE / JOIN (ip[:port], default 30567); a client's lobby is a waiting room. Returning to the lobby ends the session on purpose: the lobby re-seats everyone from scratch.
- **Known v1 gaps, on purpose**: no prediction (a client feels its own inputs one round trip late); ability/terrain *effect visuals* are not replicated (the bodies they move are); select screens are host-side only; desktop-to-desktop ENet only — a browser build cannot host or dial a raw socket (docs/ITCH.md holds the WebRTC path). Rollback stays possible: everything still flows through `InputFrame`, and this layer did not foreclose it.

## 10. Testing

- **GUT** (Godot Unit Test addon) for: MatchState (lives/elim/round-win/ult economy), cooldown ticking incl. benched heroes, stun refresh rule, coinflip/stage-picker logic. Stubs in `tests/`. GUT is a local install (`docs/SETUP.md`); until it is installed, `tests/test_match_state.gd` logs a parse error on project load and nothing else.
- Feel is tested by humans in `playground.tscn` (movement) and `duel.tscn` (1v1); both carry a debug overlay — state, velocity, momentum charge, dash charges, perfect-window hits, and in the duel stage lives, stun, grace, and a combat event log.
- **Headless harnesses** live in `tests/` and are the regression net under the physics code. Neither is GUT: both need a live scene tree, physics ticks, and real collision. Non-zero exit on failure.
  - `movement_harness.tscn` — DESIGN 4 numbers: jump heights, momentum decay, b-hop preservation, dash charges/air lock, wall-jump chain decay and aim tilt, ceilings. Run after touching `src/player/`.
  - `combat_harness.tscn` — DESIGN 3 rules: what does and does not register as a stomp, life/stun/grace/bounce, the anti-chain grace, elimination into auto-swap, and duel resolution. Run after touching stomp, stun, or duel code.
  - `net_harness.tscn` — IMPLEMENTATION 9a over **two real processes and real ENet on localhost**: the host side spawns the client process itself, and the two assert opposite halves of the round trip — a remote press moving a host-simulated body, and a host snapshot moving the client's puppet. The client writes its verdict to `user://net_client_report.txt` (a detached process's stdout goes nowhere) and the host folds it into one output.
  - `terrain_harness.tscn` — DESIGN 6.2: every element in the catalog against what it should do to a player, and against the rule none of them may break — terrain stuns, pushes, launches, and redirects, but never removes a life. Run after touching anything in `src/stage/terrain/`.
  - `match_harness.tscn` — DESIGN 2 and 5 rules: every hero's ability and ultimate firing, going on cooldown, being refused on cooldown, the ult being spendable exactly once, the cooldown waiver, and — the load-bearing one — that **no ability of any hero can cost a life**; hero-select pick rules (no duplicates in one trio, duplicates across players, undo, auto-fill), rosters, swap validation and cycling, swap preserving position/velocity, stun blocking swap and ult, cooldowns ticking while benched, the one-ult-per-round economy, round win, and the reset between rounds. Run after touching MatchState, GameManager, hero select, or the swap path.
  - Teleporting a body into place inside a harness needs a settle frame. If whatever it was resting on has moved, the next `move_and_slide()` can depenetrate it across the arena with its velocity untouched — `combat_harness.place()` re-asserts the position a frame later for exactly this reason.
  - `Godot --headless --path . res://tests/<harness>.tscn`. A newly added `class_name` needs `Godot --headless --path . --import` first, or the harness cannot see the class.
- **Balance work** has its own two screens, both off the lobby and neither part of the match flow: `src/ui/balance_sheet.tscn` lists every hero's `@export` tunables (instantiated from the real ability scenes and enumerated, so it cannot go stale), and `src/stage/training_room.tscn` is a flat bench with all-twelve hero cycling, `DummyDriver` targets, and F5/F6/F7 for cooldowns, dummy behaviour and position reset. `MatchState.free_cooldowns` / `free_ultimates` bypass the cooldown and ult-budget *checks* without clearing their timers, so turning them back off restores the real state; the room keeps ultimates free for its whole life and leaves cooldowns as an F5 toggle.
- **Generated art** has a loader check: `Godot --headless --path . --script res://tests/verify_frames.gd` confirms every hero's SpriteFrames resource parses and holds every animation the states can ask for. Run it after regenerating characters. The movement harness separately asserts that no state names an animation the sheets lack.
- Harness inputs go through `InputConfig.action(player_id, base)`. The `aim_*` actions are unbound on KBM specifically so a harness can pin an exact aim; without that, aim falls back to a mouse pointer that headless leaves at the origin.
