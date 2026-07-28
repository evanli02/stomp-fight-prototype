# NEW_HEROES.md — The Second Wave (Voodoo, Saint, Vesper, Siku)

The implementation guide for the four designed-but-unbuilt heroes. This file is
the **authoritative spec for these kits** the way DESIGN.md §5.2 is for the
first eight; DESIGN.md's roster table points here. Written 2026-07-28.

**What already exists** (do not redo):

- Art: all four rigs in `assets/tools/generate_characters.py`, sheets in
  `assets/characters/<hero>/`, SpriteFrames in
  `src/heroes/resources/frames/<hero>_frames.tres`, all held to the 41-frame
  contract by `tests/verify_frames.gd`.
- `HeroData` resources: `src/heroes/resources/{voodoo,saint,vesper,siku}.tres`
  — names, accents, cooldowns, card text, frames, ability scene wiring.
- Ability skeletons: eight `Ability` subclasses in `src/heroes/abilities/`
  (`voodoo_soul_ignition`, `voodoo_phantom`, `saint_cleanse`,
  `saint_benediction`, `vesper_sleep_dart`, `vesper_deep_sleep`, `siku_pillar`,
  `siku_frostbite`) with final tunables as `@export`s and the implementation
  marked `TODO(opus)`. Numbers are starting values — tune them, but tune them
  in the exports/resources, never inline (CLAUDE.md).
- A reusable on-body aura: `src/heroes/effects/hero_aura.gd` with styles
  `&"wind"` (already live on Fei's ult), `&"surge"` (Voodoo), `&"ward"`
  (Saint), and an `intensity` knob.

**What this file adds**: the Player/system API these kits need, the per-hero
rules that are easy to get wrong, the interaction table, and the harness
checklist. Follow the milestone discipline: build the shared systems first
(§1), then the kits (§2), then register (§4). **The heroes stay out of
`GameManager.HERO_ROSTER` until their kit passes the harness** — a registered
hero with a no-op ability is a trap for every playtest before then.

---

## 1. Shared systems to build first (in this order)

All on `Player` unless said otherwise; all following the house rules — public
API only, refresh = `max(remaining, new)`, never additive, per-tick scans over
`body_entered`, every timer on the physics tick.

### 1.1 `grant_impulse_buff(mult: float, dur: float)`

The buff-side twin of `impair_mult`: scales jump, dash, wall-jump, and
slide-jump impulses **up**. Mirror `speed_buff_mult`/`speed_buff_remaining`
exactly (fields, `_tick_timers` decay, strongest-and-longest refresh). Apply it
wherever `impair_mult` is already read in the states — the two multipliers
stack multiplicatively (`impulse * impair_mult * impulse_buff_mult`), so a
buffed-then-EMP'd player resolves without a special case. Used by Voodoo (both
kits) and Saint's Benediction.

### 1.2 `begin_contact_debuff(knockback, slow_mult, impair_mult, debuff_time, window, tag)`

Voodoo's touch. For `window` seconds the player's body re-scans overlapping
**enemy** bodies each physics tick (the players-as-terrain collision means an
Area2D is needed — add a `ContactSense` Area2D to `player.tscn` sized to the
body, mask 2, disabled except during the window). On contact:
`victim.apply_impulse(away * knockback)` (away = victim minus toucher, the
RadialBurst zero-vector guard included), `victim.apply_slow(...)` and
`victim.apply_impairment(...)` with `tag`. Per-victim re-trigger gap of
`debuff_time` — a held touch re-applies only after the debuff lapsed;
re-touching **resets** the 3 s (which `apply_slow`'s max-refresh already
does — the gap just stops every tick counting as a touch). Stomp contacts are
NOT special-cased here: the stomp scan runs independently and grace already
protects a just-stomped victim's head; the touch may still knock them back,
which is fine — knockback is not a life.

### 1.3 `begin_phasing(dur: float)` (+ `phasing_remaining`)

Voodoo's ghost rule. Players collide with each other because their body is on
the terrain layer other bodies scan; phasing drops the player-vs-player bit
**both ways** for the window (collision layer/mask edit via `set_deferred`,
restored on expiry, on respawn, and on round reset — leave no dangling ghost).
Head hurtbox and stompbox stay exactly as they are: a phasing Voodoo falling
through a head **must still resolve as a stomp** through `receive_stomp` — the
areas do the stomp work, not the body collision, so this falls out free; assert
it in the harness rather than trusting it. While phasing, the same
`ContactSense` scan (1.2) applies `apply_stun(pass_stun_time)` per enemy with a
re-trigger gap of the stun length — one pass one stun, a re-pass resets
(`apply_stun` is already max-refresh). A phasing player can no longer be
wall-jumped off — acceptable and intended: you cannot kick off a ghost.

