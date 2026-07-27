extends Node
## Measures what a player can actually reach, by flying the real body through the
## real state machine — no arithmetic on config numbers, because the numbers do
## not account for the boost window, momentum cap, air control, or the frame
## granularity that decides whether a 96px gap is crossable or a coin flip.
##
## Output is the reach envelope a stage has to be built against (docs/MAPS.md).
## Re-run it after ANY tune: commit to a movement number and these change.
##
##   Godot --headless --path . res://tools/measure_reach.tscn

const SETTLE: int = 24
const FLIGHT: int = 150         ## frames to watch an arc before giving up

var _pg: Node2D
var _p: Player
var _rows: Array[String] = []

func _ready() -> void:
	_pg = load("res://src/stage/playground.tscn").instantiate() as Node2D
	add_child(_pg)
	await get_tree().physics_frame
	_p = _pg.get_node("%Player") as Player
	await _measure()
	_report()
	get_tree().quit(0)

#region rig
func step(frames: int) -> void:
	for i in frames:
		await get_tree().physics_frame

func press(a: StringName) -> void:
	Input.action_press(InputConfig.action(_p.player_id, a))

func release(a: StringName) -> void:
	Input.action_release(InputConfig.action(_p.player_id, a))

func reset_at(pos: Vector2) -> void:
	for a in InputConfig.ACTIONS:
		release(a)
	_p.global_position = pos
	_p.velocity = Vector2.ZERO
	_p.momentum_charge = 0.0
	_p.dash_charges_left = _p.movement.dash_charges
	_p.dash_recharge_remaining = 0.0
	_p.air_dash_locked = false
	_p.wall_jump_chain = 0
	_p.stun_remaining = 0.0
	await step(SETTLE)

## Put the body into a running state at a given speed without needing the runway
## to build it. Holding right for three seconds runs into the far wall of any
## stage big enough to measure in; setting the speed and the momentum charge
## directly lands in exactly the state a capped run produces.
func launch_at(pos: Vector2, speed: float) -> void:
	await reset_at(pos)
	press(&"move_right")
	_p.velocity.x = speed
	_p.momentum_charge = clampf(speed / _p.movement.run_speed_cap, 0.0, 1.0)
	await step(2)

## Floor y of the playground, found rather than hardcoded so a retuned debug
## stage does not silently shift every number in the table.
func floor_y() -> float:
	await reset_at(Vector2(200, 200))
	for i in 120:
		await get_tree().physics_frame
		if _p.is_on_floor():
			break
	return _p.global_position.y

func row(what: String, value: String, note: String) -> void:
	_rows.append("%-34s %-14s %s" % [what, value, note])

func tiles(px: float) -> String:
	return "%.0fpx (%.1ft)" % [px, px / 16.0]
#endregion

func _measure() -> void:
	var ground := await floor_y()
	await _jumps(ground)
	await _runs(ground)
	await _dashes(ground)
	await _walls(ground)
	await _slide(ground)

## Vertical reach: how high a platform can sit above the one you left.
func _jumps(ground: float) -> void:
	_rows.append("")
	_rows.append("VERTICAL - how far above a surface the next one can sit")
	for hold: bool in [false, true]:
		await reset_at(Vector2(300, ground - 40))
		var start := _p.global_position.y
		press(&"jump")
		var apex := start
		for i in FLIGHT:
			await get_tree().physics_frame
			apex = minf(apex, _p.global_position.y)
			if not hold and i == 1:
				release(&"jump")
			if i > 4 and _p.is_on_floor():
				break
		release(&"jump")
		row("jump apex, %s" % ("held" if hold else "tapped"), tiles(start - apex),
			"clearance needed to reach a ledge" if hold else "the smallest hop")

	# Jump + up-dash at the apex: the true ceiling of a single air trip.
	await reset_at(Vector2(300, ground - 40))
	var start2 := _p.global_position.y
	press(&"jump")
	await step(20)
	release(&"jump")
	press(&"move_up")
	press(&"dash")
	var apex2 := start2
	for i in FLIGHT:
		await get_tree().physics_frame
		apex2 = minf(apex2, _p.global_position.y)
		if i > 6 and _p.is_on_floor():
			break
	release(&"dash")
	release(&"move_up")
	row("jump + up-dash apex", tiles(start2 - apex2), "the absolute ceiling from flat ground")

