---
name: overstomp-dev
description: Develop, extend, tune, and debug Overstomp — a Godot 4 stomp-to-kill platform fighter with hero abilities, momentum movement, and round-based 1v1/2v2/3v3 matches. Use this skill whenever the user asks to implement or modify anything in the Overstomp repo — movement states, heroes, abilities, ultimates, stages, terrain elements, match/round flow, HUD, controls, pixel art assets, or game-feel tuning — even if they don't name the game, e.g. "add a new hero", "the wall jump feels floaty", "make an ice stage", "fix the stun", "hook up controller input".
---

# Overstomp Development Skill

You are working in the Overstomp repository: a Godot 4.4+ / GDScript platform fighter where the **only** kill mechanic is jumping on heads. This skill routes you to the right context and encodes the workflows this repo expects.

## Required reading order (progressive)

1. **Always**: `CLAUDE.md` — non-negotiable game rules, architecture rules, style, and the "Claude gets this wrong" checklist.
2. **When touching gameplay rules or adding content**: the relevant section of `docs/DESIGN.md` (authoritative spec — match flow §2, stomp §3, movement §4, heroes §5, terrain §6, controls §7, art §8).
3. **When touching code structure**: `docs/IMPLEMENTATION.md` — node/scene architecture, signal map, terrain contract, milestone order, and "how to update this doc."
4. **When making art**: `assets/STYLE_GUIDE.md` — palette, sizes, per-asset specs, the animation table, and how to regenerate. Character art is generated from a pose rig, so edit `assets/tools/generate_characters.py` rather than the PNGs.

Do not implement from memory of similar games; this game deviates from genre defaults on purpose (no damage, no ring-outs, identical hero movement).

## Core invariants (echoed here because violations are the #1 failure mode)

- Lives are removed by stomps **only**. No damage system exists.
- Heroes differ **only** in ability + ultimate. One ultimate per player per round.
- All feel numbers live in `.tres` configs, never in scripts.
- Movement logic lives in the state machine under `src/player/states/`.
- Stages are sealed; players can't die to the environment.

## Workflows

### Add a hero
1. Read DESIGN.md §5 for constraints and the roster table.
2. Create `src/heroes/resources/<hero>.tres` (HeroData: name, colors, ability scene, ult scene, cooldown).
3. Implement ability + ultimate as `Ability` subclasses in `src/heroes/abilities/` using only the player's public API and scene-spawned effects.
4. Add a `Hero(...)` entry to `assets/tools/generate_characters.py` — colors, build, head style, prop — then re-run it, `--import`, and `verify_frames.gd`. That produces all 16 animations and the SpriteFrames resource; point the hero's `.tres` at it. Register the hero in `GameManager.HERO_ROSTER`.
5. Test in `playground.tscn`: verify the ability cannot remove a life under any circumstance and cooldown ticks while benched.

### Add a terrain element
1. Read DESIGN.md §6.2 and the `TerrainElement` contract in IMPLEMENTATION.md §4.
2. New scene in `src/stage/terrain/`, script extends the contract, all numbers exported or in config.
3. Add to the playground stage for testing; document the element's row in DESIGN.md §6.2 if it's new.

### Tune game feel
1. Change values **only** in `src/config/*.tres` or hero resources.
2. One concern per `tune:` commit with before → after values in the message.
3. Validate with the playground scene's debug overlay (velocity/momentum/state readout).

### Movement changes
1. New behavior = new state or transition in `src/player/states/`; update the state diagram in IMPLEMENTATION.md.
2. Preserve the shared "perfect-window preserves momentum" helper used by b-hop and perfect wall jump.

### Update documentation
Any change to architecture, signals, contracts, or milestones must update `docs/IMPLEMENTATION.md` in the same commit (see its §8 for exactly what to update when).

## Verification checklist before finishing any task

- [ ] Ran the affected scene (or `playground.tscn`) without script errors.
- [ ] No new hardcoded feel numbers in scripts.
- [ ] CLAUDE.md checklist items relevant to the change re-verified.
- [ ] GUT tests updated/added for pure-logic changes (`tests/`).
- [ ] Docs updated if architecture changed.
