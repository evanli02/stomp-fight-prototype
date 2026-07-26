extends Node
## Combat mechanics harness (M2). Drives two real players through the duel stage
## and asserts the DESIGN 3 rules: what does and does not register as a stomp,
## what a stomp costs, that grace stops chains, that nothing except a stomp can
## take a life, and how a wall-jump duel resolves.
##
## Not a GUT test, for the same reason the movement harness isn't: it needs a
## live scene tree, physics ticks, and real collision between two bodies.
##   Godot --headless --path . res://tests/combat_harness.tscn
## Exits non-zero if any check fails.
##
## Positions are set directly rather than played into: these checks are about
## what the combat rules do once bodies are in contact, and hand-flown approaches
## make that setup flaky without testing anything extra.

## Street level in duel.tscn: the floor's top edge is y=624, so a standing body's
## centre sits 17px above it (bodies are 34 tall). The open street is what these checks need — the
## rooftops above have their own geometry in the way.
const FLOOR_Y: float = 607.0
## A clear column of street: no awning (x 176..272), no mid platform (384..480),
## nothing overhead to land on instead of the other player.
const TEST_X: float = 320.0

var _failures: int = 0
var _stage: Node2D
var _p1: Player
var _p2: Player

func _ready() -> void:
	_stage = load("res://src/stage/duel.tscn").instantiate() as Node2D
	add_child(_stage)
	await get_tree().physics_frame
	_p1 = _stage.get_node("%Player1") as Player
	_p2 = _stage.get_node("%Player2") as Player
	await _run()
	print("\n%s" % ("ALL CHECKS PASSED" if _failures == 0 else "%d CHECK(S) FAILED" % _failures))
	get_tree().quit(1 if _failures > 0 else 0)

#region harness
func step(frames: int) -> void:
	for i in frames:
		await get_tree().physics_frame

## Bounded wait — a harness that hangs on a broken build tells you nothing, so
## every wait here has a frame budget and reports timing out as a failure.
func wait_until(cond: Callable, max_frames: int = 300) -> bool:
	for i in max_frames:
		if cond.call():
			return true
		await get_tree().physics_frame
	return false

func check(label: String, ok: bool, detail: String = "") -> void:
	if not ok:
		_failures += 1
	print("%s %s %s" % ["PASS" if ok else "FAIL", label, detail])

## Lives on whichever hero is currently out for that seat.
func lives_of(player_id: int) -> int:
	return MatchState.lives_of(player_id, MatchState.active_hero(player_id))

## Park a player somewhere with every combat timer cleared, so each check starts
## from the same state regardless of what the previous one did to them.
##
## Teleporting a body is not instant as far as the physics server is concerned:
## if whatever it was resting on has moved or vanished, the next move_and_slide()
## can depenetrate it a long way — velocity untouched, position thrown across the
## arena. Settling for a frame and re-asserting makes the placement stick.
func place(p: Player, pos: Vector2) -> void:
	_park(p, pos)
	await get_tree().physics_frame
	_park(p, pos)

func _park(p: Player, pos: Vector2) -> void:
	p.global_position = pos
	p.velocity = Vector2.ZERO
	p.stun_remaining = 0.0
	p.grace_remaining = 0.0
	p.spawn_protected = false
	p.fall_speed_memory = 0.0
	p.set_head_hurtbox_enabled(true)
	p.state_machine.change_state(&"Air")

func release_all() -> void:
	for p in [_p1, _p2]:
		for a in InputConfig.ACTIONS:
			Input.action_release(InputConfig.action(p.player_id, a))
#endregion

func _run() -> void:
	await _check_registration()
	await _check_standing_on_head_is_not_a_stomp()
	await _check_only_stomps_cost_lives()
	await _check_stomp()
	await _check_grace_blocks_the_chain()
	await _check_last_life_swaps_in_the_next_hero()
	await _check_wall_duel_stun()
	await _check_wall_duel_simultaneous()
	await _check_slam_is_a_stomp()

func _check_registration() -> void:
	check("both players are registered", MatchState.has_player(0) and MatchState.has_player(1))
	check("each seat gets a full trio",
		MatchState.roster(0).size() == MatchState.HEROES_PER_PLAYER
		and MatchState.roster(1).size() == MatchState.HEROES_PER_PLAYER,
		"p1=%s p2=%s" % [MatchState.roster(0), MatchState.roster(1)])
	check("each hero starts on 2 lives", lives_of(0) == 2 and lives_of(1) == 2,
		"p1=%d p2=%d" % [lives_of(0), lives_of(1)])
	check("seats hold different devices",
		InputConfig.device_of(0) == InputConfig.Device.KBM \
		and InputConfig.device_of(1) == InputConfig.Device.PAD)

## DESIGN 3.4: you can stand on shoulders. Only falling onto the head box counts.
func _check_standing_on_head_is_not_a_stomp() -> void:
	await place(_p2, Vector2(TEST_X, FLOOR_Y))
	await place(_p1, Vector2(TEST_X, FLOOR_Y - 34))  # feet resting on P2's head
	await step(30)                          # longer than stomp_fall_memory_time
	check("standing on a head costs no life", lives_of(1) == 2, "lives=%d" % lives_of(1))
	check("standing on a head applies no stun", is_zero_approx(_p2.stun_remaining))