### 1.4 `clear_all_debuffs()`

Saint's verb. Zeroes: `stun_remaining` (and kicks the state machine out of
`Stunned`/`Sleeping` the way stun expiry does), `freeze_remaining`,
`slow_*`, `impair_*`, `disrupt_remaining`, sleep + sleep stacks (1.6),
`debuff_tags`. Explicitly NOT touched: `grace_remaining`, spawn protection,
lives, position, velocity, cooldowns, the ult budget. Cleansing a stun is the
one sanctioned way out of a stun besides waiting — keep it a single method so
the harness can audit what it clears.

### 1.5 `fires_while_stunned` on `Ability` + `grant_debuff_immunity(dur)` + `grant_stomp_ward(dur)`

- `fires_while_stunned: bool = false` export on `Ability`.
  `Player.try_ability`/`try_ultimate` currently refuse while
  `stun_remaining > 0.0 or disrupt_remaining > 0.0`; change the stun half to
  honour the flag. **The disrupt half is not negotiable**: Kid's EMP beats
  Saint, by design. Sleep also blocks casting (1.6) and is NOT bypassed —
  the flag reads "castable while stunned", not "castable while disabled".
- `grant_debuff_immunity(dur)`: while it runs, `apply_stun`, `apply_slow`,
  `apply_impairment`, `apply_disrupt`, `apply_freeze`, `add_sleep_stack`, and
  `apply_sleep` are no-ops on this player (early-out at the top of each).
  Stomp stun/grace bypass immunity? No — see the ward: a warded stomp costs
  the blessing instead, and an unwarded stomp on a merely-immune player still
  stuns (immunity is about abilities, the stomp is sacred). Implement as: the
  stomp path calls an internal `_apply_stomp_stun` that skips the immunity
  check.
- `grant_stomp_ward(dur)`: a flag consumed inside `receive_stomp`, before
  `lose_life`, structured like the grace early-out: if warded — consume ward,
  clear Benediction's buffs/immunity/aura on that body, emit
  `stomp_warded(attacker)`, still give the ATTACKER their normal bounce
  (`attacker.on_stomp_landed` minus the victim-side effects), no life, no
  stun, no grace. This is the only place besides grace allowed to decide a
  stomp does not land, and it must live inside `receive_stomp` so victim
  authority stays the single resolution path (CLAUDE.md 1).

### 1.6 Sleep: `add_sleep_stack(life)`, `apply_sleep(dur)`, the `Sleeping` state

Vesper's system, and the biggest piece.

- **Stacks**: `sleep_stacks: int`, `sleep_stack_remaining: float` on Player.
  `add_sleep_stack(life)` increments and **resets the shared timer** (all
  stacks live and die together — that is the design, not a simplification).
  At `stacks_to_sleep` (3): stacks reset to 0 and `apply_sleep` fires.
  Expiry clears all stacks at once.
- **`apply_sleep(dur)`**: max-refresh like a stun. Enters the new `Sleeping`
  movement state (`src/player/states/sleeping.gd` — a real state, per the
  architecture rule, NOT flags inside other states).
- **`Sleeping`**: walk left/right only, hard-capped at
  `run_speed_base * sleep_walk_mult`, `momentum_charge` forced to 0 (no
  building momentum while slept), gravity applies, everything else refused:
  no jump, dash, wall interaction, slide, crouch. Swap is blocked (extend the
  `try_swap` stun check), ability/ultimate are blocked (extend
  `try_ability`/`try_ultimate` — and sleep is not bypassed by
  `fires_while_stunned`). Head hurtbox **stays live**: a sleeping player is
  the most stompable player in the game — that is the whole kit. Being
  stomped while asleep resolves normally (stun then grace); sleep continues
  underneath unless cleansed. Animation: reuse `&"stun"` until the generator
  gains a `sleep` pose.
- **Legibility** (the spec is explicit about this): stack pips and the sleep
  state must be readable on the victim. Extend `src/ui/debuff_marks.gd` —
  a `&"dart"` tag renders as 1-3 pips (pass the count through
  `Player.sleep_stacks` rather than a tag timer), and `&"sleep"` renders as a
  "zzz" mark; sleeping also desaturates the sprite slightly (same trick as
  the stun VFX language in STYLE_GUIDE).

