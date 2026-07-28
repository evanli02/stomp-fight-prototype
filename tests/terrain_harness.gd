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
	await _check_timed_stun_line()
	await _check_jump_spring()
	await _check_speed_pad()
	await _check_wind_zone()
	await _check_ice()
	await _check_portal()
	await _check_explosion()
	await _check_pole()
	await _check_bumper_block()
	await _check_nothing_took_a_life()
	await _check_cryo_lab()
	await _check_sunken_court()

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

## A line on a duty cycle (Cryo Lab's grid). The case that matters is the body
## standing in a dark line when it comes back on: entry already happened, so an
## enter-driven hazard would never touch it (CLAUDE.md: body_entered misses
## bodies already inside).
func _check_timed_stun_line() -> void:
	var lives_before := lives()
	await park(Vector2(TEST_X, FLOOR_Y))
	var line := StunLine.new()
	line.cycle_time = 1.0
	line.on_ratio = 0.4
	line.phase_offset = 0.6      # starts dark, roughly half its off-phase in
	line.retrigger = 0.2
	await place_element(line, Vector2(TEST_X, FLOOR_Y), Vector2(64, 8))
	check("a timed line starts dark on a dark phase", not line.is_live())
	await step(2)
	check("a dark line does not stun", is_zero_approx(_p.stun_remaining),
		"stun=%.2f" % _p.stun_remaining)

	# Stand still and wait for it to come back on. The body never re-enters.
	var caught := false
	for i in 90:
		await get_tree().physics_frame
		if _p.stun_remaining > 0.0:
			caught = true
			break
	check("a line that comes on catches a body already standing in it", caught,
		"live=%s stun=%.2f" % [line.is_live(), _p.stun_remaining])
	check("a timed line still costs no life", lives() == lives_before)
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

## Mason's block is a four-sided spring, so the property to check is the spring
## property: the component along the face normal is REPLACED by a fixed launch
## and the tangential component survives. A reflection would scale with how fast
## you arrived; this must not.
##
## Bodies are parked already inside the lingering hitbox rather than flown into
## it. That is how the block actually works — it re-scans overlaps every tick, so
## a body resting against it is thrown the same as one that ran in — and it makes
## the contact face unambiguous, which a falling approach does not.
func _check_bumper_block() -> void:
	var lives_before := lives()
	var at := Vector2(TEST_X, FLOOR_Y - 60)

	# Side face, arriving slowly and quickly. A fixed launch answers both the
	# same; the old elastic version answered neither reliably.
	for incoming: float in [20.0, 620.0]:
		await park(at - Vector2(20.0, 0.0), Vector2(incoming, 0.0))
		var block := BumperBlock.new()
		block.global_position = at
		block.lifetime = 4.0
		_stage.add_child(block)
		var out := 0.0
		for i in 20:
			await get_tree().physics_frame
			if _p.velocity.x < -50.0:
				out = absf(_p.velocity.x)
				break
		check("the side face throws you back (arrived at %.0f)" % incoming, out > 0.0,
			"vx=%.0f" % _p.velocity.x)
		check("the launch is the block's, not your speed returned (arrived at %.0f)"
			% incoming, absf(out - block.bounce_speed) < 40.0,
			"out=%.0f expected ~%.0f" % [out, block.bounce_speed])
		block.queue_free()
		await step(3)

	# Top face: it must pop you up the way a spring does, and keep the run you
	# brought, the way a spring leaves your horizontal speed alone.
	await park(at - Vector2(0.0, 20.0), Vector2(260.0, 120.0))
	var top := BumperBlock.new()
	top.global_position = at
	top.lifetime = 4.0
	_stage.add_child(top)
	var kept := 0.0
	var lifted := 0.0
	for i in 20:
		await get_tree().physics_frame
		if _p.velocity.y < -100.0:
			kept = _p.velocity.x
			lifted = _p.velocity.y
			break
	check("the top face pops you up", lifted < -100.0, "vy=%.0f" % lifted)
	check("and keeps the run you brought into it", kept > 200.0,
		"vx=%.0f, arrived with 260" % kept)
	check("the block costs no life", lives() == lives_before)
	top.queue_free()
	await step(3)

func _check_nothing_took_a_life() -> void:
	check("no terrain element removed a life",
		lives() == MatchState.LIVES_PER_HERO, "lives=%d" % lives())

## Cryo Lab, as a whole stage rather than element by element: it is the first
## stage assembled from terrain rather than decorated with it, so the thing worth
## asserting is that living in it for several grid cycles is survivable and
## sealed.
##
## Rooftop Rumble comes down first — two stages in one physics world would have
## their geometry overlapping, and every measurement after that is fiction.
func _check_cryo_lab() -> void:
	_stage.queue_free()
	await step(2)
	var lab := load("res://src/stage/cryo_lab.tscn").instantiate() as MatchStage
	add_child(lab)
	await step(2)

	var ice := 0
	var lines: Array[StunLine] = []
	var portals: Array[Portal] = []
	for child in lab.get_children():
		if child is Ice:
			ice += 1
		elif child is StunLine:
			lines.append(child)
		elif child is Portal:
			portals.append(child)
	check("cryo lab lays down ice", ice >= 2, "sheets=%d" % ice)
	check("cryo lab lays down a laser grid", lines.size() >= 3, "lines=%d" % lines.size())
	check("cryo lab places exactly one portal pair", portals.size() == 2,
		"portals=%d" % portals.size())
	if portals.size() == 2:
		check("the portal pair points at each other",
			portals[0].get_node_or_null(portals[0].linked_portal) == portals[1]
				and portals[1].get_node_or_null(portals[1].linked_portal) == portals[0])

	# The grid has to actually toggle, or it is just walls with extra steps.
	var seen_live := false
	var seen_dark := false
	var bounds := Vector2(lab.arena_size()) * float(Arena.TILE)
	var lives_before := lives()
	var escaped := ""
	for i in 240:
		await get_tree().physics_frame
		if not lines.is_empty():
			if lines[0].is_live():
				seen_live = true
			else:
				seen_dark = true
		for p: Player in lab.players:
			var at := p.global_position
			if at.x < 0.0 or at.y < 0.0 or at.x > bounds.x or at.y > bounds.y:
				escaped = "%s outside %s" % [at, bounds]
	check("the laser grid cycles", seen_live and seen_dark,
		"live=%s dark=%s" % [seen_live, seen_dark])
	check("cryo lab is sealed — nobody leaves the box", escaped.is_empty(), escaped)
	check("nothing in cryo lab removed a life", lives() == lives_before,
		"lives=%d" % lives())
	lab.queue_free()
	await step(2)

