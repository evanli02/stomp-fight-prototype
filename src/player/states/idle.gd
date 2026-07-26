class_name IdleState extends PlayerState
## Grounded with no horizontal input: bleed speed off with ground friction
## (DESIGN 4.1).

func physics_update(delta: float) -> void:
	if try_dash():
		return
	if try_ground_jump():
		return
	if not player.is_on_floor():
		machine.change_state(&"Air")
		return
	if try_crouch():
		return
	player.velocity.y = 0.0
	player.velocity.x = move_toward(player.velocity.x, 0.0, player.ground_friction() * delta)
	if not is_zero_approx(player.input.move.x):
		machine.change_state(&"Run")

func animation() -> StringName: return &"idle"
