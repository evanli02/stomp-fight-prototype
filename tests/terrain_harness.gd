extends Node
## Terrain harness (M5). Every element in the DESIGN 6.2 catalog, checked against
## what it is supposed to do to a player — and against the rule none of them may
## break: terrain stuns, pushes, launches, and redirects, but it can never remove
## a life (CLAUDE.md 1).
##
##   Godot --headless --path . res://tests/terrain_harness.tscn
## Exits non-zero if any check fails.

const FLOOR_Y: float = 344.0
## Empty air in the middle of the stage. Rooftop Rumble now has its own terrain
## in it, and a check that lands on a stage spring is measuring the wrong thing.
const TEST_X: float = 368.0
## A clear column over the rooftop. The pole checks need air both above and BELOW
## the grab point - a spot with a platform under it lands the body before the
## slide can be measured, and a leap that clips a wall measures the wall.


const POLE_AT: Vector2 = Vector2(400, 250)

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
	await _check_rooftop_portals()
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

	# Down rides the pole instead of letting go: the fast way down IS the pole.
	await park(POLE_AT, Vector2.ZERO)
	_p.state_machine.change_state(&"PoleClimb", {
		"pole_x": POLE_AT.x, "climb_speed": pole.climb_speed,
		"jump_off": pole.jump_off_impulse,
		"top": POLE_AT.y - 60.0, "bottom": POLE_AT.y + 60.0})
	Input.action_press(InputConfig.action(0, &"move_down"))
	await step(4)
	check("down rides the pole down rather than dropping off",
		_p.state_machine.state_name() == &"PoleClimb"
			and _p.velocity.y > _p.movement.fall_speed_max * 0.4,
		"state=%s vy=%.0f" % [_p.state_machine.state_name(), _p.velocity.y])

	# Down AND jump is what lets go now.
	Input.action_press(InputConfig.action(0, &"jump"))
	await step(3)
	Input.action_release(InputConfig.action(0, &"jump"))
	check("down plus jump lets go of the pole",
		_p.state_machine.state_name() != &"PoleClimb",
		"state=%s" % _p.state_machine.state_name())
	Input.action_release(InputConfig.action(0, &"move_down"))
	await step(2)

	# Dash on the pole is a boosted drop straight down.
	await park(POLE_AT, Vector2.ZERO)
	_p.state_machine.change_state(&"PoleClimb", {
		"pole_x": POLE_AT.x, "climb_speed": pole.climb_speed,
		"jump_off": pole.jump_off_impulse,
		"top": POLE_AT.y - 60.0, "bottom": POLE_AT.y + 60.0})
	await step(2)
	var charges := _p.dash_charges_left
	Input.action_press(InputConfig.action(0, &"dash"))
	await step(2)
	Input.action_release(InputConfig.action(0, &"dash"))
	check("dashing on a pole drops you straight down at speed",
		_p.velocity.y >= _p.movement.fall_speed_max - 1.0
			and is_zero_approx(_p.velocity.x),
		"v=%s" % _p.velocity)
	check("the pole drop spends a dash charge", _p.dash_charges_left < charges,
		"%d -> %d" % [charges, _p.dash_charges_left])

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

