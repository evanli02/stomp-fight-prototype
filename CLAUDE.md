# CLAUDE.md — Overstomp

Context and rules for AI agents (Claude Code / Opus 5) working in this repository. Read this fully before writing code.

## What this project is

Overstomp is a 1v1/2v2/3v3 **stomp-to-kill platform fighter** built in **Godot 4.4+ / GDScript**. Players pick 3 superheroes per round, swap between them freely, and eliminate enemies **only** by jumping on their heads. Movement is fast and momentum-driven (b-hops, wall-jump chains, omnidirectional dashes). Full rules: `docs/DESIGN.md` (authoritative). Architecture: `docs/IMPLEMENTATION.md`. Repo-specific workflow: `SKILL.md`.

## Non-negotiable game rules (do not "fix" these)

1. **Only stomps remove lives.** No ability, ultimate, hazard, or fall may ever remove a life. If you find code that lets anything else deal a "kill," it is a bug.
   - *One thing looks like an exception and is not:* Terra's Slam can end in a life loss, because a slam is a very fast fall and falling onto a head **is** the stomp system. It resolves through `receive_stomp` with grace, anti-chain, and victim authority intact. There is no bypass anywhere in the code, and `combat_harness.gd` asserts both halves (head hit costs a life; the shockwave alone never does). Do not "fix" it, and do not copy the pattern into an ability that is not literally a fall.
2. **Stages are sealed.** No pits, no out-of-bounds deaths, no self-elimination.
3. **All heroes share identical movement, hitboxes, hurtboxes, stompboxes.** Hero identity = 1 ability + 1 ultimate + cosmetics, nothing else. Never add per-hero speed/jump modifiers except through ability effects. Current geometry: sprites 32×36, body 22×34, head hurtbox the top 10 px, stompbox the bottom 14 px (+6 px past the feet). Changing any of these means changing `player.tscn` **and** the generator's proportions together.
4. **Two ultimates per player per round** with a ~10 s gap between them, shared across their 3 heroes (`MatchState.ULTS_PER_ROUND` / `ULT_COOLDOWN`). *Changed from one-per-round by the project owner on 2026-07-26 — DESIGN §2.3 is authoritative and matches.*
5. **Hero swap has no cooldown**; cooldowns are per-hero and tick while benched; swap is blocked only while stunned.
6. **Air dash restriction:** no two consecutive dashes airborne; surface touch resets. On surfaces, consecutive dashes are legal, and surface dashes are constrained parallel to the surface. Airborne dashes are also directionally taxed: **up** keeps ~22% of its reach, **straight down** ~30% and no post-dash boost. Diagonals are deliberately untouched.
7. **Consecutive wall jumps lose upward impulse** (first is full; later ones are mostly horizontal). **Ceilings are never wall-jumpable.**
8. **Stomped players keep momentum**, get a contact-point-based bounce, a stun (0.6 s), then a grace period with head hurtbox disabled.
9. **Players are terrain to each other side-on**; wall-jump duels stun the loser; simultaneous (ally or enemy) duels give both a juiced wall jump.

## Architecture rules

- **State machine for movement** (`src/player/states/`). New movement behavior = new state or transition. Never `if`-ladder movement logic inside `player.gd`.
- **Abilities are components** (`src/heroes/abilities/`), subclasses of `Ability`, attached to the player at spawn from `HeroData` resources. Abilities interact with the player through its public API (impulses, state requests, spawning scene effects) — never by reaching into state internals.
- **All tunables live in `.tres` resources** (`src/config/`, `src/heroes/resources/`). Never hardcode a feel number in a script. If you need a new number, add it to the relevant config resource with a comment.
- **Signals over polling** for game events: `stomped`, `life_lost`, `hero_eliminated`, `round_won`, `ultimate_spent`, `stun_applied`. `GameManager` (autoload) orchestrates match/round flow; `MatchState` (autoload) is the single source of truth for lives/rosters/ult availability.
- **Fixed physics tick** (60 Hz) for all gameplay; interpolate visuals. Do not put gameplay logic in `_process`.
- **Terrain elements** are self-contained scenes in `src/stage/terrain/`, each implementing the `TerrainElement` contract (see IMPLEMENTATION.md §4). Stages are TileMap + placed terrain scenes.
- Determinism posture: keep gameplay logic free of wall-clock time and `randomize()` (use a seeded RNG in `GameManager`) so rollback netcode remains possible later.

