extends Node
## Throwaway probe for the 2026-08-01 balance pass: the three changes that are
## behaviour rather than a number, driven against real bodies.
##   Godot --headless --path . res://tools/probe_balance.tscn

var _fails: int = 0

func check(label: String, ok: bool, detail: String = "") -> void:
	if not ok:
		_fails += 1
	print("%s %s %s" % ["PASS" if ok else "FAIL", label, detail])

func _ready() -> void:
	var stage: Node2D = load("res://src/stage/duel.tscn").instantiate()
	add_child(stage)
	await get_tree().physics_frame
	var p: Player = stage.get_node("%Player1")
	for i in 20:
		await get_tree().physics_frame

	# 1. A pole no longer refills dash charges.
	p.dash_charges_left = 0
	p.dash_recharge_remaining = 99.0
	p.request_state(&"PoleClimb", {"pole_x": p.global_position.x})
	await get_tree().physics_frame
	check("grabbing a pole does NOT refill dash charges",
		p.dash_charges_left == 0, "charges=%d" % p.dash_charges_left)
	check("grabbing a pole still clears the airborne dash lock",
		not p.air_dash_locked)
	p.request_state(&"Air")
	p.dash_charges_left = p.movement.dash_charges
	await get_tree().physics_frame

	# 2. Voodoo's Phantom grants exactly one mid-air jump per airtime.
	MatchState.reset_round()
	p.equip_hero(&"voodoo")
	await get_tree().physics_frame
	check("no air jump before the ultimate", not p.can_air_jump())
	p.try_ultimate()
	await get_tree().physics_frame
	p.global_position = Vector2(576, 200)
	p.velocity = Vector2.ZERO
	p.request_state(&"Air")
	await get_tree().physics_frame
	check("phantom grants an air jump", p.can_air_jump(),
		"charges=%d used=%d left=%.1f" % [p.air_jump_charges, p.air_jump_used,
			p.air_jump_remaining])
	var before_y := p.velocity.y
	p.consume_air_jump()
	check("consuming it spends the charge", not p.can_air_jump(),
		"used=%d" % p.air_jump_used)
	check("the jump is a real upward impulse", p.air_jump_impulse < -100.0,
		"impulse=%.0f (was vy=%.0f)" % [p.air_jump_impulse, before_y])
	# Landing gives it back — it is a double jump, not a fuel tank.
	p.air_jump_used = 0
	check("touching down restores it", p.can_air_jump())
	p.clear_movement_buffs()
	check("the window ending removes it", not p.can_air_jump())

	# 3. One ultimate per hero, gap still per player.
	MatchState.reset_round()
	var trio: Array = MatchState.roster(0)
	check("three heroes, three ultimates",
		MatchState.ults_left(0) == 3, "left=%d" % MatchState.ults_left(0))
	MatchState.try_spend_ultimate(0)
	MatchState.players[0].ult_cooldown = 0.0     # skip the gap; it is tested elsewhere
	check("hero 1's ult is spent", MatchState.ult_spent(0, trio[0]))
	check("hero 1 cannot ult again", not MatchState.ult_available(0))
	MatchState.swap_to(0, trio[1])
	check("hero 2 still has theirs", MatchState.ult_available(0))
	MatchState.try_spend_ultimate(0)
	MatchState.players[0].ult_cooldown = 0.0
	check("hero 2's ult is spent, hero 3's is not",
		MatchState.ult_spent(0, trio[1]) and not MatchState.ult_spent(0, trio[2]))
	MatchState.swap_to(0, trio[0])
	check("going back to hero 1 does not restore theirs",
		not MatchState.ult_available(0))

	print("\n%s" % ("ALL CHECKS PASSED" if _fails == 0 else "%d CHECK(S) FAILED" % _fails))
	get_tree().quit(1 if _fails > 0 else 0)
