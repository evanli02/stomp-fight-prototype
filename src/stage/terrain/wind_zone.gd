class_name WindZone extends TerrainElement
## Constant directional force, no stun. Airborne players affected ~2x more than
## grounded (DESIGN 6.2). Applied in physics_effect.
@export var force: Vector2 = Vector2(300, 0)
@export var airborne_multiplier: float = 2.0
# TODO(M5)
