# Overstomp Art Style Guide

Target: **comic-book chibi with a punk edge** — Big Hero 6 / My Hero Academia proportions (short bodies, oversized heads ~40% of the frame) wearing cyberpunk gear. Two-plane cel shading instead of painterly ramps, thick keylines inside the silhouette, one loud accent per hero, minimal clutter. The dusk-neon palette survives from the old direction; the rendering style does not.

Everything here is generated, and regenerating is the intended way to iterate. Both scripts are **stdlib-only Python** (no Pillow) on the shared canvas in `tools/pixel.py`, so a clean checkout can rebuild every asset:

```
python assets/tools/generate_characters.py     # heroes: sheets + SpriteFrames
python assets/tools/generate_placeholders.py   # icons, tiles, palette, stage mock
Godot --headless --path . --import             # so Godot picks up new PNGs
```

Hand-editing a generated PNG works, but the next run overwrites it — port the change back into the generator, or take the file out of the generator's output list first.

Besides the twelve heroes the generator also emits **variants**: same rig, different palette, swapped in at runtime and owning no `HeroData`. `voodoo_phantom` is the one that exists — his colours inverted for the duration of his ultimate (suit and accent ramps flipped, skin left alone, because an inverted face reads as a bug rather than as menace). Add one with `inverted(by_key("<hero>"), "<key>", "<name>")` in `VARIANTS`.

## Global rules
- 16 px tile grid; characters 32×36 logical px (34 px body); integer scaling only; **Filter = Nearest** on every import.
- Master palette: `palettes/master_palette_32.png` / `.gpl` (loadable in Aseprite/GIMP/Libresprite). Stay inside it; propose additions via PR note.
- Two-plane cel shading per material + a 1px rim light on the key-light side (key light = up-right, dusk warm). No painterly ramps — this is a comic, not a painting.
- Readability beats detail: silhouettes and accent colors must be parseable at gameplay zoom during fast movement.

## Characters (`characters/<hero>/<animation>.png`)

One PNG per animation, frames laid left-to-right in 32px columns. `<hero>_frames.tres` in `src/heroes/resources/frames/` is generated beside them and is what `AnimatedSprite2D` actually loads.

### Non-negotiables
- **32×36, feet on row 35, body 34 px tall.** Identical for every hero — heroes share movement, hitboxes, and silhouette *size* (DESIGN 5.1). Only identity differs. The head is ~15 px wide and owns the sprite.
- **Everything is drawn facing +x (right).** The engine mirrors it for leftward travel (`flip_h = facing < 0`, pinned by the movement harness). Every forward cue must agree: nose and face features forward, cap and helmet peaks jutting **forward**, capes/scarves/fins trailing **backward**, torso leaning into the direction of travel. A backward-pointing peak makes the whole character read as facing the wrong way even with the eyes drawn correctly — the silhouette wins at gameplay speed, so a head whose mass leans backward will look flipped no matter where the features sit.
- **The top ~10 px is the head/stomp hurtbox, and the accent owns it.** That band is the kill zone (DESIGN 3.1); if a player cannot see where it ends, the core mechanic is unreadable. Crouched and sliding frames drop the body into the bottom half, accent band riding down with it.
- Dark suit + one signature accent: Deadeye red `#e63946`, Fei jade `#3ddc84`, Mason gold `#ffd23f`, Cerebelle **dark** violet `#4c1076` on **white** plate, Sai pink `#ff6ec7`, Slip **deep** blue `#1c6dd0`, Terra **dark** brown `#6b4526`, Kid orange `#ffa521`, Voodoo **bright** purple `#ca5cff`, Saint cream-white `#f2f2fa`, Vesper neon pink `#ff2ec4` on a **black** costume, Siku ice blue `#9edfff`. The hue-family pairs are deliberate splits: Cerebelle went dark so Voodoo could be loud; Slip went deep so Siku could be pale. Vesper's *costume* is black by design, but her accent slots (and `HeroData.accent_color`) carry her eye-pink — a pure black accent would erase the head band, the HUD stripe, and every effect she owns.
- **Internal keylines, not just an outline.** Every limb is drawn with its own 1px dark border. A dark suit against a dark stage collapses into one blob otherwise, and the back leg has to stay separable from the front leg while both are in shadow.
- Suit midtones are tinted ~20% toward the hero's accent. The night palette is too narrow for an untinted ramp to hold up at gameplay zoom. **`accent_tint` scales that**, for heroes whose costume must *not* take the accent's hue: Vesper runs 0.12 so black stays black and the pink stays trim, Cerebelle 0.3 so a dark violet accent cannot wash her white plate lavender.
- **Both eyes, always, and never the same pair twice.** A single eye on a 3/4 face reads as a pure profile at 32px and made every hero's expression identical — the hat was doing all the work. `eye_style` picks the shape: `sharp` (squint under a heavy brow), `almond` (lashes, softer lid), `wide` (big pupils, glint), `calm` (half-lidded), `masked` (glowing slits, no whites), `visor` (the head style draws them instead). The far eye is always dimmer than the near one; that falloff is what stops the head reading flat-on.
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

