# OVERSTOMP — Game Design Document

> A 1v1 / 2v2 / 3v3 hero-based platform fighter where the only way to score a kill is to jump on an opponent's head. Inspired by the movement feel of Super Mario Bros., the competitive structure of Super Smash Bros., and the hero-swap economy of modern hero shooters. Visual target: colorful modern-superhero pixel art that channels the painterly lighting and texture of Arcane (Riot / Fortiche).

Version: 0.1 (pre-production design)
Engine: Godot 4.4+ (GDScript)

---

## 1. Pillars

1. **The stomp is sacred.** Only a head-stomp removes a life. Abilities and ultimates create openings; they never kill directly.
2. **Movement is the skill ceiling.** Momentum, b-hops, wall-jump chains, and dash management separate good players from great ones.
3. **Heroes are utility, not stats.** All heroes share identical movement, hitboxes, and hurtboxes. A hero is exactly one ability + one ultimate.
4. **Rounds are drafts.** Picking 3 heroes per round, swapping freely mid-round, and spending two shared ultimates per round is the strategic layer.

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
- **Variable-height jump**: holding jump extends rise (min hop ≈ 1.35 tiles, full hold ≈ 5.5 tiles, `jump_hold_time_max ≈ 0.33 s`). The tap and the hold are far apart on purpose — the tap is a shuffle, and height is something you ask for, and hold for.
- **Gravity is heavy** (`gravity ≈ 1800`). Arcs are tall but not slow; hanging at the apex reads as floating and is the enemy of a game about landing on heads. The hold force is set just short of cancelling gravity so the rise always decelerates.
- Coyote time (~0.1 s) and jump buffering (~0.12 s) — non-negotiable feel features.
- **B-hopping**: landing and jumping within a **perfect-timing window** (`bhop_window ≈ 0.08 s`) preserves 100% of horizontal momentum (normal landing applies ground friction immediately). Chained b-hops let you carry (not exceed) capped run speed indefinitely.

### 4.3 Omnidirectional dash
- **2 charges**, short shared recharge (`dash_recharge ≈ 2.5 s per charge`).
- Direction: on a **surface**, dash is constrained parallel to that surface (along ground, along wall while sliding); **airborne**, dash is fully omnidirectional, steered by the **movement input** (left stick / WASD), else facing. The aim vector belongs to abilities and never steers movement — two directions fighting over one action reads as the controls disagreeing with you.
- The dash is **very short** (~0.12 s) and grants a **brief acceleration boost** after it ends (~0.4 s of raised speed cap) — dashes are momentum tools, not teleports.
  - **Air dash ≈ 4.5 tiles** sideways and downward, diagonals included — the longest of the three, and the range tool. Airborne is where you cannot accelerate, so that is where the dash should pay.
  - **Ground dash ≈ 3.5 tiles**, deliberately *shorter* than the air dash: on the ground you can already run, so a dash is a small reposition rather than the better option.
  - Its **upward** component is cut to roughly a sixth of that reach (~1 tile of climb).
  - A **straight-down** air dash is cut to ~30% reach and grants no post-dash boost. A cheap fast-fall is the strongest stomp approach in the game and should cost something to line up. **Down-diagonals are untouched** — the nerf is aimed at one input, not at dive angles. Diagonal dashes therefore fly nearly flat: you keep the distance, you do not get the height. An up-dash at parity with the jump beats the jump at its own job and collapses the whole vertical game into "dash up".
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
- **You cannot dash out of a slide, or out of a crouch.** Dash is the instant-redirect tool, and allowing it would turn the slide into a free way to hold speed instead of a commitment. Crouch is covered too because a slide that has bled off its speed becomes a crouch while the player is still visually sliding.
- **The opening second of a slide is free**: speed and momentum carried in are kept, and only after that does friction start bleeding them, gently. Entering a slide at a capped run should be a way to *travel*, not a way to stop.
- **Landing straight into a slide inside the b-hop window keeps all of your horizontal speed** - the third member of the perfect-window family, alongside the b-hop and the perfect wall jump. It is what lets an air dash be converted into ground speed rather than clamped away by the landing.
- **You can jump out of a slide**, and it is the point of sliding: little height (~90% of the *minimum* hop) but a hard horizontal launch (~1.75x current speed, **capped** at `run_speed_cap x slide_jump_speed_mult` so chaining slide jumps holds that line instead of compounding), briefly above the normal cap. The slide jump is **not** hold-extendable — it is a committed leap, not a better jump.
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
- Distinct: **1 ability** (cooldown-based, ~6–12 s) + **1 ultimate** (the player gets two activations per round, shared across their 3 heroes — see §2.3).
- Abilities provide **positioning utility**: self-buffs, mobility, terrain creation/modification, crowd control (stuns/knockback), zoning. They must never directly remove a life.
- Aimable abilities use the shared aim vector (cursor / right stick).

### 5.2 Launch roster (8 heroes; first 4 are the vertical-slice set)