## CLAUDE.md rule 1: no ability, hazard, or impulse may ever remove a life.
func _check_only_stomps_cost_lives() -> void:
	_p2.apply_stun(0.5)
	_p2.apply_impulse(Vector2(600, -600))
	await step(20)
	check("stun and knockback cost no life", lives_of(1) == 2, "lives=%d" % lives_of(1))

func _check_stomp() -> void:
	await place(_p2, Vector2(TEST_X, FLOOR_Y))
	await place(_p1, Vector2(TEST_X, FLOOR_Y - 110))  # ~60px of fall onto the head
	var stomps: Array[Player] = []
	_p1.stomp_landed.connect(func(victim: Player) -> void: stomps.append(victim))
	await step(30)
	check("falling onto a head registers a stomp", stomps.size() == 1, "stomps=%d" % stomps.size())
	check("the stomp takes exactly one life", lives_of(1) == 1, "lives=%d" % lives_of(1))
	check("the victim is stunned", _p2.stun_remaining > 0.0
		and _p2.stun_remaining <= _p2.combat.stomp_stun_time,
		"stun=%.2f" % _p2.stun_remaining)
	check("the victim gets grace", _p2.grace_remaining > 0.0, "grace=%.2f" % _p2.grace_remaining)
	check("the victim's head hurtbox is off during grace", not _p2.head_hurtbox.monitorable)
	check("the attacker never loses a life", lives_of(0) == 2, "lives=%d" % lives_of(0))

func _check_grace_blocks_the_chain() -> void:
	# Same fall again while grace is still running: the chain has to be refused.
	await place(_p1, Vector2(TEST_X, FLOOR_Y - 110))
	_p2.global_position = Vector2(TEST_X, FLOOR_Y)
	_p2.velocity = Vector2.ZERO
	check("grace is still running for the second drop", _p2.grace_remaining > 0.0,
		"grace=%.2f" % _p2.grace_remaining)
	await step(30)
	check("grace refuses the chained stomp", lives_of(1) == 1, "lives=%d" % lives_of(1))

## The second stomp on a hero pops it and the player's NEXT hero comes in at
## their spawn (DESIGN 3.3). The round only ends when the whole trio is gone,
## which the match harness covers.
func _check_last_life_swaps_in_the_next_hero() -> void:
	var eliminated: Array[StringName] = []
	MatchState.hero_eliminated.connect(func(_pid: int, hid: StringName) -> void: eliminated.append(hid))
	var grace_ended: bool = await wait_until(func() -> bool: return _p2.grace_remaining <= 0.0)
	check("grace expires on its own", grace_ended, "grace=%.2f" % _p2.grace_remaining)
	var doomed := MatchState.active_hero(1)
	await place(_p2, Vector2(TEST_X, FLOOR_Y))
	await place(_p1, Vector2(TEST_X, FLOOR_Y - 110))
	await step(30)
	check("the second stomp empties the hero",
		MatchState.lives_of(1, doomed) == 0, "lives=%d" % MatchState.lives_of(1, doomed))
	check("hero_eliminated fires", eliminated.has(doomed), "fired=%s" % [eliminated])

	var swapped: bool = await wait_until(func() -> bool: return MatchState.active_hero(1) != doomed)
	check("the next hero is auto-swapped in", swapped,
		"active=%s" % MatchState.active_hero(1))
	check("the incoming hero arrives on full lives", lives_of(1) == 2, "lives=%d" % lives_of(1))
	check("the incoming hero gets spawn protection", _p2.spawn_protected or _p2.grace_remaining > 0.0,
		"protected=%s grace=%.2f" % [_p2.spawn_protected, _p2.grace_remaining])
	check("the eliminated player is not out yet", not MatchState.is_out(1),
		"living=%s" % [MatchState.living_heroes(1)])

## Integration path: P1 clings to P2's flank and kicks off it (DESIGN 3.4).
func _check_wall_duel_stun() -> void:
	# Bodies are 22px wide, so adjacent is 23px of centre separation.
	await place(_p2, Vector2(TEST_X, FLOOR_Y))
	await place(_p1, Vector2(TEST_X - 23, FLOOR_Y - 20))
	Input.action_press(InputConfig.action(0, &"move_right"))  # hold into P2
	var clung := false
	for i in 40:
		await get_tree().physics_frame
		if _p1.wall_player == _p2:
			clung = true
			break
	check("another player reads as a wall", clung, "wall_player=%s state=%s"
		% [_p1.wall_player, _p1.state_machine.state_name()])
	check("clinging to a player is not a stomp", lives_of(1) == 2, "lives=%d" % lives_of(1))

	Input.action_press(InputConfig.action(0, &"jump"))
	var jumped := false
	for i in 20:
		await get_tree().physics_frame
		if _p1.wall_jump_chain > 0:
			jumped = true
			break
	release_all()
	check("wall jump off a player fires", jumped, "chain=%d" % _p1.wall_jump_chain)
	# The stun is deliberately deferred to the end of the duel window.
	await step(_p1.movement.duel_window_frames + 2)
	check("the loser of the duel is stunned", _p2.stun_remaining > 0.0,
		"stun=%.2f" % _p2.stun_remaining)
	check("the duel stun matches the table",
		_p2.stun_remaining <= _p1.combat.stun_duel_loss + 0.02,
		"stun=%.2f expected<=%.2f" % [_p2.stun_remaining, _p1.combat.stun_duel_loss])
	check("the winner is not stunned", is_zero_approx(_p1.stun_remaining),
		"stun=%.2f" % _p1.stun_remaining)
	check("a duel costs no life", lives_of(0) == 2 and lives_of(1) == 2,
		"p1=%d p2=%d" % [lives_of(0), lives_of(1)])