## Rooftop Rumble's channel teleporters are ONE-WAY, and that is the whole reason
## falling into a channel costs anything. A pair wired both ways would make the
## channels a free elevator, so this asserts the direction rather than trusting
## the wiring to stay right.
##
## Runs while the stage from _ready is still up, before the cryo check tears it
## down.
func _check_rooftop_portals() -> void:
	var entrances := 0
	var arrivals: Array[Portal] = []
	for child in _stage.get_children():
		var portal := child as Portal
		if portal == null:
			continue
		if portal.linked_portal.is_empty():
			arrivals.append(portal)
		else:
			entrances += 1
	check("rooftop has two channel entrances", entrances == 2, "entrances=%d" % entrances)

	# A channel entrance has to fill its channel wall to wall and reach the floor.
	# Any strip of floor beside one is somewhere to stand at the bottom of the
	# stage, which is exactly what the channels must not offer.
	var narrow := ""
	for child in _stage.get_children():
		var door := child as Portal
		if door == null or door.linked_portal.is_empty():
			continue
		var left: float = door.position.x - door.size.x * 0.5
		var right: float = door.position.x + door.size.x * 0.5
		var wall_side: float = 16.0 if left < 576.0 else 976.0
		var roof_side: float = 176.0 if left < 576.0 else 1136.0
		if minf(left, right) > minf(wall_side, roof_side) + 0.5 				or maxf(left, right) < maxf(wall_side, roof_side) - 0.5:
			narrow += " %s spans %.0f..%.0f" % [door.position, left, right]
		if door.position.y + door.size.y * 0.5 < 623.0:
			narrow += " %s stops above the floor" % door.position
	check("a channel entrance fills its channel down to the floor", narrow.is_empty(),
		narrow)

	# The outer platforms hang PAST the roof edges, out over the channels - but
	# not so far that they roof one over. A covered channel is a channel you
	# cannot fall into, which would quietly remove the stage's whole down-side.
	var overhang := ""
	for block: Rect2 in (_stage as MatchStage).platforms():
		var left: float = block.position.x
		var right: float = left + block.size.x
		if left < 176.0:
			if right <= 176.0:
				overhang += " %s is entirely off the roof" % block
			elif left < 16.0 + 96.0:
				overhang += " %s covers too much of the left channel" % block
		elif right > 976.0:
			if left >= 976.0:
				overhang += " %s is entirely off the roof" % block
			elif right > 1136.0 - 96.0:
				overhang += " %s covers too much of the right channel" % block
	check("the outer platforms overhang without roofing the channels",
		overhang.is_empty(), overhang)

	# The pole over the centre platform: reachable by jumping from it, and topping
	# out level with the arrival pads.
	var mid_pole: Pole = null
	for child in _stage.get_children():
		var candidate := child as Pole
		if candidate != null:
			mid_pole = candidate
	check("rooftop hangs a pole over the centre platform", mid_pole != null)
	if mid_pole != null:
		var bottom: float = mid_pole.position.y + mid_pole.size.y * 0.5
		var top: float = mid_pole.position.y - mid_pole.size.y * 0.5
		var standing_head: float = 224.0 - 24.0 - 17.0
		check("the pole hangs clear of a head on the centre platform",
			bottom < standing_head, "bottom=%.0f head=%.0f" % [bottom, standing_head])
		check("but inside a held jump from it",
			standing_head - bottom < StageGrid.JUMP_APEX,
			"gap=%.0f jump=%.0f" % [standing_head - bottom, StageGrid.JUMP_APEX])
		check("and tops out level with the arrival pads",
			absf(top - 88.0) < 1.0, "top=%.0f" % top)
	check("and two arrival pads", arrivals.size() == 2, "arrivals=%d" % arrivals.size())

	# The load-bearing half: standing in an arrival pad must do nothing at all.
	if arrivals.is_empty():
		return
	var pad: Portal = arrivals[0]
	await park(pad.global_position, Vector2.ZERO)
	var start := _p.global_position
	await step(6)
	check("an arrival pad never sends anyone back down",
		_p.global_position.distance_to(start) < 120.0,
		"moved from %s to %s" % [start, _p.global_position])

	# ...and the entrance still works, upward and across.
	var door: Portal = null
	for child in _stage.get_children():
		var portal := child as Portal
		if portal != null and not portal.linked_portal.is_empty():
			door = portal
			break
	var exit_at: Vector2 = door.get_node(door.linked_portal).global_position
	await park(door.global_position + Vector2(0, -40), Vector2(0, 200))
	var went := false
	for i in 30:
		await get_tree().physics_frame
		if _p.global_position.distance_to(exit_at) < 80.0:
			went = true
			break
	check("a channel entrance sends you to the far top corner", went,
		"at=%s expected near %s" % [_p.global_position, exit_at])
	check("the channel teleport costs no life", lives() == MatchState.LIVES_PER_HERO,
		"lives=%d" % lives())

