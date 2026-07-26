class_name SkidState extends PlayerState
## The cost of redirecting from high momentum (DESIGN 4.1): a short brake before
## the flip, its length scaled by how much momentum is being thrown away.

var _remaining: float = 0.0

func enter(_params: Dictionary = {}) -> void:
	_remaining = player.movement.skid_time_at_cap * maxf(player.momentum_charge, 0.25)

func exit() -> void:
	# Paid on every exit route (flip, jump, dash) so skidding is never free.
	player.momentum_charge *= player.movement.momentum_keep_on_skid

func physics_update(delta: float) -> void:
	if try_dash():
		return
	if try_ground_jump():
		return
	if not player.is_on_floor():
		machine.change_state(&"Air")
		return
	if try_crouch():  # bailing out of a redirect into a slide is legal tech
		return
	_remaining -= delta
	player.velocity.y = 0.0
	player.velocity.x = move_toward(player.velocity.x, 0.0, player.ground_accel() * delta)
	if _remaining <= 0.0 or is_zero_approx(player.velocity.x):
		machine.change_state(&"Idle" if is_zero_approx(player.input.move.x) else &"Run")
