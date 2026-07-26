# OVERSTOMP — Game Design Document

> A 1v1 / 2v2 / 3v3 hero-based platform fighter where the only way to score a kill is to jump on an opponent's head. Inspired by the movement feel of Super Mario Bros., the competitive structure of Super Smash Bros., and the hero-swap economy of modern hero shooters. Visual target: colorful modern-superhero pixel art that channels the painterly lighting and texture of Arcane (Riot / Fortiche).

Version: 0.1 (pre-production design)
Engine: Godot 4.4+ (GDScript)

---

## 1. Pillars

1. **The stomp is sacred.** Only a head-stomp removes a life. Abilities and ultimates create openings; they never kill directly.
2. **Movement is the skill ceiling.** Momentum, b-hops, wall-jump chains, and dash management separate good players from great ones.
3. **Heroes are utility, not stats.** All heroes share identical movement, hitboxes, and hurtboxes. A hero is exactly one ability + one ultimate.
4. **Rounds are drafts.** Picking 3 heroes per round, swapping freely mid-round, and spending one shared ultimate per round is the strategic layer.

---

## 2. Match Structure

### 2.1 Formats
- Team sizes: **1v1, 2v2, 3v3**
- Match length: best of **1 / 3 / 5** rounds (configurable in lobby).

### 2.2 Round flow
1. **Hero select** — each *player* picks **3 heroes** for the round (duplicates across teammates allowed or banned via lobby rule; default: allowed, no duplicates within one player's trio).
2. **Stage select** —
   - Round 1: coinflip winner picks the stage.
   - Round N>1: the **loser of the most recent round** picks.
3. **Combat** — every one of a player's 3 heroes has **2 lives** (6 lives per player per round).
   - The player controls one hero at a time and may **swap freely** (no cooldown) between their own living heroes.
   - When a hero loses both lives, that hero is **eliminated for the rest of the round** for that player.
   - A player is out of the round when all 3 of their heroes are eliminated.
   - A **team** wins the round by eliminating every hero of every opposing player.
4. Repeat until one team reaches the required round wins.

### 2.3 The ultimate economy
- Each player gets **two ultimate activations per round**, shared across their 3 heroes, with a **~10 s cooldown between them**.
- They may be spent at any time in the round by whichever hero is currently active.
- Spending one (even to no effect) consumes it. Two-with-a-gap makes the ult a resource you plan around across a round rather than one all-or-nothing moment, while the gap stops both being dumped into the same scramble.

### 2.4 Hero swap rules
- Swap is instantaneous and cooldown-free.
- The incoming hero inherits the outgoing hero's **position, velocity, lives-state UI, and stun state** (you cannot swap to cancel a stun — see §5.4).
- Ability cooldowns are **per hero** and keep ticking while a hero is benched (prevents swap-to-reset abuse being strictly better, while still rewarding rotation planning).
- Swapping while your ability projectile/effect is live: the effect persists (e.g., a placed block stays).

---

## 3. Core Combat: The Stomp

### 3.1 Landing a stomp
- Every hero has an identical **head hurtbox** (top ~25% of the body) and identical **feet stompbox** (bottom ~20%).
- A stomp registers when an enemy's stompbox overlaps your head hurtbox **while the enemy's vertical velocity is downward relative to you** (falling onto you). Grazing contact while both rise does not count.
- Abilities and ultimates **cannot** remove lives. Hazards (stun lines, explosions) **cannot** remove lives. Only stomps.

### 3.2 On being stomped
1. Victim loses 1 life.
2. Victim is **briefly stunned** (`stomp_stun_time`, ~0.6 s) but **keeps momentum**, plus receives a small directional bounce impulse based on the attacker's contact point/velocity (getting stomped on the left shoulder shoves you down-right, etc.).
3. Victim then gains an **anti-chain grace period** (`stomp_grace_time`, ~1.2 s) during which their head hurtbox is disabled. Visual: blinking silhouette.
4. Attacker receives a **stomp bounce**: an upward impulse (roughly a full jump, hold-extendable) — chaining stomps between *different* victims is possible and encouraged.

### 3.3 Losing the last life
- On the second stomp, the hero pops (confetti-style burst, no gore), the player is auto-swapped to their next living hero at a team spawn point with brief spawn protection (~2 s or until they act).
- If it was their last hero, the player enters spectator-of-teammates mode (team modes) or the round ends (1v1 / round-deciding elimination).

### 3.4 Player-vs-player body collision
- Side-to-side contact treats the other player (ally **or** enemy) **as terrain**: you can stand on shoulders (without triggering a stomp if not falling onto the head box), run into them, and — critically — **wall-jump off them**.
- **Player wall-jump duel:** during the brief contact window, the first player to input a wall jump off the other **briefly stuns** the other (~0.3 s, no life loss, no bounce).
- **Simultaneous wall jump** (within `duel_window`, ~4 physics frames, allies included): both players perform a **juiced wall jump** (~+20% impulse), no stun. This is a deliberate team-tech: allies can "kickflip" off each other for extra height.

---

## 4. Movement System

All numbers are starting tunables; every value lives in `movement_config.tres` for hot iteration.

### 4.1 Ground movement & momentum
- Running builds momentum up to a cap after **~1–2 s** of sustained movement (`accel_time_to_cap ≈ 1.5 s`, `run_speed_base ≈ 260 px/s`, `run_speed_cap ≈ 420 px/s`).
- **Starting is heavier than turning.** Reaching base speed from a standstill takes `ground_accel_time ≈ 0.083 s`, while a **direction change stays fast** (~0.1 s to flip at base speed). Committing to a direction costs something; changing your mind does not. Redirect from capped momentum still costs a short skid.
- **In the air**, control authority is low: air acceleration nudges trajectory (`air_control ≈ 12–18%` of ground accel) — commit to your arcs.
- Momentum redirect midair is **gradual**, never instant (dash is the instant-redirect tool).

### 4.2 Jumping
- **Variable-height jump**: holding jump extends rise (min hop ≈ 1.25 tiles, full hold ≈ 4.5 tiles, `jump_hold_time_max ≈ 0.28 s`). The tap and the hold are far apart on purpose — the tap is a shuffle, and height is something you ask for, and hold for.
- **Gravity is heavy** (`gravity ≈ 1800`). Arcs are tall but not slow; hanging at the apex reads as floating and is the enemy of a game about landing on heads. The hold force is set just short of cancelling gravity so the rise always decelerates.
- Coyote time (~0.1 s) and jump buffering (~0.12 s) — non-negotiable feel features.
- **B-hopping**: landing and jumping within a **perfect-timing window** (`bhop_window ≈ 0.08 s`) preserves 100% of horizontal momentum (normal landing applies ground friction immediately). Chained b-hops let you carry (not exceed) capped run speed indefinitely.

### 4.3 Omnidirectional dash
- **2 charges**, short shared recharge (`dash_recharge ≈ 2.5 s per charge`).
- Direction: on a **surface**, dash is constrained parallel to that surface (along ground, along wall while sliding); **airborne**, dash is fully omnidirectional, steered by the **movement input** (left stick / WASD), else facing. The aim vector belongs to abilities and never steers movement — two directions fighting over one action reads as the controls disagreeing with you.
- The dash is **very short** (~0.12 s) and grants a **brief acceleration boost** after it ends (~0.4 s of raised speed cap) — dashes are momentum tools, not teleports.
  - **Air dash ≈ 4.5 tiles** sideways and downward, diagonals included — the longest of the three, and the range tool. Airborne is where you cannot accelerate, so that is where the dash should pay.
  - **Ground dash ≈ 3.5 tiles**, deliberately *shorter* than the air dash: on the ground you can already run, so a dash is a small reposition rather than the better option.
  - Its **upward** component is cut to roughly a sixth of that reach (~1 tile of climb). Diagonal dashes therefore fly nearly flat: you keep the distance, you do not get the height. An up-dash at parity with the jump beats the jump at its own job and collapses the whole vertical game into "dash up".
  - **Wall dash ≈ 3 tiles** along the wall: climbing stays the expensive way up.
- **Air restriction:** two charges cannot be used **consecutively in the air**; after an airborne dash you must touch a surface (ground, wall, ceiling, or another player) before dashing again. On a surface, back-to-back dashes are legal.

### 4.4 Walls
- **Wall slide**: holding into a wall slides at reduced fall speed; neutral input slides faster; down input drops.
- **Wall jump**:
  - First wall jump has full up-and-away impulse.
  - **Consecutive wall jumps off the same wall face** keep horizontal push but have **little-to-no upward** component — hopping one wall moves you *across*, not *up*.
  - **The chain belongs to a wall face, not to your airtime.** Crossing to a different wall — the opposite side of a shaft, a different pillar — starts a fresh chain at full impulse. Bouncing between two walls is meant to climb; ratcheting up a single wall is not. A face is a collider plus a side, so both walls of a one-tilemap shaft count as different.
  - **Steered wall jumps**: the **movement input** tilts the wall-jump direction within a cone (~35°) away from the wall. Holding into the wall steepens the jump; holding away flattens it into distance. Neutral gives the plain up-and-away impulse.
  - **Perfect wall jump**: jumping within `walljump_perfect_window` (~0.08 s) of wall contact preserves momentum, mirroring b-hop rules — this is the wall analog of b-hopping.
- **Ceilings can never be wall-jumped.** (They can be dash-touched to reset the air-dash restriction.)

### 4.5 Crouch & slide
- **Crouch** = hold down while grounded. The body is **half height** and the head hurtbox drops with it, so crouching changes where you can be hit, not whether you can be.
- **Slide** = crouch while running with real speed (`slide_min_speed ≈ 200 px/s`). Speed and momentum bleed away steadily; below `slide_exit_speed` the slide settles into a crouch.
- **You cannot dash out of a slide.** Dash is the instant-redirect tool, and allowing it would turn the slide into a free way to hold speed instead of a commitment.
- **You can jump out of a slide**, and it is the point of sliding: little height (~80% of the *minimum* hop) but a hard horizontal launch (~1.5× current speed), briefly above the normal cap. The slide jump is **not** hold-extendable — it is a committed leap, not a better jump.
- Slide → jump → land → slide is the intended ground-chain alongside b-hopping, and it trades the ability to change your mind for distance.

### 4.6 Movement state machine (implementation shape)

```
Idle ↔ Run → Skid
  ↓      ↓  (down held)
  └→ Crouch ↔ Slide → slide jump
  ↓  Jump/Fall (variable jump, coyote, buffer)
Air ↔ Dash (omni)  ↔ WallSlide → WallJump
  ↓
Stunned (stomp / duel-loss / hazard) → Grace
PoleClimb (terrain-specific state)
```

Every state is a node under a `StateMachine`; heroes plug abilities in *around* this machine, never inside it (see IMPLEMENTATION.md).

---

## 5. Heroes

### 5.1 Design constraints
- Identical: movement stats, hitboxes, hurtboxes, stompboxes, silhouette size (32×48 logical px).
- Distinct: **1 ability** (cooldown-based, ~6–12 s) + **1 ultimate** (once per round per player).
- Abilities provide **positioning utility**: self-buffs, mobility, terrain creation/modification, crowd control (stuns/knockback), zoning. They must never directly remove a life.
- Aimable abilities use the shared aim vector (cursor / right stick).

### 5.2 Launch roster (8 heroes; first 4 are the vertical-slice set)

| # | Hero (working name) | Ability (CD) | Ultimate | Fantasy |
|---|---|---|---|---|
| 1 | **Deadeye** | Aim & fire a stun bolt; on hit, enemy is stunned ~0.8 s (6.4 s) | **Loaded Shot**: refunds the bolt cooldown and makes the *next* bolt 50% faster with a 4 s stun | Sharpshooter vigilante |
| 2 | **Skyla** | Second jump in mid-air, **stronger** than a normal jump; not aimed, horizontal momentum untouched (5.6 s) | **Double Trouble**: for 7 s her jump cooldown drops to 1 s | Jet-boot speedster |
| 3 | **Mason** | Place a **solid** bumper block with a lingering hitbox and vector-based reflection — you leave along your incoming angle mirrored, like a Smash bumper. Everyone bounces, Mason included (10 s, max 1 alive, ~4 s life) | **Keystone**: a block his own team walks through; enemies who touch it are **frozen and stunned**, then dropped under normal gravity | Hard-light constructor |
| 4 | **Nova** | Radial burst: heavy knockback on nearby enemies, no stun (7.2 s) | **Supernova**: one ring leaves his body and expands across the **whole stage**, slowly enough to outrun. Whoever it catches is stunned, stripped of all momentum, and dropped | Gravity brawler |
| 5 | **Wisp** | Dropped teleport beacon; re-cast to warp back to it (11 s) | **Phase Shift**: team-wide brief intangibility to stomps (2.5 s) | Phantom courier |
| 6 | **Tether** | Fire a grapple that pulls you to terrain/players (8 s) | **Lockdown**: tether the nearest enemy to a point for 2 s (they can move within a radius) | Chain-slinger |
| 7 | **Gale** | Wind gust column that pushes players (7 s) | **Tempest**: stage-wide directional wind for 6 s | Storm caller |
| 8 | **Frostbyte** | Coat a terrain strip in ice (9 s) | **Flash Freeze**: all current terrain becomes ice for 8 s | Cryo hacker |

(Wisp's ult is the only stomp-defensive ult; keep an eye on it in balance.)

**Ability cooldowns are ordered, not uniform**: Skyla 5.6 s < Deadeye 6.4 s < Nova 7.2 s < Mason 10 s. The cheaper an ability is to press, the less it should decide on its own — Skyla's is pure mobility, Mason's places terrain that outlives the press.

Nova's Supernova is deliberately outrunnable and deliberately undodgeable: it moves well below a capped run, so reacting early keeps you ahead of it, but it covers the entire stage, so there is no edge to escape past. Escaping it outright is a hole left for later kit — Wisp's teleport, portal terrain — rather than something movement alone should solve.

### 5.3 Cooldown rules
- Cooldowns tick in real time, including while benched (see §2.4).
- Cooldowns reset between rounds. The unspent ultimate does **not** carry over.

### 5.4 Stun rules (unified)
- Stun sources: stomp (0.6 s), duel loss (0.3 s), Deadeye bolt (0.8 s), stun line (0.4 s), explosion (0.5 s), Nova ult (1.0 s), Mason ult block (0.5 s).
- While stunned: no inputs, momentum preserved, gravity applies, cannot swap heroes.
- Stuns do **not** stack; a new stun refreshes to `max(remaining, new)`.
- Stunned players' head hurtboxes remain **active** (stun into stomp is the core combo) *except* during post-stomp grace.

---

## 6. Stages & Terrain

### 6.1 Stage rules
- **Fully contained**: sealed boundaries (walls/ceiling/floor or wrap-none). You cannot fall off or self-eliminate. There are no pits — the stage is the arena, the players are the hazards.
- Sizes scale with format: **Small** (1v1, ~40×24 tiles), **Medium** (2v2, ~56×32), **Large** (3v3, ~72×40). Tile = 16 px.
- Team spawns are on opposite sides with brief spawn protection.

### 6.2 Terrain element catalog

| Element | Behavior |
|---|---|
| **Pole** | Grab to instantly zero momentum; crawl up/down; jump off either side (aimable). The "reset button" of movement. |
| **Ice** | Near-zero friction: momentum cap raised slightly, redirect much slower, no skid-stop. B-hop window is more lenient on ice. |
| **Stun line** | Glowing tripwire; touching it stuns ~0.4 s (momentum kept). Head hurtbox stays active — classic setup tool. |
| **Jump spring** | Fixed strong launch on contact (overrides vertical velocity); can be b-hop-chained. |
| **Speed boost pad** | Directional pad that sets you to (or over) momentum cap briefly. |
| **Portal pair** | Enter one, exit the other, **velocity vector preserved and rotated** to exit orientation. |
| **Wind zone** | Constant directional force; no stun; affects airborne players ~2× more than grounded. |
| **Explosion (hazard)** | Telegraphed periodic blast (2 s warning glow): knockback + ~0.5 s stun. |
| *Extra:* **Conveyor belt** | Moves grounded players; stacking with run momentum can exceed cap. |
| *Extra:* **Crumble platform** | Breaks ~0.5 s after stood on; respawns after 4 s — denies camping. |
| *Extra:* **Sticky wall** | No slide-down; wall jumps off it get +15% impulse but consume a longer contact lockout. |
| *Extra:* **One-way platform** | Pass-through from below, drop-through with down+jump. Standard platformer fare; head-stomps *through* one-ways are disabled. |
| *Extra:* **Rotating platform / gear** | Slowly rotating terrain, carries momentum tangentially when you jump off. |
| *Extra:* **Bumper orb** | Pinball bumper: fixed-magnitude radial knockback, no stun. |

### 6.3 Launch stages (vertical slice: first 2)
1. **Rooftop Rumble** (Small) — city rooftops at dusk; poles (antennas), springs (awnings), one wind corridor between buildings.
2. **Cryo Lab** (Small/Medium) — ice floors, stun-line laser grid on a timer, portal pair.
3. **Powerplant** (Medium) — conveyor belts, periodic explosion vents, sticky walls.
4. **Skyline Gardens** (Large) — rotating platforms, wind updrafts, bumper orbs, many one-ways.

---

## 7. Controls

| Action | Mouse & Keyboard | Controller |
|---|---|---|
| Move | WASD | Left stick |
| Crouch / slide | S (hold) | Left stick down (hold) |
| Jump (variable) | Space | R1 (right bumper) |
| Aim | Mouse cursor (Enter-the-Gungeon-style reticle) | Right stick |
| Dash | Shift | R2 (right trigger) |
| Ability | Left click | L1 (left bumper) |
| Swap hero | Right click (cycles; hold for radial menu) | L2 (left trigger) — tap cycles, hold for radial |
| Ultimate | E | **R2 + L2 together** (chord) |

Notes:
- The controller ultimate chord requires a small simultaneity window (~0.1 s) and suppresses the individual dash/swap actions when the chord lands.
- All bindings rebindable via `InputMap`; store overrides in `user://input.cfg`.
- Aim vector is *always live* (feeds aimed wall jumps and dashes even for heroes with untargeted abilities).

## 8. Art Direction

- **Format**: pixel art, 32×48 character frames, 16 px tiles, rendered at integer scales.
- **Aesthetic target**: "pixel Arcane" — modern-superhero costumes, saturated neon-against-dusk palettes, painterly gradient lighting faked with 2–3 tone ramps per material, heavy rim light, chunky silhouettes, expressive squash-and-stretch on jumps/stomps.
- **Palette discipline**: shared 32-color master palette (`assets/palettes/`), each hero owns a 6–8 color slice with one signature neon accent (Deadeye = magenta, Skyla = cyan, Mason = amber, Nova = violet).
- **Silhouette before color.** Heroes must be distinguishable in one frame with the color stripped out: Deadeye is the slim coat and brimmed cowl, Skyla the finned helmet and streaming scarf, Mason the hard hat and slab shoulders, Nova the hooded ring-bearer. Color alone fails for colorblind players and in a screenshot full of neon.
- **The accent always owns the head band.** The top 12px is the stomp hurtbox, and it is the one piece of information the whole game is built on — every hero marks it, standing or crouched.
- Teams are distinguished by **outline/rim-light color** (blue vs. red rim), not by recoloring the hero.
- **Every movement state gets its own pose.** A player reads intent off silhouettes at speed: a slide has to be unmistakably not a crouch, a wall jump not a rise. The full set is tabulated in `assets/STYLE_GUIDE.md`.
- VFX are bold and readable first: stun = yellow stars + desaturation; grace = blinking alpha; ult = full-screen chromatic pulse.
- See `assets/STYLE_GUIDE.md` for per-asset specs, the animation table, and how to regenerate.

## 9. Audio Direction (light, for completeness)
- Synthwave-meets-orchestral hybrid (Arcane's genre-blend instinct at chiptune fidelity).
- The stomp needs the best sound in the game: layered thump + pop + pitch-up per chain stomp.

## 10. UX / Meta screens
- Lobby → format select (1v1/2v2/3v3, Bo1/3/5) → per-round: hero select (3 picks, simultaneous, timed) → stage select (coinflip/loser) → combat → round results → match results.
- In-round HUD: your 3 hero portraits with life pips (2 each), ability cooldown radial, ultimate available marker (team-visible), enemy roster life state.

## 11. Out of scope for v0.x (explicitly)
- Online netcode (design for it: fixed-tick simulation, input-driven, deterministic where cheap — see IMPLEMENTATION.md §Networking posture).
- Ranked/progression, cosmetics, more than 8 heroes, more than 4 stages.

## 12. Tunables index
All feel-critical numbers live in resources, not code:
- `src/config/movement_config.tres` — speeds, windows, dash, wall rules
- `src/config/combat_config.tres` — stun table, grace, bounce impulses
- Per-hero `src/heroes/resources/*.tres` — cooldowns, ability params