## Code style

- GDScript, tabs, static typing everywhere (`var speed: float`, typed arrays, `-> void`).
- `snake_case` files/functions/variables, `PascalCase` classes/nodes, `SCREAMING_SNAKE` constants, signals in past tense (`life_lost`).
- One class per file; `class_name` for anything referenced across files.
- Every scene has exactly one script on its root; child nodes accessed via `@onready` + `%UniqueName`.
- Prefer composition. No inheritance deeper than 2 (e.g., `Ability` → `DeadeyeBolt` is fine).
- Comments explain *why*, not *what*. Doc-comment (`##`) every public function on manager/API classes.

## Workflow rules

- Run in small steps: implement → open in editor / run scene → verify → commit. Commits: `feat(scope): ...`, `fix:`, `tune:`, `art:`, `docs:`.
- **Feel changes** (any number in a config resource) get their own `tune:` commits so they can be reverted independently of logic.
- Update `docs/IMPLEMENTATION.md` **in the same commit** as any architectural change (new autoload, new state, new signal, new terrain contract method).
- Tests: **headless harnesses in `tests/`, not GUT** (GUT is never installed here; `tests/test_match_state.gd` is a legacy stub that logs one harmless parse error on load). Four harnesses — `movement`, `combat`, `match`, `terrain` — plus `verify_frames.gd`. Run all of them before committing; see `handoff.md` for the exact commands. Physics *feel* is still judged by a human in `playground.tscn` / `duel.tscn`.
- Milestone order lives in `docs/IMPLEMENTATION.md` §7 — follow it; don't build heroes before movement feels good.

## Things Claude tends to get wrong here (checklist)

- [ ] Don't give the stomp bounce or ability knockbacks the power to remove lives via "environmental damage" — there is no damage, only lives and stomps.
- [ ] Don't reset ability cooldowns on swap.
- [ ] Don't let swap cancel stuns, or let ult be used while stunned.
- [ ] Stun refresh rule is `max(remaining, new)`, never additive.
- [ ] The controller ultimate is the R2+L2 **chord** — make sure it suppresses the individual dash/swap presses when it triggers.
- [ ] B-hop and perfect wall jump share the same "perfect window preserves momentum" pattern — implement once, reuse.
- [ ] Grace period disables only the **head hurtbox**, not collision (they're still terrain to others).
- [ ] Godot 4 syntax only (no `onready var` without `@`, no `yield`, use `await`; `move_and_slide()` takes no args on CharacterBody2D).
- [ ] `signi()` takes an **int** — `signi(0.7)` truncates to 0. Use `1 if x > 0.0 else -1` for float signs. This silently broke sprite facing on analog sticks for a whole session.
- [ ] GDScript has **no tuple literals**: `for x in (1, 2)` is a parse error; use `[1, 2]`. Loop vars over float arrays often need `for x: float in [...]`.
- [ ] Lambdas capture locals **by value** — a flag set inside `func(): done = true` never escapes. Use a one-element array.
- [ ] A launch applied to a grounded body is erased next frame: `Idle`/`Run` zero `velocity.y` while on the floor. Anything that launches (springs, pads) must also `request_state(&"Air")`.
- [ ] Detecting overlap with `body_entered` misses bodies that are already inside the area. Everything that must affect a resting or re-entering body re-scans overlaps each tick with a per-player re-trigger gap (`TerrainElement`, both Mason blocks).