### 1.7 New debuff badges

`DebuffMarks.MARKS` additions: `&"ignite"` (Voodoo touch — ring, bright
purple), `&"dart"` (Vesper stacks — pips, neon pink), `&"sleep"` (zzz, neon
pink). Shapes first, colour second, as ever.

---

## 2. The kits

The `@export` blocks in the skeleton files are the tunables and their starting
values; the `TODO(opus)` comments are the assembly order. What follows is only
what is not obvious from those.

### Voodoo (bright purple `#bf5fff`) — Soul Ignition / Phantom

- Ignition = 1.1 + 1.2 + `HeroAura` `&"surge"` at intensity 1. Phantom = the
  same at bigger numbers + 1.3 + `&"surge"` at intensity 2.
- **No stacking, ever**: re-casting refreshes his window; his touch resets the
  victim's 3 s. Both come free from max-refresh — the harness asserts it
  anyway.
- Phantom's palette inversion is a **SpriteFrames swap**, not a modulate (a
  tint would fight the grace blink, which drives `modulate.a`). Add an
  inverted-palette variant emission to the generator (same rig, inverted
  suit/accent slots) as `voodoo_phantom_frames.tres`; swap in
  `set_hero`-style via `sprite.sprite_frames`, restore on expiry, elimination,
  swap-out, and round reset.
- A phantom stomp is a stomp. `combat_harness` must gain the Terra-style
  two-sided assertion: falling through a head while phasing costs a life via
  `receive_stomp`; passing through side-on costs a stun and never a life.

### Saint (white `#f2f2fa`) — Cleanse / Benediction

- Both casts are stage-wide and instant. No aim, no range: the skill is
  timing, and the counterplay is baiting the cast or EMP-locking it.
- `fires_while_stunned = true` on both scenes. **EMP still blocks both.**
  Cleanse while slept: blocked (sleep blocks casting, and that is Vesper's
  win condition against Saint — an intended counter, like EMP).
- Benediction order matters: cleanse first, then buff — so a stun landing the
  same frame is cleansed, not immunized-around.
- The ward consumes on **any** stomp, including Terra's slam (a slam onto a
  head IS a stomp — same system, so the ward answers it; do not special-case).
- Ward + 2v2/3v3: every living **body** of every ally player gets exactly one
  ward; a hero swap keeps it (it is on the Player body, like every debuff).

### Vesper (black costume, neon pink `#ff2ec4` accent) — Sleep Dart / Deep Sleep

- Her costume is black by design; her `HeroData.accent_color` is the neon
  pink of her eyes because the accent drives the stomp burst, the HUD stripe,
  and the aim line, and pure black is invisible on a dusk stage. Her effects
  should read black-bodied with pink rims (the Deep Sleep sphere especially).
- The dart is `StunBolt`'s body with different payload: same 620 speed, same
  size, same raycast terrain death, first enemy only. Do not fork StunBolt —
  extract the flight into a shared base or parameterise the payload with a
  Callable; either is fine, copy-paste is not.
- Stack bookkeeping lives on the **victim** (1.6), not the dart or the
  ability — darts from a benched-then-returned Vesper, or two Vespers in a
  duplicate-pick lobby, must merge into one stack pool per victim.
- Deep Sleep pierces literally everything — no terrain query at all. It hits
  each enemy once per cast (per-cast hit set, ShockwaveRing-style). The drop
  (zero velocity, zero momentum) happens even if the victim is mid-dash or
  mid-swing: `set_velocity_override` + `request_state(&"Air")` first, then
  `apply_sleep`, so no grounded state erases the drop.
- Sleep vs. grace: sleeping does not touch the head hurtbox; a graced victim
  can still be slept (grace protects the head, not the ears).

### Siku (ice blue `#9edfff`) — Pillar / Frostbite

- The headroom refusal is **the** anti-stuck mechanism and belongs in
  `_can_fire` (refused = nothing spent, base class already handles that).
  The check: a shape query the size of `pillar_size` plus a standing body
  (`required_headroom` tall) cast upward from the ground under Siku, mask 1,
  must find nothing. This covers "distance from ground to the surface above
  is less than pillar + character" exactly, and refusing beats clamping — a
  half-height pillar would be a different ability under every low ceiling.