## Horizontal reach: how wide a gap can be.
func _runs(ground: float) -> void:
	_rows.append("")
	_rows.append("HORIZONTAL - how wide a gap can be")
	var speeds: Array[float] = [0.0, _p.movement.run_speed_base, _p.movement.run_speed_cap]
	var labels: Array[String] = ["standing", "base run", "capped run"]
	for i in speeds.size():
		await launch_at(Vector2(120, ground - 40), speeds[i])
		var launch := _p.global_position.x
		press(&"jump")
		var far := launch
		for f in FLIGHT:
			await get_tree().physics_frame
			far = maxf(far, _p.global_position.x)
			if f > 4 and (_p.is_on_floor() or _p.is_on_wall()):
				break
		release(&"jump")
		release(&"move_right")
		row("held jump, %s" % labels[i], tiles(far - launch), "vx=%.0f at launch" % speeds[i])

	# Jump then dash forward: the widest ordinary crossing.
	await launch_at(Vector2(120, ground - 40), _p.movement.run_speed_cap)
	var launch2 := _p.global_position.x
	press(&"jump")
	await step(14)
	release(&"jump")
	press(&"dash")
	var far2 := launch2
	for f in FLIGHT:
		await get_tree().physics_frame
		far2 = maxf(far2, _p.global_position.x)
		if f > 6 and (_p.is_on_floor() or _p.is_on_wall()):
			break
	release(&"dash")
	release(&"move_right")
	row("capped jump + air dash", tiles(far2 - launch2), "the widest gap worth building")

func _dashes(ground: float) -> void:
	_rows.append("")
	_rows.append("DASH - reach in one dash, from a standstill")
	# Ground dash.
	await reset_at(Vector2(200, ground - 40))
	press(&"move_right")
	await step(2)
	var from := _p.global_position.x
	press(&"dash")
	await step(14)
	release(&"dash")
	release(&"move_right")
	row("ground dash", tiles(_p.global_position.x - from), "shorter than the air dash on purpose")

	# Air dash, flat and dived.
	for down: bool in [false, true]:
		await reset_at(Vector2(200, ground - 200))
		press(&"move_right")
		if down:
			press(&"move_down")
			release(&"move_right")
		await step(2)
		var f2 := _p.global_position
		press(&"dash")
		await step(10)
		release(&"dash")
		release(&"move_right")
		release(&"move_down")
		var moved: float = absf(_p.global_position.y - f2.y) if down \
			else _p.global_position.x - f2.x
		row("air dash, %s" % ("straight down" if down else "sideways"), tiles(moved),
			"nerfed hard - diagonals are not" if down else "the range tool")

## Wall geometry. The rise is derived from the impulse rather than flown: a
## measured climb depends on where the test pillars happen to be, and the number
## a stage needs is "how much height does one kick buy".
func _walls(_ground: float) -> void:
	_rows.append("")
	_rows.append("WALLS - shafts and climbs")
	var g := _p.movement.gravity
	var up: float = absf(_p.movement.walljump_impulse.y)
	var later: float = up * _p.movement.walljump_later_up_mult
	row("first wall jump, rise", tiles(up * up / (2.0 * g)), "off a fresh wall face")
	row("same-wall repeat, rise", tiles(later * later / (2.0 * g)),
		"chains on ONE wall barely climb - by design")
	row("wall jump, horizontal push", tiles(_p.movement.walljump_impulse.x * 0.35),
		"roughly, before air control")
	row("wall dash along a face", tiles(_p.movement.dash_distance_wall),
		"climbing stays expensive")
	_rows.append("  -> a climbable shaft needs TWO facing walls: a different face")
	_rows.append("     resets the chain to full impulse, the same face does not.")
	_rows.append("     Known-good widths: 64px (Rooftop, duels happen), 128px (Cryo).")

func _slide(ground: float) -> void:
	_rows.append("")
	_rows.append("SLIDE - the low, long option")
	await launch_at(Vector2(120, ground - 40), _p.movement.run_speed_cap)
	press(&"move_down")
	await step(4)
	var from := _p.global_position.x
	press(&"jump")
	await step(3)
	release(&"jump")
	release(&"move_down")
	var far := from
	for f in FLIGHT:
		await get_tree().physics_frame
		far = maxf(far, _p.global_position.x)
		if f > 4 and (_p.is_on_floor() or _p.is_on_wall()):
			break
	release(&"move_right")
	row("slide jump from a capped run", tiles(far - from), "low arc, long gap")
	row("crouched body height", "17px (1.1t)", "half the 34px standing body")

func _report() -> void:
	print("\n=== OVERSTOMP REACH ENVELOPE ===")
	print("Measured by flying the real body. Tile = 16px. Body = 22x34.")
	print("Re-run after any movement tune: tools/measure_reach.tscn\n")
	for r in _rows:
		print(r)
	print("\n=== END ===")
