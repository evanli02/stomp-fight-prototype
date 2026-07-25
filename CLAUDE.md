# CLAUDE.md — Overstomp

Context and rules for AI agents (Claude Code / Opus 5) working in this repository. Read this fully before writing code.

## What this project is

Overstomp is a 1v1/2v2/3v3 **stomp-to-kill platform fighter** built in **Godot 4.4+ / GDScript**. Players pick 3 superheroes per round, swap between them freely, and eliminate enemies **only** by jumping on their heads. Movement is fast and momentum-driven (b-hops, wall-jump chains, omnidirectional dashes). Full rules: `docs/DESIGN.md` (authoritative). Architecture: `docs/IMPLEMENTATION.md`. Repo-specific workflow: `SKILL.md`.

## Non-negotiable game rules (do not "fix" these)

1. **Only stomps remove lives.** No ability, ultimate, hazard, or fall may ever remove a life. If you find code that lets anything else deal a "kill," it is a bug.
2. **Stages are sealed.** No pits, no out-of-bounds deaths, no self-elimination.
3. **All heroes share identical movement, hitboxes, hurtboxes, stompboxes.** Hero identity = 1 ability + 1 ultimate, nothing else. Never add per-hero speed/jump modifiers except through ability effects.
4. **One ultimate per player per round**, shared across their 3 heroes.
5. **Hero swap has no cooldown**; cooldowns are per-hero and tick while benched; swap is blocked only while stunned.
6. **Air dash restriction:** no two consecutive dashes airborne; surface touch resets. On surfaces, consecutive dashes are legal, and surface dashes are constrained parallel to the surface.
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
- Tests: pure-logic systems (match state, cooldowns, stun table, ult economy) get GUT tests in `tests/`. Physics feel is validated by the debug playground scene (`src/stage/playground.tscn`), not unit tests.
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
