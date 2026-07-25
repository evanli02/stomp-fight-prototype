class_name Pole extends TerrainElement
## Grab to zero momentum instantly; crawl up/down; jump off either side, aimable
## (DESIGN 6.2). Enters the PoleClimb state. The movement "reset button."
# TODO(M5): on_body_entered -> player.request_state(&"PoleClimb", {pole: self})
