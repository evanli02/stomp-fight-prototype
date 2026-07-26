class_name WallJumpState extends PlayerState
## One-tick impulse state (DESIGN 4.4): away from the wall, tilted within the aim
## cone, with the upward component collapsing on consecutive jumps so chains
## travel across rather than up. Ceilings never reach here — WallSlide filters
## them by normal.

func enter(_params: Dictionary = {}) -> void:
	var cfg := player.movement
	var n := player.wall_normal
	var up_mult := 1.0 if player.wall_jump_chain == 0 else cfg.walljump_later_up_mult
	var impulse := Vector2(n.x * cfg.walljump_impulse.x, cfg.walljump_impulse.y * up_mult)
	impulse = _apply_aim_tilt(impulse)

	# Kicking off another player is a duel: whoever inputs first stuns the other,
	# and a tie juices both (DESIGN 3.4). The player arbitrates; the state just
	# takes the multiplier back.
	if player.wall_player != null and is_instance_valid(player.wall_player):
		impulse *= player.claim_wall_duel(player.wall_player, impulse)

	# Wall analog of the b-hop: jumping inside the window keeps the momentum
	# charge (and so the speed cap) you arrived with.
	if player.perfect_window_check(player.time_since_wall_contact, cfg.walljump_perfect_window):
		player.note_perfect(&"walljump")
	else:
		player.momentum_charge *= cfg.momentum_keep_on_wall_jump

	player.velocity = impulse
	player.wall_jump_chain += 1
	player.facing = signi(n.x)
	machine.change_state(&"Air")

## Tilt the impulse toward the live aim vector, clamped to the cone so an aimed
## wall jump can never point back into the wall (DESIGN 4.4).
func _apply_aim_tilt(impulse: Vector2) -> Vector2:
	var aim := player.input.aim
	if aim.length() < 0.1:
		return impulse
	var cone := deg_to_rad(player.movement.walljump_aim_cone_deg)
	var tilt := clampf(angle_difference(impulse.angle(), aim.angle()), -cone, cone)
	return impulse.rotated(tilt)
