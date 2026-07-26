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
	await _check_overhang()
	await _check_crouch()
	await _check_slide()
	await _check_animation_contract()

func _check_land() -> void:
	await step(60)
	check("spawn falls and lands", _player.is_on_floor() and state() == "Idle", "state=%s" % state())

func _check_run_to_cap() -> void:
	# Startup is the slow part now: base speed takes ground_accel_time, and a
	# third of the way in you should still be well short of it (DESIGN 4.1).
	await reset_at(Vector2(200, 300))
	press(&"move_right")
	var frames_to_base := 0
	for i in 30:
		await get_tree().physics_frame
		frames_to_base += 1
		if absf(_player.velocity.x) >= _player.movement.run_speed_base * 0.99:
			break
	var expected_frames := _player.movement.ground_accel_time * 60.0
	check("reaching base speed takes about ground_accel_time",
		absf(frames_to_base - expected_frames) <= 2.5,
		"%d frames, expected ~%.1f" % [frames_to_base, expected_frames])
	check("startup is slower than the redirect rate",
		_player.ground_accel() < _player.ground_redirect_accel(),
		"startup=%.0f redirect=%.0f" % [_player.ground_accel(), _player.ground_redirect_accel()])
	release(&"move_right")
	await step(20)

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
	# Min hop: DESIGN 4.2 says ~1.25 tiles (20px).
	await reset_at(Vector2(200, 300))
	press(&"jump")
	await step(1)
	release(&"jump")
	var min_apex: float = await measure_apex(90)
	check("min hop ~= 1.25 tiles", near(min_apex, 20.0, 5.0), "apex=%.1fpx (%.2f tiles)" % [min_apex, min_apex / 16.0])

	# Full hold: DESIGN 4.2 says ~4.5 tiles (72px).
	await reset_at(Vector2(200, 300))
	press(&"jump")
	var full_apex: float = await measure_apex(90)
	release(&"jump")
	check("full hold ~= 4.5 tiles", near(full_apex, 72.0, 8.0), "apex=%.1fpx (%.2f tiles)" % [full_apex, full_apex / 16.0])
	check("hold extends the jump", full_apex > min_apex * 2.5,
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
	# Ground dash: surface-parallel, no air lock, and the long one (DESIGN 4.3).
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
	check("ground dash runs at the ground distance",
		near(_player.velocity.x, _player.movement.dash_distance_ground / _player.movement.dash_duration, 1.0),
		"vx=%.1f" % _player.velocity.x)
	# The AIR dash is the long one: on the ground you can already run, so the
	# dash there is a small reposition. Spending it airborne is what pays.
	check("the air dash out-reaches the ground dash",
		_player.movement.dash_distance > _player.movement.dash_distance_ground
		and _player.movement.dash_distance_ground > _player.movement.dash_distance_wall,
		"air=%.0f ground=%.0f wall=%.0f" % [_player.movement.dash_distance,
			_player.movement.dash_distance_ground, _player.movement.dash_distance_wall])
	await step(15)
	release(&"move_right")

	# An upward air dash is cut to a fraction of its reach (DESIGN 4.3): at
	# parity it beats the jump outright.
	await reset_at(Vector2(300, 300))
	press(&"jump")
	await step(6)
	release(&"jump")
	press(&"move_up")
	press(&"dash")
	await step(3)  # the just_pressed edge needs a frame; the dash holds velocity
	var up_speed := _player.velocity.y
	release(&"dash")
	release(&"move_up")
	var flat_speed := _player.movement.dash_distance / _player.movement.dash_duration
	check("upward air dash is cut to air_dash_up_mult",
		near(up_speed, -flat_speed * _player.movement.air_dash_up_mult, 12.0),
		"vy=%.1f expected=%.1f" % [up_speed, -flat_speed * _player.movement.air_dash_up_mult])
	check("the upward air dash climbs about a sixth of a tile per frame",
		absf(up_speed) < 150.0, "vy=%.1f" % up_speed)
	while not _player.is_on_floor():
		await get_tree().physics_frame
	await step(10)

	# Sideways and diagonal air dashes keep the full, now longer, reach.
	await reset_at(Vector2(300, 300))
	press(&"jump")
	await step(6)
	release(&"jump")
	press(&"move_right")
	press(&"dash")
	await step(3)
	var flat_air := _player.velocity.x
	release(&"dash")
	check("sideways air dash runs at the full air distance",
		near(flat_air, flat_speed, 1.0), "vx=%.1f expected=%.1f" % [flat_air, flat_speed])
	release(&"move_right")
	while not _player.is_on_floor():
		await get_tree().physics_frame
	await step(10)

	# Up-diagonal: the horizontal half is untouched, only the climb is cut.
	await reset_at(Vector2(300, 300))
	press(&"jump")
	await step(6)
	release(&"jump")
	press(&"move_right")
	press(&"move_up")
	press(&"dash")
	await step(3)
	var diag := _player.velocity
	release(&"dash")
	release(&"move_up")
	release(&"move_right")
	check("up-diagonal air dash keeps its horizontal reach",
		near(diag.x, flat_speed * sqrt(0.5), 12.0),
		"vx=%.1f expected=%.1f" % [diag.x, flat_speed * sqrt(0.5)])
	check("up-diagonal air dash still pays the upward tax",
		absf(diag.y) < absf(diag.x) * 0.5, "v=(%.1f, %.1f)" % [diag.x, diag.y])
	while not _player.is_on_floor():
		await get_tree().physics_frame
	await step(10)

	# Air dash: locks out the second consecutive airborne dash (DESIGN 4.3).
	# Direction is pinned right into open floor — an air dash follows the
	# movement input, and an unpinned one lands on the spawn ledge, clearing the
	# lock we are trying to test.
	await reset_at(Vector2(300, 300))
	press(&"move_right")
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
	release(&"move_right")
	while not _player.is_on_floor():
		await get_tree().physics_frame
	check("landing clears the air-dash lock", not _player.air_dash_locked)
	await step(10)

func _check_wall() -> void:
	# Pillar B spans y=112..336 with its left face at x=880. Start airborne and
	# adjacent — grounded contact with a wall is Run, not WallSlide.
	await _reach_wall(0, &"")
	check("reaches wall slide", state() == "WallSlide", "state=%s pos=%.1f" % [state(), _player.global_position.x])
	# _reach_wall returns on the frame the slide is detected, before WallSlide has
	# had a tick to clamp the fall — the clamp is what is being asserted.
	await step(1)
	# Input is neutral by now, so the applicable cap is the neutral slide speed,
	# well under terminal velocity.
	check("wall slide is slower than free fall",
		_player.velocity.y <= _player.movement.wall_slide_speed_neutral + 20.0
		and _player.velocity.y < _player.movement.fall_speed_max * 0.5,
		"vy=%.1f neutral cap=%.1f" % [_player.velocity.y, _player.movement.wall_slide_speed_neutral])

	# Neutral movement input: the plain untilted impulse, and the baseline the
	# steered jumps below are compared against.
	var first_up: float = await _wall_jump_vy(0, &"")
	check("wall jump leaves the wall", _player.wall_jump_chain == 1 and _player.velocity.x < 0.0,
		"chain=%d vx=%.1f" % [_player.wall_jump_chain, _player.velocity.x])
	check("neutral wall jump is the untilted impulse",
		near(first_up, _player.movement.walljump_impulse.y, 12.0),
		"vy=%.1f expected=%.1f" % [first_up, _player.movement.walljump_impulse.y])

	# chain=1: consecutive jumps go across, not up (DESIGN 4.4).
	var second_up: float = await _wall_jump_vy(1, &"")
	check("consecutive wall jump loses upward impulse", second_up > first_up * 0.5,
		"first vy=%.1f second vy=%.1f" % [first_up, second_up])
	check("consecutive wall jump keeps horizontal push", absf(_player.velocity.x) > 200.0,
		"vx=%.1f" % _player.velocity.x)

	# Holding up steepens the same jump, holding away from the wall flattens it:
	# the tilt follows the movement stick, not the aim (DESIGN 4.4).
	var steered_up: float = await _wall_jump_vy(0, &"move_up")
	check("wall jump tilts toward the movement input", steered_up < first_up - 40.0,
		"neutral vy=%.1f up-held vy=%.1f" % [first_up, steered_up])
	var steered_away: float = await _wall_jump_vy(0, &"move_left")
	check("holding away from the wall flattens the jump", steered_away > first_up + 40.0,
		"neutral vy=%.1f away-held vy=%.1f" % [first_up, steered_away])

	await _check_chain_is_per_wall(first_up)

## The chain belongs to one wall face (DESIGN 4.4). Crossing the shaft between
## the two pillars pays full impulse again; hopping the same face decays. Both
## halves are flown for real — the pillars are 96px apart, which one wall jump
## clears comfortably.
func _check_chain_is_per_wall(full_up: float) -> void:
	var reached: bool = await _reach_wall(0, &"")
	check("shaft setup reaches the first wall", reached, "state=%s" % state())
	if not reached:
		return
	var first_wall := _player.wall_collider_id
	press(&"jump")
	await step(3)
	release(&"jump")

	var crossed := false
	for i in 60:
		await get_tree().physics_frame
		if state() == "WallSlide" and _player.wall_collider_id != first_wall:
			crossed = true
			break
	check("a wall jump crosses to the opposite wall", crossed,
		"state=%s x=%.1f" % [state(), _player.global_position.x])
	if not crossed:
		return

	# The chain count is already 1 from the first jump and restarts at 1, so it
	# cannot signal that the second jump fired. Ownership of the chain moving to
	# the new wall can.
	var second_wall := _player.wall_collider_id
	press(&"jump")
	var vy := 0.0
	var jumped := false
	for i in 10:
		await get_tree().physics_frame
		if _player.chain_wall_collider == second_wall:
			vy = _player.velocity.y
			jumped = true
			break
	release(&"jump")
	check("the jump off the opposite wall fires", jumped, "state=%s" % state())
	check("a different wall restarts the chain at full impulse", near(vy, full_up, 20.0),
		"vy=%.1f first-wall vy=%.1f" % [vy, full_up])
	check("the restarted chain counts from one", _player.wall_jump_chain == 1,
		"chain=%d" % _player.wall_jump_chain)

## Fall onto pillar B's left face, holding until the slide actually registers.
## steer_action is pressed before the jump and left held; pass &"" for neutral.
##
## The chain is forced by also claiming the wall face it belongs to — the chain
## is per-face now, so a count without an owner would just be discarded.
func _reach_wall(chain: int, steer_action: StringName) -> bool:
	await reset_at(Vector2(861, 180), 2)
	press(&"move_right")
	for i in 30:
		await get_tree().physics_frame
		if state() == "WallSlide":
			release(&"move_right")
			_player.wall_jump_chain = chain
			_player.chain_wall_collider = _player.wall_collider_id
			_player.chain_wall_side = signi(int(signf(_player.wall_normal.x)))
			if steer_action != &"":
				press(steer_action)
			return true
	release(&"move_right")
	return false

## Wall-jump off pillar B at a forced chain count and steering input, returning
## velocity.y on the exact frame the jump fires (before gravity touches it).
func _wall_jump_vy(chain: int, steer_action: StringName) -> float:
	var reached: bool = await _reach_wall(chain, steer_action)
	if not reached:
		check("wall-jump setup reached the wall (chain=%d)" % chain, false, "state=%s" % state())
		return 0.0
	press(&"jump")
	var vy := 0.0
	for i in 10:
		await get_tree().physics_frame
		if _player.wall_jump_chain > chain:
			vy = _player.velocity.y
			break
	release(&"jump")
	if steer_action != &"":
		release(steer_action)
	return vy

## Down while standing still: a crouch, half the body height (DESIGN 4.6).
func _check_crouch() -> void:
	await reset_at(Vector2(200, 300))
	var stand_height := _body_height()
	press(&"move_down")
	await step(3)  # the shape swap is deferred by a frame
	check("down on the ground crouches", state() == "Crouch", "state=%s" % state())
	check("crouching halves the body", near(_body_height(), stand_height * 0.5, 1.0),
		"standing=%.0f crouched=%.0f" % [stand_height, _body_height()])
	check("the crouched head hurtbox drops with the body",
		_player.head_shape_crouch.disabled == false and _player.head_shape.disabled,
		"stand_disabled=%s crouch_disabled=%s"
		% [_player.head_shape.disabled, _player.head_shape_crouch.disabled])
	# Still holding down: Crouch decays out of Slide, so a dash allowed here is a
	# slide-dash by another name.
	var crouch_charges := _player.dash_charges_left
	press(&"dash")
	await step(3)
	release(&"dash")
	check("dash is refused while crouching",
		_player.dash_charges_left == crouch_charges and state() == "Crouch",
		"state=%s charges=%d" % [state(), _player.dash_charges_left])

	release(&"move_down")
	await step(3)
	check("releasing down stands you back up", state() == "Idle" and not _player.crouched,
		"state=%s crouched=%s" % [state(), _player.crouched])
	check("standing restores the full body", near(_body_height(), stand_height, 1.0),
		"height=%.0f" % _body_height())

## Down out of a run: a slide that bleeds speed, refuses dashes, and can be
## cashed in for a long flat jump (DESIGN 4.6).
func _check_slide() -> void:
	# Short run-up, short slide. A slide that holds its speed for a full second
	# crosses ~450px, and the playground only has ~750px of clear floor before
	# the pillars at x=768 — a long run-up here ends in a wall, not a measurement.
	await reset_at(Vector2(80, 300))
	press(&"move_right")
	await step(20)
	var entry_speed := absf(_player.velocity.x)
	var entry_charge := _player.momentum_charge
	press(&"move_down")
	await step(2)
	check("down out of a run slides", state() == "Slide", "state=%s vx=%.1f" % [state(), entry_speed])
	check("sliding lowers the body", _player.crouched)

	var charges_before := _player.dash_charges_left
	press(&"dash")
	await step(3)
	release(&"dash")
	check("dash is refused while sliding",
		state() == "Slide" and _player.dash_charges_left == charges_before,
		"state=%s charges=%d" % [state(), _player.dash_charges_left])

	# The opening of the slide is free: speed carried in is speed kept. Sampled
	# inside slide_hold_time (0.3s), not after it.
	await step(12)
	check("the slide holds its speed at first",
		absf(_player.velocity.x) >= entry_speed - 6.0 and state() == "Slide",
		"%.1f -> %.1f after 0.2s (state=%s)" % [entry_speed, absf(_player.velocity.x), state()])
	check("momentum is held through the opening too",
		_player.momentum_charge >= entry_charge - 0.02,
		"%.2f -> %.2f" % [entry_charge, _player.momentum_charge])

	# ...and only then does it start to cost.
	var held_speed := absf(_player.velocity.x)
	await step(40)
	check("sliding bleeds speed after the hold", absf(_player.velocity.x) < held_speed - 40.0,
		"%.1f -> %.1f" % [held_speed, absf(_player.velocity.x)])
	check("sliding bleeds momentum after the hold", _player.momentum_charge < entry_charge,
		"%.2f -> %.2f" % [entry_charge, _player.momentum_charge])

	# The slide jump: little height, a lot of launch.
	var pre_jump_speed := absf(_player.velocity.x)
	press(&"jump")
	await step(2)
	release(&"jump")
	check("slide jump launches horizontally",
		absf(_player.velocity.x) > pre_jump_speed * 1.2,
		"%.1f -> %.1f" % [pre_jump_speed, absf(_player.velocity.x)])
	check("slide jump stands you back up", not _player.crouched)
	release(&"move_down")
	var apex: float = await measure_apex(90)
	check("slide jump stays low", apex < 20.0, "apex=%.1fpx" % apex)
	release(&"move_right")
	await step(20)

## Every state names an animation and every hero has to have it. A missing name
## is silent at runtime — the sprite just keeps showing the previous pose — so it
## is worth an explicit check.
func _check_animation_contract() -> void:
	var frames: SpriteFrames = _player.sprite.sprite_frames
	check("the player has sprite frames", frames != null)
	if frames == null:
		return
	var missing: Array[String] = []
	for state in _player.state_machine.get_children():
		if state is PlayerState:
			var anim: StringName = (state as PlayerState).animation()
			if not frames.has_animation(anim):
				missing.append("%s->%s" % [state.name, anim])
	check("every state's animation exists in the sheet", missing.is_empty(),
		"missing=%s" % [missing])

	# Sheets are drawn facing +x and the sprite mirrors for -x. Getting this
	# backwards makes every hero run backwards, which is easy to introduce and
	# invisible to every other check here.
	await reset_at(Vector2(200, 300))
	press(&"move_right")
	await step(4)
	check("moving right faces right (sheet orientation, unflipped)",
		_player.facing == 1 and not _player.sprite.flip_h,
		"facing=%d flip_h=%s" % [_player.facing, _player.sprite.flip_h])
	release(&"move_right")
	press(&"move_left")
	await step(4)
	check("moving left flips the sprite",
		_player.facing == -1 and _player.sprite.flip_h,
		"facing=%d flip_h=%s" % [_player.facing, _player.sprite.flip_h])
	release(&"move_left")

	await reset_at(Vector2(200, 300))
	await step(4)
	check("idle plays the idle animation", _player.sprite.animation == &"idle",
		"anim=%s" % _player.sprite.animation)
	press(&"move_right")
	await step(12)
	check("running plays the run animation", _player.sprite.animation == &"run",
		"anim=%s" % _player.sprite.animation)
	press(&"move_down")
	await step(3)
	check("sliding plays the slide animation", _player.sprite.animation == &"slide",
		"anim=%s state=%s" % [_player.sprite.animation, state()])
	release(&"move_down")
	release(&"move_right")
	await step(10)
	press(&"jump")
	await step(4)
	release(&"jump")
	check("rising plays the rise animation", _player.sprite.animation == &"rise",
		"anim=%s vy=%.1f" % [_player.sprite.animation, _player.velocity.y])
	while _player.velocity.y < 0.0:
		await get_tree().physics_frame
	await step(2)
	check("falling plays the fall animation", _player.sprite.animation == &"fall",
		"anim=%s vy=%.1f" % [_player.sprite.animation, _player.velocity.y])
	while not _player.is_on_floor():
		await get_tree().physics_frame
	await step(20)

## Height of whichever body shape is currently enabled.
func _body_height() -> float:
	var shape: CollisionShape2D = _player.body_shape_crouch if _player.crouched else _player.body_shape
	return (shape.shape as RectangleShape2D).size.y

## The overhang (x=400..496, y=192..208) sits just above the apex of a full jump
## and just inside the reach of an up-dash taken at that apex. Confirm a jump
## alone misses it, a dash touches it, and that it reads as a ceiling rather
## than a wall (DESIGN 4.3, 4.4).
func _check_overhang() -> void:
	await reset_at(Vector2(440, 300))
	press(&"jump")
	await step(30)  # full hold, all the way to the apex
	release(&"jump")
	check("a jump alone does not reach the overhang", not _player.is_on_ceiling(),
		"y=%.1f" % _player.global_position.y)

	await reset_at(Vector2(440, 300))
	press(&"jump")
	# Dash at the apex: the dash replaces velocity outright, so spending it while
	# still rising fast throws away the climb it was meant to extend.
	await step(22)
	release(&"jump")
	press(&"move_up")
	press(&"dash")
	await step(3)
	release(&"dash")
	release(&"move_up")
	var hit_ceiling := false
	for i in 20:
		await get_tree().physics_frame
		if _player.is_on_ceiling():
			hit_ceiling = true
			break
	check("an up-dash at the apex reaches the overhang", hit_ceiling,
		"y=%.1f" % _player.global_position.y)
	check("ceiling never becomes a wall", state() != "WallSlide", "state=%s" % state())
	check("ceiling touch clears the air-dash lock", not _player.air_dash_locked)
	await step(20)