- The launch is the JumpSpring recipe verbatim: replace `velocity.y` with
  `launch_velocity`, keep `velocity.x` (spec: horizontal velocity is
  maintained), `request_state(&"Air")` (grounded states zero a launch —
  CLAUDE.md checklist). Everyone in the footprint launches: Siku, allies,
  enemies — terrain does not take sides.
- Footprint = bodies overlapping the pillar's column at cast (Area2D scan of
  the footprint rect at ground level). Launch first, then add the collision —
  same frame is fine because the launch has already moved them into `Air`,
  but never add a solid under a body that was not launched (a body standing
  half-off the footprint must not end up inside the pillar wall: the launch
  set must be exactly "overlaps the footprint", and the pillar spawn happens
  after the launches in the same tick).
- The melt frees a StaticBody2D under whoever climbed on top; Godot's
  depenetration can shove a standing body ~100 px when its support vanishes
  (handoff.md trap). Melt by shrinking the collision downward over a few
  frames (scale the shape, bottom-anchored) so standers settle instead of
  teleporting.
- Pillar top is icy: call `apply_surface_slip` per tick on standers, exactly
  the `Ice` element (reuse it — the pillar can own an `Ice` child sized to
  its cap).
- Frostbite reuses `ShockwaveRing.launch()` as-is (it already takes speed,
  reach, stun, and does the momentum strip). The sequencer node owns the
  schedule; rings centre on the CURRENT body of the casting player each
  pulse — the storm belongs to the player, not the skin, and survives swaps
  (effects are stage-parented).

---

## 3. Interaction table (assert these, don't assume them)

| Interaction | Ruling |
|---|---|
| Saint's Cleanse vs Kid's EMP | EMP wins: disrupt blocks the cast. The one hole in Cleanse, by design. |
| Saint's Cleanse vs sleep | Cleansing an ally's sleep: yes. Casting while HE is slept: no (sleep blocks casting). |
| Benediction immunity vs Vesper | Darts apply nothing, stacks don't accrue, sphere doesn't sleep. Existing stacks were already cleansed by the cast. |
| Benediction ward vs Terra slam | Slam-onto-head is a stomp, so the ward eats it: no life, blessing gone, Terra still bounces. |
| Benediction ward vs stomp during grace | Grace check runs first (existing early-out); a graced stomp attempt still costs nothing and does not consume the ward. |
| Voodoo phantom stomp | A life, via `receive_stomp`, exactly like Terra's slam. Two-sided harness assertion required. |
| Voodoo phantom + wall-jump duels | You cannot wall-jump off a phasing body (no contact); no duel can open. |
| Voodoo touch vs Saint immunity | Knockback lands (an impulse is not a debuff); the slow does not. |
| Sleep + stomp | Stomping a sleeping player: normal stomp, stun+grace on top, sleep keeps ticking under it unless cleansed. |
| Sleep + swap | Blocked, like stun. Waking (expiry or cleanse) unblocks. |
| Two Vespers (duplicate picks) | One stack pool per victim; either Vesper's dart advances it. |
| Siku pillar under an enemy mid-grace | Launches them (launch is not a debuff and not a head event). |
| Frostbite vs Benediction | Immune allies shrug the stun and the drop is never applied (the drop rides the stun application). |

Rule-1 audit for the wave: nothing here touches `lose_life` except the two
stomp paths that already exist (`receive_stomp` for Phantom's falls; the ward
consuming INSTEAD of a life). If any other path in the new code can reach a
life, it is wrong — stop and restructure.

## 4. Definition of done, per hero

1. Shared systems from §1 in place, with `docs/IMPLEMENTATION.md` §3's API
   list updated in the same commits.
2. Kit implemented in the skeleton files; skeleton `push_warning` lines gone.
3. `tests/match_harness.gd`: extend `_check_abilities` expectations (Siku's
   pillar is air-refused via `_can_fire` like Terra's slam is ground-refused —
   the sweep needs to know); add the per-hero cases above; the no-life sweep
   must cover all twelve.
4. `tests/combat_harness.gd`: phantom-stomp two-sided check; ward-consumption
   check; sleeping-player-is-stompable check.
5. Register in `GameManager.HERO_ROSTER` (this is the LAST code step), run all
   four harnesses + `verify_frames`, feel-test in `duel.tscn`.
6. Docs in the same commit as registration: DESIGN §5.2 rows move from
   "designed" to implemented, IMPLEMENTATION §7 milestone note, handoff.md.