| Hero | Colour | Head | Tell |
|---|---|---|---|
| **Deadeye** | red | cowboy brim, glowing augmented eye | long split coat, bolt pistol |
| **Fei** | jade | hair bun with a jade pin, band | streaming ribbon scarf |
| **Mason** | gold | fur crown with gold trims | heavy shoulders, huge gauntlets |
| **Cerebelle** | dark violet on white | crested helm over long pale hair | slim build, sleeveless, tattooed arms, war cape |
| **Sai** | pink | sleek visor, swept hair | short scarf, hook at the hip |
| **Slip** | deep blue | tall spiked hair, goggles | backpack gadget |
| **Terra** | dark brown | hard hat, front-heavy brim | widest build, gauntlets |
| **Kid** | bright orange | big round glasses, messy fringe | satchel, chest screen |
| **Voodoo** | bright purple | white doll mask, X eyes, purple head-flames | long coat, stitched-X chest |
| **Saint** | cream white | bare crown, halo circlet | vestment cape, gold-bead cross |
| **Vesper** | black / neon pink | hood + half-mask, two glowing pink eyes | all-black suit, diamond chest mark |
| **Siku** | ice blue | fur-ringed parka hood | chunky coat, snowflake chest mark |

### Team read (deferred)
Team is meant to read as **rim-light color** (blue `#457b9d` vs red `#e63946`), never by recoloring the suit. That needs a shader pass and lands in M6. Until then the duel stage gives its two seats visually opposite heroes instead of tinting them, because tinting a whole sprite is exactly what this rule forbids.

## Ability icons (`abilities/`)
- 16×16 on `#1a1030` field with `#5b5b7a` frame; one concept, one accent color; must read at 100%.

## Stage tiles & mocks (`stages/`)
- One 16×16 tile per terrain element, color-coded to gameplay: green = spring, cyan = speed/wind, gold = stun line, violet = portal, red = explosion, pale blue = ice.
- `mock_rooftop_rumble.png` shows target composition: 4-band dusk gradient sky, teal rooftops, sealed edges, hazards popping in neon. Make one mock per new stage before tiling it.
- Stun/hazard telegraphy always uses the gold→white ramp; danger imminent = red `#e63946`.

## VFX language
- Stun: gold stars + brief desaturation. Grace: 4 Hz alpha blink. **Debuff badges over the head, one per source, distinguished by SHAPE first and colour second** (slash / bolt / bars / ring). Slip's anchor is a pulsing diamond with a countdown arc — an invisible anchor makes the whole ability unreadable for both players. **Stomp: eight-spoke starburst in the attacker's accent at the victim's head — the kill confirm.** Ability/ult: the `cast` flourish plus each effect's own draw. Perfect b-hop/wall-jump: tiny white spark at contact. **Buff windows wear a `HeroAura`** (`src/heroes/effects/hero_aura.gd`): `wind` gusts for Fei's Tailwind, `surge` licks for empowerments (Voodoo — the ult passes a higher intensity so it reads angrier than the ability), `ward` halo for Saint's blessing; Fei's air jump additionally kicks off a `WindPuff` cloud at the cast point. All follower-style effects (stage-parented, tracking the body) — never children of the player.

## Sound

Generated the same way as the art: stdlib Python only, no dependencies, the
*definition* of a sound is the code.

```bash
python assets/tools/generate_sfx.py
```

Writes 18 16-bit mono WAVs to `assets/sfx/` (~208KB total). Godot imports `.wav`
as `AudioStreamWAV` with no import settings. The noise generator is seeded, so a
re-run is byte-identical and a rebuild is not a diff.

Rules for the set:

- **Short.** Nothing here reaches half a second. A sound that outlives its event
  is noise on a screen that is already busy.
- **One idea per cue** — a pitch direction or a texture, not both.
- **The stomp is the loudest thing in the game** and everything else leaves it
  room, because the stomp is the only event that changes the score. Movement
  cues sit around 0.3-0.4 peak; the stomp is 1.0.
- Adding a sound means a `save()` here **and** a line in `Audio.CUES`. The match
  harness checks the two agree in both directions, so one without the other
  fails a test.
