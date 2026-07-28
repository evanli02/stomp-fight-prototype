# OPUS_PROMPT.md — Implementation Kickoff Prompt

Paste the prompt below into a fresh Claude Opus 5 / Claude Code session started at the repo root. It is written to be reusable: run it once per milestone by changing the milestone number in the final line.

---

```
You are implementing Overstomp, a Godot 4.4+ / GDScript platform fighter where players
eliminate each other exclusively by jumping on heads. This repository already contains
the complete design and architecture — your job is to implement against it, not to
redesign it.

Before writing any code, read in this order:
1. CLAUDE.md            — binding rules: game invariants, architecture rules, code style,
                          and a checklist of known failure modes. Treat every item as a
                          hard constraint.
2. SKILL.md             — repo workflows (adding heroes/terrain, tuning, doc upkeep).
3. docs/DESIGN.md       — the authoritative spec. Sections: match flow (2), stomp (3),
                          movement (4), heroes (5), terrain (6), controls (7), art (8).
4. docs/IMPLEMENTATION.md — node/scene architecture, autoloads, player public API,
                          terrain contract, signal map, and the milestone order in §7.

Ground rules for this session:
- Follow the milestone order in IMPLEMENTATION.md §7 strictly. Do not implement heroes
  before movement passes its exit criteria; do not build stages before the terrain
  contract works in the playground.
- All game-feel numbers go in .tres config resources, never in scripts. When you need a
  number the design doesn't specify, add it to the config with a comment and flag it in
  your summary as a tuning decision.
- Movement logic goes in the state machine (src/player/states/). Abilities are Ability
  components using only the Player public API. Terrain elements implement the
  TerrainElement contract.
- Only stomps may remove lives. If any code path you write could remove a life through
  an ability, ultimate, or hazard, it is wrong — stop and restructure.
- Work in small verifiable increments: implement one system, run the relevant scene
  (playground.tscn for movement), fix errors, commit with the conventional prefixes
  from CLAUDE.md, then continue.
- Update docs/IMPLEMENTATION.md in the same commit as any architectural change, per
  its §8.
- Existing files in src/ are intentional stubs with contracts and TODOs — flesh them
  out in place rather than replacing their structure. Keep static typing everywhere.
- At the end of the session, produce: (a) a summary of what was implemented and
  verified, (b) any deviations from the design and why, (c) the list of tuning
  decisions you made, (d) what the next session should start with.

Current task: implement Milestone M1 (Movement core) to its exit criteria: a playable
playground scene where b-hop chains, wall-jump chains with upward decay, aimed wall
jumps, variable jumps with coyote/buffer, and the 2-charge dash with the air-consecutive
restriction all work and are readable on the debug overlay.
```

---

## Follow-up prompts per milestone

Reuse the prompt with the last paragraph swapped:

- **M2**: "implement Milestone M2 (Stomp loop): stomp detection with relative-velocity check, lives, stun/grace/bounce per DESIGN §3.2, players-as-terrain with wall-jump duels, and local 2-player input (KBM + controller incl. the R2+L2 ultimate chord stub)."
- **M3**: "implement Milestone M3 (Match structure): MatchState with full GUT test coverage of lives/eliminations/round wins/ultimate economy/stage-picker logic, hero select, free swap with per-hero benched-ticking cooldowns, and the in-round HUD."
- **M4**: "implement Milestone M4: the four vertical-slice heroes (Deadeye, Skyla, Mason, Nova) per DESIGN §5.2, as Ability components."
- **M5**: "implement Milestone M5: the TerrainElement roster (pole, ice, stun line, spring, speed pad, portals, wind, explosion) and the Rooftop Rumble + Cryo Lab stages."
- **M6**: "implement Milestone M6: 2v2/3v3, stage select flow with coinflip/loser-picks, Bo1/3/5, and a first VFX/SFX readability pass."
- **M7 (the second hero wave)**: "implement the four designed heroes — Voodoo, Saint, Vesper, Siku — from docs/NEW_HEROES.md. That file is the authoritative spec: read it fully first, alongside CLAUDE.md. Art, HeroData resources, and ability skeletons with final tunables already exist; your job is §1's shared systems (impulse buff, contact debuff, phasing, cleanse, stomp ward, the sleep system + Sleeping state), then the kits in the skeleton files, then the harness cases in §4 — registration in GameManager.HERO_ROSTER is the LAST step, after everything passes. The interaction table in §3 is a list of assertions to write, not trivia. Rule 1 note: Voodoo's phantom stomp resolves through receive_stomp like Terra's slam, and Saint's ward consumes INSIDE receive_stomp — no new life-touching paths exist anywhere in this wave."

## Tips for driving the sessions

- Ask for the session-end summary before context runs long; start the next session fresh with the next milestone line — CLAUDE.md + IMPLEMENTATION.md carry the state.
- When feel is off, prompt with observed behavior + desired behavior ("wall-jump chains gain height; DESIGN 4.4 says later jumps should be mostly horizontal") rather than proposed code.
- Have it write the GUT test *first* for any MatchState/logic change.
