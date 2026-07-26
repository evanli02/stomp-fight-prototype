extends Node
## Movement mechanics harness (M1). Drives synthetic input through the playground
## and asserts the DESIGN 4 rules numerically — the regression net under the
## movement code that M2+ will keep refactoring. Feel itself is still judged by a
## human in playground.tscn; this only guards the mechanics.
##
## Not a GUT test: it needs a live scene tree, physics ticks, and real collision.
##   /Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
##     res://tests/movement_harness.tscn
## Exits non-zero if any check fails.
##
## Writing checks: pin the aim vector with the aim_* actions. The aim is always
## live (DESIGN 7), and headless leaves the "mouse" at the origin, which silently
## tilts wall jumps and steers air dashes.

var _failures: int = 0
var _player: Player
var _pg: Node2D

func _ready() -> void:
	_pg = load("res://src/stage/playground.tscn").instantiate() as Node2D
	add_child(_pg)
	await get_tree().physics_frame
	_player = _pg.get_node("%Player") as Player
	await _run()
	print("\n%s" % ("ALL CHECKS PASSED" if _failures == 0 else "%d CHECK(S) FAILED" % _failures))
	get_tree().quit(1 if _failures > 0 else 0)

#region harness
func step(frames: int) -> void:
	for i in frames:
		await get_tree().physics_frame

## Input actions are namespaced per player slot, so everything here goes through
## InputConfig.action() rather than naming "move_right" directly.
func press(action: StringName) -> void:
	Input.action_press(InputConfig.action(_player.player_id, action))

func release(action: StringName) -> void:
	Input.action_release(InputConfig.action(_player.player_id, action))

func reset_at(pos: Vector2, settle: int = 20) -> void:
	for a in InputConfig.ACTIONS:
		release(a)
	_player.global_position = pos
	_player.velocity = Vector2.ZERO
	_player.momentum_charge = 0.0
	_player.dash_charges_left = _player.movement.dash_charges
	_player.air_dash_locked = false
	_player.wall_jump_chain = 0
	await step(settle)

func state() -> String:
	return String(_player.state_machine.state_name())

func check(label: String, ok: bool, detail: String = "") -> void:
	if not ok:
		_failures += 1
	print("%s %s %s" % ["PASS" if ok else "FAIL", label, detail])

func near(a: float, b: float, tol: float) -> bool:
	return absf(a - b) <= tol

## Apex height gained from the current position, over the given frame budget.
func measure_apex(frames: int) -> float:
	var start_y := _player.global_position.y
	var best := start_y
	for i in frames:
		await get_tree().physics_frame
		best = minf(best, _player.global_position.y)
		if _player.is_on_floor() and i > 5:
			break
	return start_y - best
#endregion

func _run() -> void:
	await _check_land()
	await _check_run_to_cap()
	await _check_jump_heights()
	await _check_bhop()
	await _check_dash()
	await _check_wall()

func _check_land() -> void:
	await step(60)
	check("spawn falls and lands", _player.is_on_floor() and state() == "Idle", "state=%s" % state())

func _check_run_to_cap() -> void:
	await reset_at(Vector2(200, 300))
	press(&"move_right")
	await step(88)  # ~1.47s of runway before the far wall
	var cap := _player.speed_cap()
	check("run builds momentum to full", _player.momentum_charge >= 0.9,
		"momentum=%.2f" % _player.momentum_charge)
	check("run reaches the momentum cap", near(_player.velocity.x, cap, 12.0),
		"vx=%.1f cap=%.1f" % [_player.velocity.x, cap])
	check("cap tracks momentum toward run_speed_cap",
		cap > _player.movement.run_speed_base and cap <= _player.movement.run_speed_cap,
		"cap=%.1f" % cap)
	release(&"move_right")
	await step(30)