## Sunken Court. The layout claims worth testing are the ones the stage rests on:
## the trench is too deep to jump out of, it has no standing room at all, and the
## springs get you out anyway. If any of those stops being true the stage becomes
## a trap, a rest stop, or a formality.
func _check_sunken_court() -> void:
	var court := load("res://src/stage/sunken_court.tscn").instantiate() as MatchStage
	add_child(court)
	await step(3)
	var p: Player = court.players[0]

	var springs: Array[JumpSpring] = []
	var poles: Array[Pole] = []
	for child in court.get_children():
		if child is JumpSpring:
			springs.append(child)
		elif child is Pole:
			poles.append(child)
	check("sunken court has five springs", springs.size() == 5, "springs=%d" % springs.size())
	check("sunken court has a pole over each mesa", poles.size() == 2, "poles=%d" % poles.size())

	# A pole should sit on top of each spawn, which is also what puts them as far
	# apart as the stage allows.
	var paired := true
	for i in mini(poles.size(), 2):
		paired = paired and absf(poles[i].position.x - court.spawn_for(i).x) < 24.0
	check("each pole sits over a spawn", paired,
		"poles=%s spawns=%s,%s" % [
			[poles[0].position.x, poles[1].position.x] if poles.size() == 2 else [],
			court.spawn_for(0).x, court.spawn_for(1).x])

	check("both seats spawn on the mesa tops",
		is_equal_approx(court.spawn_for(0).y, court.spawn_for(1).y)
			and court.spawn_for(0).x < 448.0 and court.spawn_for(1).x > 448.0,
		"a=%s b=%s" % [court.spawn_for(0), court.spawn_for(1)])

	# No seam anywhere along the trench floor: sort the springs and require each
	# one to start no later than the previous one ended. A 22px body can rest in
	# any gap, and the trench is meant to be passed through, not held.
	springs.sort_custom(func(a: JumpSpring, b: JumpSpring) -> bool:
		return a.position.x < b.position.x)
	var seam := ""
	var reach: float = springs[0].position.x - springs[0].size.x * 0.5
	for spring: JumpSpring in springs:
		var left: float = spring.position.x - spring.size.x * 0.5
		if left > reach + 0.01:
			seam += " gap %.0f..%.0f" % [reach, left]
		reach = maxf(reach, spring.position.x + spring.size.x * 0.5)
	check("the springs leave no standing room in the pit", seam.is_empty(), seam)
	check("the springs span the trench wall to wall",
		springs[0].position.x - springs[0].size.x * 0.5 <= 288.5 and reach >= 607.5,
		"%.0f..%.0f, trench 288..608" % [
			springs[0].position.x - springs[0].size.x * 0.5, reach])

	# The platform is as long as the gap it roofs, and high enough that reaching
	# it costs a dash.
	var platform := Rect2()
	for block: Rect2 in court.arena_blocks():
		if is_equal_approx(block.position.y, 272.0):
			platform = block
	check("the platform is as long as the gap", is_equal_approx(platform.size.x, 320.0),
		"platform=%.0f trench=320" % platform.size.x)
	check("the platform is past a plain held jump",
		368.0 - platform.position.y > StageGrid.JUMP_APEX,
		"rise=%.0f held jump=%.0f" % [368.0 - platform.position.y, StageGrid.JUMP_APEX])
	check("...but inside the jump-plus-dash ceiling",
		368.0 - platform.position.y <= StageGrid.JUMP_DASH_APEX,
		"rise=%.0f ceiling=%.0f" % [368.0 - platform.position.y, StageGrid.JUMP_DASH_APEX])

	# Drop in anywhere and the floor throws you back out. Checked from the very
	# corner of the trench, which is the spot most likely to have been missed.
	p.global_position = Vector2(300.0, 440.0)
	p.velocity = Vector2.ZERO
	p.stun_remaining = 0.0
	await step(30)
	var sprung := 512.0
	for i in 90:
		await get_tree().physics_frame
		sprung = minf(sprung, p.global_position.y)
	check("the pit corner is sprung too, not standable", sprung < 344.0,
		"apex y=%.0f, need < 344 (mesa standing height)" % sprung)
	check("a spring stops short of the platform overhead", sprung > 248.0,
		"apex y=%.0f, platform standing height 248" % sprung)

	check("the trench is deeper than a held jump",
		496.0 - 368.0 > StageGrid.JUMP_APEX,
		"depth=128 held jump=%.0f" % StageGrid.JUMP_APEX)
	check("nothing in sunken court removed a life",
		lives() == MatchState.LIVES_PER_HERO, "lives=%d" % lives())
	court.queue_free()
	await step(2)
