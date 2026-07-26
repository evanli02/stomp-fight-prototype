extends Node
## Terrain harness (M5). Every element in the DESIGN 6.2 catalog, checked against
## what it is supposed to do to a player — and against the rule none of them may
## break: terrain stuns, pushes, launches, and redirects, but it can never remove
## a life (CLAUDE.md 1).
##
##   Godot --headless --path . res://tests/terrain_harness.tscn
## Exits non-zero if any check fails.

const FLOOR_Y: float = 607.0
## Empty air in the middle of the stage. Rooftop Rumble now has its own terrain
## in it, and a check that lands on a stage spring is measuring the wrong thing.
const TEST_X: float = 640.0
## Open sky above the left half of the stage. The pole check needs room to leap
## into: at street level every direction runs into stage geometry within a few
## frames, and a leap that clips a wall measures the wall.
const POLE_AT: Vector2 = Vector2(320, 250)

var _failures: int = 0
var _stage: Node2D
var _p: Player

func _ready() -> void:
	_stage = load("res://src/stage/duel.tscn").instantiate() as Node2D
	add_child(_stage)
	await get_tree().physics_frame
	_p = _stage.get_node("%Player1") as Player
	await _run()
	print("\n%s" % ("ALL CHECKS PASSED" if _failures == 0 else "%d CHECK(S) FAILED" % _failures))
	get_tree().quit(1 if _failures > 0 else 0)

#region harness
func step(frames: int) -> void:
	for i in frames:
		await get_tree().physics_frame

func check(label: String, ok: bool, detail: String = "") -> void:
	if not ok:
		_failures += 1
	print("%s %s %s" % ["PASS" if ok else "FAIL", label, detail])

func lives() -> int:
	return MatchState.lives_of(0, MatchState.active_hero(0))

## Drop an element into the stage at a position and give it a frame to build its
## detection area.
func place_element(element: TerrainElement, at: Vector2, element_size: Vector2) -> TerrainElement:
	element.size = element_size
	element.global_position = at
	_stage.add_child(element)
	await get_tree().physics_frame
	return element

## Park FIRST, then place the element being tested. park() re-asserts position a
## frame later (physics can depenetrate a teleported body), and that second write
## would overwrite the very launch a spring or pad had just applied.
func park(at: Vector2, velocity: Vector2 = Vector2.ZERO) -> void:
	_settle(at, velocity)
	await get_tree().physics_frame
	_settle(at, velocity)

func _settle(at: Vector2, velocity: Vector2) -> void:
	_p.global_position = at
	_p.velocity = velocity
	_p.stun_remaining = 0.0
	_p.freeze_remaining = 0.0
	_p.surface_slip = 0.0
	# Spawn protection turns the head hurtbox off; several checks care that it is
	# on, and none of them are about grace.
	_p.grace_remaining = 0.0
	_p.spawn_protected = false
	_p.set_head_hurtbox_enabled(true)
	_p.state_machine.change_state(&"Air")
#endregion

func _run() -> void:
	await _check_stun_line()
	await _check_jump_spring()
	await _check_speed_pad()
	await _check_wind_zone()
	await _check_ice()
	await _check_portal()
	await _check_explosion()
	await _check_pole()
	await _check_nothing_took_a_life()

func _check_stun_line() -> void:
	var lives_before := lives()
	await park(Vector2(TEST_X, FLOOR_Y), Vector2(200, 0))
	var line: StunLine = await place_element(StunLine.new(),
		Vector2(TEST_X, FLOOR_Y), Vector2(64, 8))
	await step(6)
	check("a stun line stuns on contact", _p.stun_remaining > 0.0,
		"stun=%.2f" % _p.stun_remaining)
	check("the stun line costs no life", lives() == lives_before)
	# Momentum kept, head hurtbox still live — this is a setup tool, not a shield.
	check("a stun line leaves the head hurtbox active", _p.head_hurtbox.monitorable)
	line.queue_free()
	await step(2)

func _check_jump_spring() -> void:
	await park(Vector2(TEST_X, FLOOR_Y), Vector2(240, 0))
	var spring: JumpSpring = await place_element(JumpSpring.new(),
		Vector2(TEST_X, FLOOR_Y), Vector2(48, 16))
	await step(3)
	check("a spring launches upward", _p.velocity.y < -400.0, "vy=%.1f" % _p.velocity.y)
	check("a spring keeps horizontal speed", _p.velocity.x > 150.0, "vx=%.1f" % _p.velocity.x)
	check("a spring clears the air-dash lock", not _p.air_dash_locked)
	spring.queue_free()
	await step(2)

func _check_speed_pad() -> void:
	await park(Vector2(TEST_X, FLOOR_Y), Vector2(60, 0))
	var pad: SpeedPad = await place_element(SpeedPad.new(),
		Vector2(TEST_X, FLOOR_Y), Vector2(48, 16))
	pad.direction = Vector2.RIGHT
	await step(2)
	check("a speed pad launches you along its direction",
		_p.velocity.x >= pad.boost_speed * 0.8, "vx=%.1f" % _p.velocity.x)
	check("a speed pad grants the boost window so the cap cannot eat it",
		_p.dash_boost_remaining > 0.0, "boost=%.2f" % _p.dash_boost_remaining)
	pad.queue_free()
	await step(2)

