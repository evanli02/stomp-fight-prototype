class_name JumpSpring extends TerrainElement
## Fixed strong launch: set_velocity_override on the vertical component.
## Chainable with b-hops (DESIGN 6.2).
@export var launch_velocity: Vector2 = Vector2(0, -700)
# TODO(M5)