## Terra's slam kill goes through the ORDINARY stomp system — the plummet is
## just a very fast fall, so head contact resolves via receive_stomp with every
## stomp rule intact. The shockwave, like all ability effects, never takes a
## life (CLAUDE.md 1).
func _check_slam_is_a_stomp() -> void:
	MatchState.reset_round()
	MatchState.swap_to(0, &"terra")
	_p1.equip_hero(&"terra")
	# Earlier checks auto-swapped p2 through several heroes; the body's idea of
	# its active hero has to match MatchState or the life comes off the wrong row.
	_p2.equip_hero(MatchState.active_hero(1))
	await place(_p2, Vector2(TEST_X, FLOOR_Y))
	await place(_p1, Vector2(TEST_X, FLOOR_Y - 150))
	var victim_hero := MatchState.active_hero(1)
	var lives_before := MatchState.lives_of(1, victim_hero)
	var stomps: Array = []
	var cb := func(v: Player) -> void: stomps.append(v)
	_p1.stomp_landed.connect(cb)
	check("slam fires in the air", _p1.try_ability())
	var landed: bool = await wait_until(func() -> bool: return not stomps.is_empty(), 120)
	_p1.stomp_landed.disconnect(cb)
	check("the slam head hit registers as a stomp", landed, "stomps=%d" % stomps.size())
	check("the slam costs exactly one life, via the stomp system",
		MatchState.lives_of(1, victim_hero) == lives_before - 1,
		"lives=%d" % MatchState.lives_of(1, victim_hero))
	check("the slam victim gets normal stomp grace", _p2.grace_remaining > 0.0)

	# Shockwave only: slam lands BESIDE the victim — stun and shove, never a life.
	var grace_over: bool = await wait_until(func() -> bool: return _p2.grace_remaining <= 0.0, 200)
	check("grace clears before the shockwave case", grace_over)
	MatchState.start_cooldown(0, &"terra", 0.0)
	await place(_p2, Vector2(TEST_X, FLOOR_Y))
	# +45, not further: the stepping platform starts at x=384 and a slam that
	# lands on it is 120px from the victim — outside the shockwave.
	await place(_p1, Vector2(TEST_X + 45, FLOOR_Y - 150))
	var lives_mid := MatchState.lives_of(1, MatchState.active_hero(1))
	check("slam fires again beside the victim", _p1.try_ability())
	var shocked: bool = await wait_until(func() -> bool: return _p2.stun_remaining > 0.0, 120)
	check("the shockwave stuns", shocked, "stun=%.2f" % _p2.stun_remaining)
	check("the shockwave costs no life",
		MatchState.lives_of(1, MatchState.active_hero(1)) == lives_mid)

## Arbitration path: both inputs land inside duel_window_frames, so both get the
## juice and neither is stunned — allies included (DESIGN 3.4).
func _check_wall_duel_simultaneous() -> void:
	await place(_p1, Vector2(TEST_X - 23, FLOOR_Y - 20))
	await place(_p2, Vector2(TEST_X, FLOOR_Y - 20))
	await step(2)
	var juice := _p1.movement.duel_juice_mult
	var first_impulse := Vector2(-360.0, -420.0)
	var p1_before := _p1.velocity
	var first_mult := _p1.claim_wall_duel(_p2, first_impulse)
	var second_mult := _p2.claim_wall_duel(_p1, Vector2(360.0, -420.0))
	check("the first jumper takes the plain impulse", is_equal_approx(first_mult, 1.0),
		"mult=%.2f" % first_mult)
	check("the answering jumper is juiced", is_equal_approx(second_mult, juice),
		"mult=%.2f expected=%.2f" % [second_mult, juice])
	check("the first jumper is juiced retroactively",
		_p1.velocity.is_equal_approx(p1_before + first_impulse * (juice - 1.0)),
		"v %s -> %s" % [p1_before, _p1.velocity])
	await step(_p1.movement.duel_window_frames + 2)
	check("a tied duel stuns nobody",
		is_zero_approx(_p1.stun_remaining) and is_zero_approx(_p2.stun_remaining),
		"p1=%.2f p2=%.2f" % [_p1.stun_remaining, _p2.stun_remaining])