func _check_wind_zone() -> void:
	await park(Vector2(TEST_X, FLOOR_Y - 120))
	var wind: WindZone = await place_element(WindZone.new(),
		Vector2(TEST_X, FLOOR_Y - 120), Vector2(160, 120))
	wind.force = Vector2(400, 0)
	var before := _p.velocity.x
	await step(10)
	check("wind pushes an airborne player", _p.velocity.x > before + 30.0,
		"vx %.1f -> %.1f" % [before, _p.velocity.x])
	check("wind never stuns", is_zero_approx(_p.stun_remaining))
	wind.queue_free()
	await step(2)

func _check_ice() -> void:
	await park(Vector2(TEST_X, FLOOR_Y), Vector2(300, 0))
	var ice: Ice = await place_element(Ice.new(),
		Vector2(TEST_X, FLOOR_Y + 24), Vector2(160, 16))
	await step(6)
	check("standing on ice raises slip", _p.surface_slip > 0.5,
		"slip=%.2f" % _p.surface_slip)
	check("ice cuts ground friction", _p.ground_friction() < _p.movement.ground_friction * 0.5,
		"%.0f vs %.0f" % [_p.ground_friction(), _p.movement.ground_friction])
	check("ice widens the b-hop window", _p.bhop_window() > _p.movement.bhop_window,
		"%.3f vs %.3f" % [_p.bhop_window(), _p.movement.bhop_window])
	ice.queue_free()
	await step(20)
	check("slip decays once you leave the ice", _p.surface_slip <= 0.0,
		"slip=%.2f" % _p.surface_slip)

func _check_portal() -> void:
	await park(Vector2(TEST_X - 40, FLOOR_Y - 60), Vector2(320, 0))
	var a: Portal = await place_element(Portal.new(),
		Vector2(TEST_X, FLOOR_Y - 60), Vector2(32, 48))
	var b: Portal = await place_element(Portal.new(),
		Vector2(TEST_X + 200, FLOOR_Y - 60), Vector2(32, 48))
	a.linked_portal = a.get_path_to(b)
	b.linked_portal = b.get_path_to(a)
	# Speed has to be sampled on the frame BEFORE the jump: the approach is a
	# fall, so a baseline taken any earlier is measuring gravity, not the portal.
	var speed_before := 0.0
	var teleported := false
	for i in 20:
		var was := _p.velocity.length()
		var x0 := _p.global_position.x
		await get_tree().physics_frame
		if _p.global_position.x - x0 > 100.0:
			speed_before = was
			teleported = true
			break
	check("a portal moves you to its pair", teleported and _p.global_position.x > TEST_X + 150.0,
		"x=%.1f" % _p.global_position.x)
	check("a portal preserves speed", absf(_p.velocity.length() - speed_before) < 40.0,
		"%.1f -> %.1f" % [speed_before, _p.velocity.length()])
	# The lockout is what stops the pair ping-ponging a body forever.
	await step(4)
	check("the exit does not immediately send you back",
		_p.global_position.x > TEST_X + 100.0, "x=%.1f" % _p.global_position.x)
	a.queue_free()
	b.queue_free()
	await step(2)

func _check_explosion() -> void:
	await park(Vector2(TEST_X, FLOOR_Y - 20))
	var vent: ExplosionHazard = await place_element(ExplosionHazard.new(),
		Vector2(TEST_X, FLOOR_Y), Vector2(32, 32))
	vent.period = 0.4
	vent.warning_time = 0.2
	var lives_before := lives()
	var blasted: bool = false
	for i in 60:
		await get_tree().physics_frame
		if _p.stun_remaining > 0.0:
			blasted = true
			break
	check("an explosion vent stuns whoever is in range", blasted,
		"stun=%.2f" % _p.stun_remaining)
	check("an explosion costs no life", lives() == lives_before)
	vent.queue_free()
	await step(2)

func _check_pole() -> void:
	await park(POLE_AT - Vector2(60, 0), Vector2(380, -200))
	var pole: Pole = await place_element(Pole.new(), POLE_AT, Vector2(8, 120))
	await step(12)
	check("grabbing a pole enters PoleClimb",
		_p.state_machine.state_name() == &"PoleClimb",
		"state=%s" % _p.state_machine.state_name())
	check("grabbing a pole zeroes momentum",
		_p.velocity.length() < 1.0 and is_zero_approx(_p.momentum_charge),
		"v=%s charge=%.2f" % [_p.velocity, _p.momentum_charge])
	check("a pole refills the dash", _p.dash_charges_left == _p.movement.dash_charges)

	# Jump off: the movement stick picks the side.
	Input.action_press(InputConfig.action(0, &"move_left"))
	Input.action_press(InputConfig.action(0, &"jump"))
	await step(6)
	Input.action_release(InputConfig.action(0, &"jump"))
	Input.action_release(InputConfig.action(0, &"move_left"))
	check("jumping off a pole leaves toward the held side",
		_p.velocity.x < -100.0 and _p.state_machine.state_name() != &"PoleClimb",
		"vx=%.1f state=%s" % [_p.velocity.x, _p.state_machine.state_name()])
	pole.queue_free()
	await step(2)

func _check_nothing_took_a_life() -> void:
	check("no terrain element removed a life",
		lives() == MatchState.LIVES_PER_HERO, "lives=%d" % lives())
