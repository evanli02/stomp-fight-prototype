# Overstomp Art Style Guide

Target: **"pixel Arcane"** — modern-superhero pixel art that borrows Arcane's (Riot/Fortiche) dusk-key lighting, saturated neon-against-shadow palettes, painterly value ramps, and strong rim light — expressed at pixel fidelity.

Everything here is generated, and regenerating is the intended way to iterate. Both scripts are **stdlib-only Python** (no Pillow) on the shared canvas in `tools/pixel.py`, so a clean checkout can rebuild every asset:

```
python assets/tools/generate_characters.py     # heroes: sheets + SpriteFrames
python assets/tools/generate_placeholders.py   # icons, tiles, palette, stage mock
Godot --headless --path . --import             # so Godot picks up new PNGs
```

Hand-editing a generated PNG works, but the next run overwrites it — port the change back into the generator, or take the file out of the generator's output list first.

## Global rules
- 16 px tile grid; characters 32×48 logical px; integer scaling only; **Filter = Nearest** on every import.
- Master palette: `palettes/master_palette_32.png` / `.gpl` (loadable in Aseprite/GIMP/Libresprite). Stay inside it; propose additions via PR note.
- Fake the painterly look with 2–3 tone ramps per material + a 1px rim light on the key-light side (we default key light = up-right, dusk warm).
- Readability beats detail: silhouettes and accent colors must be parseable at gameplay zoom during fast movement.

## Characters (`characters/<hero>/<animation>.png`)

One PNG per animation, frames laid left-to-right in 32px columns. `<hero>_frames.tres` in `src/heroes/resources/frames/` is generated beside them and is what `AnimatedSprite2D` actually loads.

### Non-negotiables
- **32×48, feet on row 47.** Identical for every hero — heroes share movement, hitboxes, and silhouette *size* (DESIGN 5.1). Only identity differs.
- **The top 12 px is the head/stomp hurtbox, and the accent owns it.** That band is the kill zone (DESIGN 3.1); if a player cannot see where it ends, the core mechanic is unreadable. Crouched and sliding frames drop the whole body into the bottom 24 px, with the accent band in rows 24–30 to match the shrunken head box.
- Dark suit from the night/teal ramps + one signature neon: Deadeye magenta `#ff2e88`, Skyla cyan `#2de2e6`, Mason amber `#ffb454`, Nova violet `#9d4edd`.
- **Internal keylines, not just an outline.** Every limb is drawn with its own 1px dark border. A dark suit against a dark stage collapses into one blob otherwise, and the back leg has to stay separable from the front leg while both are in shadow.
- Suit midtones are tinted ~20% toward the hero's accent. The night palette is too narrow for an untinted ramp to hold up at gameplay zoom.
- Rim light on the up-right key side, fading toward the midtone further down the body — a uniform bright edge reads as an outline, not as light.
- Squash-and-stretch: exaggerate on jump start (stretch), landing (squash), and the stomp bounce (both, hard).

### Animation set (per hero, 41 frames)
| Animation | Frames | FPS | Loops | Driven by |
|---|---|---|---|---|
| `idle` | 4 | 6 | yes | `Idle` |
| `run` | 6 | 14 | yes | `Run` |
| `rise` | 2 | 8 | no | `Air`, rising |
| `fall` | 2 | 8 | yes | `Air`, falling |
| `land` | 2 | 14 | no | `player.gd`, first 0.12s after a landing |
| `dash` | 2 | 16 | no | `Dash` |
| `skid` | 2 | 10 | yes | `Skid` |
| `crouch` | 2 | 4 | yes | `Crouch` |
| `slide` | 2 | 8 | yes | `Slide` |
| `slide_jump` | 2 | 10 | no | `Air`, launched from a slide |
| `wall_slide` | 2 | 6 | yes | `WallSlide` |
| `wall_jump` | 2 | 12 | no | `Air`, launched off a wall |
| `pole_climb` | 2 | 6 | yes | `PoleClimb` |
| `stun` | 2 | 5 | yes | `Stunned` |
| `cast` | 2 | 12 | no | ability use (M4, art ready) |
| `pop` | 5 | 12 | no | `Player.play_elimination()` |

Adding an animation means adding it to `ANIMATIONS` in the generator **and** to the state that requests it — the movement harness fails if any state names an animation no hero has.

### Hero identities
Each is a different silhouette and one unmistakable prop, so heroes are told apart at gameplay zoom during fast movement — not by hue alone, which fails for colorblind players and in a screenshot full of neon.

| Hero | Build | Head | Prop / tell |
|---|---|---|---|
| **Deadeye** | slimmest, coat tails flare when moving | brimmed cowl, horizontal visor slit | bolt pistol, chest bandolier |
| **Skyla** | narrow shoulders, streamlined | finned aero helmet, goggle lenses | streaming scarf, vented jet boots |
| **Mason** | widest, blockiest | hard hat with a front-heavy brim, brow lamp | slab pauldrons, oversized gauntlets |
| **Nova** | broad and low | deep hood, violet halo ring, face in shadow | gravity orb, ring motif everywhere |

### Team read (deferred)
Team is meant to read as **rim-light color** (blue `#457b9d` vs red `#e63946`), never by recoloring the suit. That needs a shader pass and lands in M6. Until then the duel stage gives its two seats visually opposite heroes instead of tinting them, because tinting a whole sprite is exactly what this rule forbids.

## Ability icons (`abilities/`)
- 16×16 on `#1a1030` field with `#5b5b7a` frame; one concept, one accent color; must read at 100%.

## Stage tiles & mocks (`stages/`)
- One 16×16 tile per terrain element, color-coded to gameplay: green = spring, cyan = speed/wind, gold = stun line, violet = portal, red = explosion, pale blue = ice.
- `mock_rooftop_rumble.png` shows target composition: 4-band dusk gradient sky, teal rooftops, sealed edges, hazards popping in neon. Make one mock per new stage before tiling it.
- Stun/hazard telegraphy always uses the gold→white ramp; danger imminent = red `#e63946`.

## VFX language
- Stun: gold stars + brief desaturation. Grace: 4 Hz alpha blink. Ultimate: 1-frame full-screen chromatic pulse in the hero accent. Perfect b-hop/wall-jump: tiny white spark at contact (teach the timing visually).
