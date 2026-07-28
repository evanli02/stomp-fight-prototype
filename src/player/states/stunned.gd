class_name StunnedState extends PlayerState
## No inputs, momentum preserved, gravity applies (DESIGN 5.4). The head hurtbox
## stays ACTIVE — stun into stomp is the core combo; only post-stomp grace
## disables it (CLAUDE.md checklist). Swapping out is blocked while here (M3).

func physics_update(delta: float) -> void:
	# Frozen: pinned in the air, gravity suspended. When the freeze runs out the
	# player just falls — the drop is gravity, not a push (DESIGN 5.2 Keystone).
	if player.freeze_remaining > 0.0:
		player.velocity = Vector2.ZERO
		return
	if player.is_on_floor():
		player.velocity.y = 0.0
	else:
		player.velocity.y = minf(
			player.velocity.y + player.movement.gravity * delta,
			player.movement.fall_speed_max)
	# velocity.x is deliberately untouched: being stunned never costs momentum.
	if player.stun_remaining <= 0.0:
		# A stun landed on a sleeping player suspends the sleep rather than
		# replacing it — coming out of the stun hands them back to it, so
		# stunning someone can never be a way to wake them up.
		if player.sleep_remaining > 0.0:
			machine.change_state(&"Sleeping")
			return
		machine.change_state(&"Idle" if player.is_on_floor() else &"Air")

func animation() -> StringName: return &"stun"