## Cryo Lab as a whole stage. The claims worth asserting are the ones the rebuild
## rests on: every surface is ice with no patch of grip left behind, the three
## portal pairs are linked to the right partners, and the lower chamber has a way
## up that is not a portal.
##
## Rooftop Rumble comes down first - two stages in one physics world would have
## their geometry overlapping, and every measurement after that is fiction.
func _check_cryo_lab() -> void:
	_stage.queue_free()
	await step(2)
	var lab := load("res://src/stage/cryo_lab.tscn").instantiate() as MatchStage
	add_child(lab)
	await step(2)

	var ice: Array[Ice] = []
	var poles := 0
	var portals: Array[Portal] = []
	var lines := 0
	for child in lab.get_children():
		if child is Ice:
			ice.append(child)
		elif child is Pole:
			poles += 1
		elif child is Portal:
			portals.append(child)
		elif child is StunLine:
			lines += 1
	check("cryo lab has no stun lines left", lines == 0, "lines=%d" % lines)
	check("cryo lab hangs three poles", poles == 3, "poles=%d" % poles)
	# Poles have to be out of reach from the ground: a body standing on the floor
	# tops out at FLOOR - 41, and a pole you can touch while standing is a ladder,
	# not a leap.
	var standing_head: float = 496.0 - 41.0
	var low := ""
	for child in lab.get_children():
		var pole := child as Pole
		if pole == null:
			continue
		var bottom: float = pole.position.y + pole.size.y * 0.5
		if bottom > standing_head - 10.0:
			low += " pole at %s reaches %.0f" % [pole.position, bottom]
	check("no pole can be grabbed without jumping", low.is_empty(), low)
	check("cryo lab places three portal pairs", portals.size() == 6,
		"portals=%d" % portals.size())

	# Every walkable surface iced, floor included. One un-iced platform would be
	# the single patch of grip in an ice level, which is worse than either choice.
	var surfaces: Array[Rect2] = lab.platforms()
	var bare := ""
	for block: Rect2 in surfaces:
		var covered := false
		for sheet: Ice in ice:
			var left: float = sheet.position.x - sheet.size.x * 0.5
			var right: float = sheet.position.x + sheet.size.x * 0.5
			if left <= block.position.x + 1.0 					and right >= block.position.x + block.size.x - 1.0 					and absf(sheet.position.y - (block.position.y - 24.0)) < 4.0:
				covered = true
				break
		if not covered:
			bare += " %s" % block
	check("every platform is iced", bare.is_empty(), bare)
	check("the floor is iced too", ice.size() == surfaces.size() + 1,
		"sheets=%d surfaces=%d" % [ice.size(), surfaces.size()])

	# Every platform needs a body's height of clearance under whatever is above
	# it, or it is decoration you cannot stand on.
	var crushed := ""
	for block: Rect2 in surfaces:
		for other: Rect2 in surfaces:
			if other == block or other.position.y >= block.position.y:
				continue
			var overlaps: bool = other.position.x < block.position.x + block.size.x 				and other.position.x + other.size.x > block.position.x
			var headroom: float = block.position.y - (other.position.y + other.size.y)
			if overlaps and headroom < 36.0:
				crushed += " %s under %s (%.0fpx)" % [block, other, headroom]
	check("every platform has standing headroom", crushed.is_empty(), crushed)

	# Pairs point at their own partner, and partners share a colour. A pair wired
	# to the wrong end would still teleport, just not where the colour promised.
	var wired := true
	var mismatched := ""
	for portal: Portal in portals:
		var other := portal.get_node_or_null(portal.linked_portal) as Portal
		if other == null or other.get_node_or_null(other.linked_portal) != portal:
			wired = false
			continue
		if not portal.accent.is_equal_approx(other.accent):
			mismatched += " %s" % portal.position
	check("every portal is linked back to its own partner", wired)
	check("both ends of a pair share a colour", mismatched.is_empty(), mismatched)

	# The stage has to be survivable and sealed with all of that in it.
	var bounds := Vector2(lab.arena_size()) * float(Arena.TILE)
	var lives_before := lives()
	var escaped := ""
	for i in 180:
		await get_tree().physics_frame
		for p: Player in lab.players:
			var at := p.global_position
			if at.x < 0.0 or at.y < 0.0 or at.x > bounds.x or at.y > bounds.y:
				escaped = "%s outside %s" % [at, bounds]
	check("cryo lab is sealed - nobody leaves the box", escaped.is_empty(), escaped)
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