| # | Hero (working name) | Ability (CD) | Ultimate | Fantasy |
|---|---|---|---|---|
| 1 | **Deadeye** (red) | Aim & fire a stun bolt; on hit, enemy is stunned ~0.8 s (6.4 s) | **Loaded Shot**: refunds the bolt cooldown; the *next* bolt is 50% faster with a 5.5 s stun | Cyberpunk cowboy, augmented eyes |
| 2 | **Fei** (jade) | Second jump in mid-air, **stronger** than a normal jump; not aimed, momentum untouched (5.6 s) | **Tailwind**: for 8 s her jump cooldown drops to 0.3 s | Jade dancer, sword-saint grace |
| 3 | **Mason** (gold) | Place a **solid** block with a lingering hitbox that acts as a **four-sided spring**: a fixed launch out of whichever face you touch (~half a stage spring), tangential speed kept (10 s, max 1 alive, ~4 s life) | **Keystone**: a gate his own team walks through; enemies who touch it are **frozen and stunned**, then dropped (20 s life) | Engineer-chieftain, fur and tech |
| 4 | **Cerebelle** (purple) | Radial burst: heavy knockback on nearby enemies, no stun (6.7 s) | **Supernova**: one slow ring crosses the **whole stage**; the caught are stunned, stripped of momentum, and dropped | Gravity valkyrie, crested helm, tattoos |
| 5 | **Sai** (pink) | **Grapple Hook** (4.7 s): throw a visible hook along the aim; if it bites terrain, swing on a fixed-radius pendulum. Five direction changes, then the rope releases. **Recast while roped to reel in** — a fast haul up the rope that stops a body's length short of the anchor, free because it is the same activation. Jumping off keeps the swing's momentum | **Sai Slash**: instantly cross a long line through bodies (never terrain); everyone hit is slowed with jump/dash/wall jump gutted for ~3.5 s | Stylish grappler |
| 6 | **Slip** (aqua) | **Slip Back** (8 s): drop an anchor; recast to blink instantly back to it. Anchor expires in 6 s | **Teleport**: place two pads (recast places the second, free). Touch one, exit the other; both go dark 1.5 s after each use. Enemies arrive slowed, allies hasted | Streetpunk tinkerer |
| 7 | **Terra** (brown) | **Slam** (9 s, air only): hang, then drive straight down. Landing on a head resolves as a **stomp** — the one ability kill, and it is a stomp kill. Landing beside one is a shockwave: shove + brief stun | **Fracture**: a slab that drags whoever it catches, detonates on terrain; the caught drop, slowed, no dash or jump ~2 s | Warrior-builder (name is a placeholder) |
| 8 | **Kid** (orange) | **Wind Cannon** (8.5 s): a stage-crossing gust along the aim, through walls, shoving everyone in it — allies too | **EMP**: after a 0.6 s telegraph, every enemy is slowed 50% and locked out of dash/ability/ultimate for 3 s | Nerdy gadgeteer |
(Former concepts Wisp / Tether / Gale / Frostbyte are retired; their best ideas were folded into Slip, Sai, and Kid. Terra's slam is the only ability that can end in a life — and only because a slam onto a head **is** a stomp, resolved by the ordinary stomp system with grace and anti-chain intact.)

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
2. **Cryo Lab** (Medium, 56×32) — a sealed cryogenics floor. Ice on the outer thirds of the floor and on both mid benches, the centre deliberately grippy so there is somewhere to plant a stomp from; a four-line laser grid on one 3 s clock with staggered phases; one portal pair at floor level against opposite walls, both facing the same way so a full-speed run comes out the far side at the same speed. A containment cell in the middle is the contested platform, with a 128 px wall-jump shaft hanging under it.
3. **Sunken Court** (Medium, 56×32) — two solid mesas either side of a 320×128 trench. The trench is deeper than a held jump and **five springs tile its floor wall to wall**, so it has no standing room at all: you enter it, bounce, and steer out over two or three arcs. One platform exactly as long as the trench roofs it 96px above the mesa tops — past a plain held jump, inside the jump-plus-dash ceiling, so the high ground costs a dash. A pole sits over each spawn as the dash reset. The vertical counterpart to Rooftop Rumble's runway.
4. **Powerplant** (Medium) — conveyor belts, periodic explosion vents, sticky walls.
5. **Skyline Gardens** (Large) — rotating platforms, wind updrafts, bumper orbs, many one-ways.

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
- **Aim guide**: every player draws a short dashed line from their body along the aim, six hero-heights (216 px) long, clipped at the first terrain it meets. Not a laser sight — knowing your exact line across the whole stage would turn aimed abilities into hitscan. Its tip reads as a bar when terrain stopped it and a chevron when it did not, so it doubles as "the hook bites here". Hidden while stunned or frozen, when there is nothing to aim with.

## 8. Art Direction

- **Format**: pixel art, 32×36 character frames (bodies 34 px — 30% shorter than the original spec), 16 px tiles, integer scales.
- **Aesthetic target**: **comic-book chibi with a punk edge** — Big Hero 6 / My Hero Academia proportions (oversized heads, ~40% of the body) wearing cyberpunk gear. Two-plane cel shading, thick keylines, one loud accent per hero, minimal clutter. Squash-and-stretch stays expressive on jumps and stomps.
- **Every stomp pops**: an eight-spoke starburst in the attacker's accent colour fires at the victim's head on every stomp — the kill confirm reads from across the stage.
- **Debuffs are legible.** Every non-stun debuff shows a badge over the victim, distinct per source: a slash for Sai, a lightning kink for Kid's EMP, bars for Terra's fracture, a ring for a plain slow. A player who cannot tell *why* they are slowed cannot decide what to do about it — an EMP means wait, a slash means you still have a dash, a fracture means you are pinned. Shape carries the meaning so it survives colourblindness; colour is the fast read.
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
