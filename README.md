# OVERSTOMP

A 1v1 / 2v2 / 3v3 **stomp-to-kill hero platform fighter** for Godot 4.4+. Pick 3 superheroes a round, swap freely, and eliminate the enemy team the only way possible: by jumping on their heads. Fast momentum movement (b-hops, wall-jump chains, omni-dashes) meets hero utility abilities and a one-ultimate-per-round economy. Pixel art aiming for the lighting of *Arcane*; game feel aiming for *Mario* legs and *Smash* brains.

**Status: skeleton.** Design and architecture are complete; systems are contracted stubs awaiting implementation (milestones in `docs/IMPLEMENTATION.md` §7).

## Map of the repo

| Path | What |
|---|---|
| `docs/DESIGN.md` | Authoritative game design (rules, movement, heroes, stages, controls, art) |
| `docs/IMPLEMENTATION.md` | Architecture, contracts, signal map, milestone order, doc-upkeep rules |
| `docs/SETUP.md` | Install Godot/Git/GUT/art tools on your machine |
| `docs/OPUS_PROMPT.md` | Copy-paste prompt to drive Claude Opus 5 implementation sessions |
| `CLAUDE.md` | Binding rules for AI agents working in this repo |
| `SKILL.md` | Agent workflows (add hero / terrain / tune / update docs) |
| `src/` | GDScript skeleton: autoloads, player + movement state machine, abilities, terrain contract |
| `assets/` | Pixel art + `STYLE_GUIDE.md` + the stdlib-only generators in `tools/` |
| `tests/` | GUT test stubs defining required logic coverage |

## Quick start
1. Follow `docs/SETUP.md` (Godot 4.4+, Git; GUT + Aseprite recommended).
2. Open `project.godot` in Godot; F5 should run the stub menu clean.
3. To build with Claude: open Claude Code at the repo root and paste `docs/OPUS_PROMPT.md`. Start at Milestone M1.

## The five laws (see CLAUDE.md for all of them)
1. Only stomps remove lives. 2. Stages are sealed. 3. Heroes differ only by ability + ultimate. 4. One ultimate per player per round. 5. Feel numbers live in `.tres` configs.