func _check_jump_heights() -> void:
	# Min hop: DESIGN 4.2 says ~2.5 tiles (40px).
	await reset_at(Vector2(200, 300))
	press(&"jump")
	await step(1)
	release(&"jump")
	var min_apex: float = await measure_apex(90)
	check("min hop ~= 2.5 tiles", near(min_apex, 40.0, 6.0), "apex=%.1fpx (%.2f tiles)" % [min_apex, min_apex / 16.0])

	# Full hold: DESIGN 4.2 says ~4.5 tiles (72px).
	await reset_at(Vector2(200, 300))
	press(&"jump")
	var full_apex: float = await measure_apex(90)
	release(&"jump")
	check("full hold ~= 4.5 tiles", near(full_apex, 72.0, 8.0), "apex=%.1fpx (%.2f tiles)" % [full_apex, full_apex / 16.0])
	check("hold extends the jump", full_apex > min_apex + 20.0,
		"min=%.1f full=%.1f" % [min_apex, full_apex])
	await step(20)

func _check_bhop() -> void:
	# Run to cap, jump, and land — then compare jumping inside vs outside the
	# b-hop window (DESIGN 4.2).
	await reset_at(Vector2(200, 300))
	press(&"move_right")
	await step(80)
	var charge_before := _player.momentum_charge
	var vx_before := _player.velocity.x

	# Outside the window: momentum should decay by momentum_keep_on_landing.
	# Input is released on the way up so Run cannot rebuild what we're measuring.
	press(&"jump")
	await step(2)
	release(&"jump")
	release(&"move_right")
	while not _player.is_on_floor():
		await get_tree().physics_frame
	await step(20)  # well past bhop_window (0.08s = ~5 frames)
	var expected := charge_before * _player.movement.momentum_keep_on_landing
	check("normal landing costs momentum", near(_player.momentum_charge, expected, 0.12),
		"charge %.2f -> %.2f (expected ~%.2f)" % [charge_before, _player.momentum_charge, expected])

	# Inside the window: 100% preserved, and the perfect signal fires.
	await reset_at(Vector2(200, 300))
	press(&"move_right")
	await step(60)  # short of the far wall, so the landing is what stops us
	var perfect_hits: Array[StringName] = []
	_player.perfect_window_hit.connect(func(kind: StringName) -> void: perfect_hits.append(kind))
	charge_before = _player.momentum_charge
	vx_before = _player.velocity.x
	press(&"jump")
	await step(2)
	release(&"jump")
	while not _player.is_on_floor():
		await get_tree().physics_frame
	# Land, then jump immediately (next frame) — inside bhop_window.
	press(&"jump")
	await step(2)
	release(&"jump")
	check("b-hop fires the perfect signal", perfect_hits.has(&"bhop"), "hits=%s" % [perfect_hits])
	check("b-hop preserves momentum charge", near(_player.momentum_charge, charge_before, 0.05),
		"charge %.2f -> %.2f" % [charge_before, _player.momentum_charge])
	check("b-hop preserves horizontal speed", near(_player.velocity.x, vx_before, 25.0),
		"vx %.1f -> %.1f" % [vx_before, _player.velocity.x])
	release(&"move_right")
	await step(20)

func _check_dash() -> void:
	await reset_at(Vector2(200, 300))
	# Ground dash: surface-parallel, no air lock.
	press(&"move_right")
	await step(5)
	press(&"dash")
	await step(3)  # held across frames so the just_pressed edge can't be missed
	release(&"dash")
	check("ground dash consumes a charge", _player.dash_charges_left == 1,
		"charges=%d" % _player.dash_charges_left)
	check("ground dash does not air-lock", not _player.air_dash_locked)
	check("ground dash is horizontal", is_zero_approx(_player.velocity.y),
		"vy=%.1f" % _player.velocity.y)
	await step(15)
	release(&"move_right")

	# Air dash: locks out the second consecutive airborne dash (DESIGN 4.3).
	# Aim is pinned right into open floor — an air dash follows the aim vector,
	# and an unpinned one lands on the spawn ledge, clearing the lock we test.
	await reset_at(Vector2(300, 300))
	press(&"aim_right")
	press(&"jump")
	await step(6)
	release(&"jump")
	press(&"dash")
	await step(3)
	release(&"dash")
	var after_first := _player.dash_charges_left
	check("air dash consumes a charge", after_first == 1, "charges=%d" % after_first)
	check("air dash sets the lock", _player.air_dash_locked)
	await step(12)
	press(&"dash")
	await step(3)
	release(&"dash")
	check("second airborne dash is blocked", _player.dash_charges_left == after_first,
		"charges=%d" % _player.dash_charges_left)
	release(&"aim_right")
	while not _player.is_on_floor():
		await get_tree().physics_frame
	check("landing clears the air-dash lock", not _player.air_dash_locked)
	await step(10)

