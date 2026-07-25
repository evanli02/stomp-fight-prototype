# Overstomp Art Style Guide

Target: **"pixel Arcane"** — modern-superhero pixel art that borrows Arcane's (Riot/Fortiche) dusk-key lighting, saturated neon-against-shadow palettes, painterly value ramps, and strong rim light — expressed at pixel fidelity. All current assets are programmer placeholders meant to be iterated on or replaced; regenerate them with `python assets/tools/generate_placeholders.py`.

## Global rules
- 16 px tile grid; characters 32×48 logical px; integer scaling only; **Filter = Nearest** on every import.
- Master palette: `palettes/master_palette_32.png` / `.gpl` (loadable in Aseprite/GIMP/Libresprite). Stay inside it; propose additions via PR note.
- Fake the painterly look with 2–3 tone ramps per material + a 1px rim light on the key-light side (we default key light = up-right, dusk warm).
- Readability beats detail: silhouettes and accent colors must be parseable at gameplay zoom during fast movement.

## Characters (`characters/`)
- 32×48. **The top 12 px (25%) is the head/stomp hurtbox — always mark it with the hero's accent color (cowl/helmet/hair glow)** so the kill zone is legible.
- Each hero: dark suit base from the night/teal ramps + one signature neon accent slice: Deadeye magenta `#ff2e88`, Skyla cyan `#2de2e6`, Mason amber `#ffb454`, Nova violet `#9d4edd`.
- Team read = rim-light color only (blue `#457b9d` vs red `#e63946`), never recolor the suit.
- Needed animation set per hero (M4+): idle 4f, run 6f, jump/rise 2f, fall 2f, dash 2f, wall-slide 1f, stun 2f, stomped-pop 5f, ability cast 3f. Placeholders ship idle + a 3f run strip showing sheet layout (32px columns, left-to-right).
- Squash-and-stretch: exaggerate on jump start (stretch), landing (squash), and the stomp bounce (both, hard).

## Ability icons (`abilities/`)
- 16×16 on `#1a1030` field with `#5b5b7a` frame; one concept, one accent color; must read at 100%.

## Stage tiles & mocks (`stages/`)
- One 16×16 tile per terrain element, color-coded to gameplay: green = spring, cyan = speed/wind, gold = stun line, violet = portal, red = explosion, pale blue = ice.
- `mock_rooftop_rumble.png` shows target composition: 4-band dusk gradient sky, teal rooftops, sealed edges, hazards popping in neon. Make one mock per new stage before tiling it.
- Stun/hazard telegraphy always uses the gold→white ramp; danger imminent = red `#e63946`.

## VFX language
- Stun: gold stars + brief desaturation. Grace: 4 Hz alpha blink. Ultimate: 1-frame full-screen chromatic pulse in the hero accent. Perfect b-hop/wall-jump: tiny white spark at contact (teach the timing visually).
