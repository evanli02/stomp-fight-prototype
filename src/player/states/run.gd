class_name RunState extends PlayerState
## Grounded with input: accelerate toward the momentum-scaled cap and build
## momentum with sustained movement. Redirecting at speed hands off to Skid
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
	var dir := player.input.move.x
	if is_zero_approx(dir):
		machine.change_state(&"Idle")
		return
	# Flipping while fast costs a skid; at low speed the redirect is free.
	if signf(dir) != signf(player.velocity.x) and absf(player.velocity.x) > player.movement.run_speed_base:
		machine.change_state(&"Skid")
		return
	player.velocity.y = 0.0
	player.build_momentum(delta)
	var target := signf(dir) * player.speed_cap()
	# Turning around below the skid threshold uses the quicker redirect rate;
	# building speed in the direction you already face uses the slower startup.
	var reversing := not is_zero_approx(player.velocity.x) and signf(dir) != signf(player.velocity.x)
	var accel := player.ground_redirect_accel() if reversing else player.ground_accel()
	player.velocity.x = move_toward(player.velocity.x, target, accel * delta)

func animation() -> StringName: return &"run"