func _check_wall() -> void:
	# Pillar B spans y=112..336 with its left face at x=880. Start airborne and
	# adjacent — grounded contact with a wall is Run, not WallSlide.
	await _reach_wall(0, &"aim_left")
	check("reaches wall slide", state() == "WallSlide", "state=%s pos=%.1f" % [state(), _player.global_position.x])
	check("wall slide is slower than free fall",
		_player.velocity.y <= _player.movement.wall_slide_speed_hold + 20.0,
		"vy=%.1f" % _player.velocity.y)
	release(&"aim_left")

	# The aim vector is ALWAYS live and tilts every wall jump (DESIGN 4.4/7), so
	# it has to be pinned or these comparisons measure the mouse, not the chain.
	var first_up: float = await _wall_jump_vy(0, &"aim_left")
	check("wall jump leaves the wall", _player.wall_jump_chain == 1 and _player.velocity.x < 0.0,
		"chain=%d vx=%.1f" % [_player.wall_jump_chain, _player.velocity.x])

	# Same aim, chain=1: consecutive jumps go across, not up (DESIGN 4.4).
	var second_up: float = await _wall_jump_vy(1, &"aim_left")
	check("consecutive wall jump loses upward impulse", second_up > first_up * 0.5,
		"first vy=%.1f second vy=%.1f" % [first_up, second_up])
	check("consecutive wall jump keeps horizontal push", absf(_player.velocity.x) > 200.0,
		"vx=%.1f" % _player.velocity.x)

	# Aiming up should steepen the same jump — proves the tilt follows the aim
	# rather than fighting it.
	var aimed_up: float = await _wall_jump_vy(0, &"aim_up")
	check("aimed wall jump tilts toward the aim", aimed_up < first_up,
		"horizontal-aim vy=%.1f up-aim vy=%.1f" % [first_up, aimed_up])

## Fall onto pillar B's left face with the aim pinned, holding until the slide
## actually registers.
func _reach_wall(chain: int, aim_action: StringName) -> bool:
	await reset_at(Vector2(861, 180), 2)
	_player.wall_jump_chain = chain
	press(aim_action)
	press(&"move_right")
	for i in 30:
		await get_tree().physics_frame
		if state() == "WallSlide":
			release(&"move_right")
			return true
	release(&"move_right")
	return false

## Wall-jump off pillar B at a forced chain count and pinned aim, returning
## velocity.y on the exact frame the jump fires (before gravity touches it).
func _wall_jump_vy(chain: int, aim_action: StringName) -> float:
	var reached: bool = await _reach_wall(chain, aim_action)
	if not reached:
		check("wall-jump setup reached the wall (chain=%d)" % chain, false, "state=%s" % state())
		release(aim_action)
		return 0.0
	press(&"jump")
	var vy := 0.0
	for i in 10:
		await get_tree().physics_frame
		if _player.wall_jump_chain > chain:
			vy = _player.velocity.y
			break
	release(&"jump")
	release(aim_action)
	return vy

	# The overhang (x=400..496, y=160..176) is above jump height: dash up into it
	# and confirm it reads as a ceiling, not a wall (DESIGN 4.4).
	await reset_at(Vector2(440, 300))
	press(&"jump")
	await step(8)
	release(&"jump")
	press(&"aim_up")
	press(&"dash")
	await step(3)
	release(&"dash")
	release(&"aim_up")
	var hit_ceiling := false
	for i in 20:
		await get_tree().physics_frame
		if _player.is_on_ceiling():
			hit_ceiling = true
			break
	check("dash reaches the overhang", hit_ceiling, "y=%.1f" % _player.global_position.y)
	check("ceiling never becomes a wall", state() != "WallSlide", "state=%s" % state())
	check("ceiling touch clears the air-dash lock", not _player.air_dash_locked)
	await step(20)
