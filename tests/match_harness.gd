extends Node
## Match structure harness (M3). Covers the rules that decide who is on the
## field and what they are allowed to do: rosters, hero swap, per-hero cooldowns
## that tick while benched, the one-ultimate-per-round economy, round wins, and
## the reset between rounds.
##
## Most of this is pure logic on the autoloads and needs no bodies. The parts
## that do — swapping actually re-equipping the player, stun blocking swap and
## ult — run against the real duel scene.
##   Godot --headless --path . res://tests/match_harness.tscn
## Exits non-zero if any check fails.

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

func check(label: String, ok: bool, detail: String = "") -> void:
	if not ok:
		_failures += 1
	print("%s %s %s" % ["PASS" if ok else "FAIL", label, detail])

## Take every life off a hero without needing a body to stomp it.
func kill_hero(pid: int, hero: StringName) -> void:
	for i in MatchState.LIVES_PER_HERO:
		MatchState.lose_life(pid, hero)
#endregion

func _run() -> void:
	await _check_hero_select()
	await _check_rosters()
	await _check_swap()
	await _check_swap_equips_the_body()
	await _check_stun_blocks_swap_and_ult()
	await _check_cooldowns_tick_while_benched()
	await _check_ultimate_economy()
	await _check_abilities()
	await _check_round_win_and_reset()
	await _check_stage_registry()
	await _check_stage_select_flow()

## Hero select's rules, driven directly rather than through synthetic button
## presses — the screen is a thin shell over these and the rules are the part
## that can silently go wrong (DESIGN 2.2).
func _check_hero_select() -> void:
	var screen: CanvasLayer = load("res://src/ui/hero_select.tscn").instantiate()
	add_child(screen)
	await get_tree().physics_frame
	var roster: Array = GameManager.roster_ids()

	screen._pick(0, roster[0])
	screen._pick(0, roster[0])
	check("a hero cannot be picked twice by the same player",
		screen._picks[0].size() == 1, "picks=%s" % [screen._picks[0]])

	screen._pick(1, roster[0])
	check("two players may both take the same hero",
		screen._picks[1].size() == 1 and screen._picks[1][0] == roster[0],
		"p2 picks=%s" % [screen._picks[1]])

	screen._undo(0)
	check("undo removes the last pick", screen._picks[0].is_empty(),
		"picks=%s" % [screen._picks[0]])

	for i in roster.size():
		screen._pick(0, roster[i])
	check("a player cannot pick more than three",
		screen._picks[0].size() == MatchState.HEROES_PER_PLAYER,
		"picks=%s" % [screen._picks[0]])
	check("the screen is not ready until every seat has three",
		not screen._all_seats_ready())

	# A seat with no controller attached never picks; the timer covers it.
	var confirmed: Array = []
	screen.picks_confirmed.connect(func(r: Dictionary, t: Dictionary) -> void:
		confirmed.append({"rosters": r, "teams": t}))
	screen._remaining = 0.0
	var fired: bool = false
	for i in 30:
		await get_tree().physics_frame
		if not confirmed.is_empty():
			fired = true
			break
	check("the timer auto-fills an idle seat and confirms", fired,
		"picks=%s" % [screen._picks[1]])
	if fired:
		var rosters: Dictionary = confirmed[0]["rosters"]
		check("every confirmed seat has exactly three heroes",
			rosters[0].size() == 3 and rosters[1].size() == 3,
			"p1=%s p2=%s" % [rosters[0], rosters[1]])
		check("auto-filled picks have no duplicates",
			rosters[1].size() == _unique(rosters[1]).size(), "p2=%s" % [rosters[1]])
	screen.queue_free()
	await get_tree().physics_frame

func _unique(a: Array) -> Array:
	var seen := []
	for v in a:
		if not seen.has(v):
			seen.append(v)
	return seen

func _check_rosters() -> void:
	check("the match starts in ROUND_ACTIVE",
		GameManager.phase == GameManager.Phase.ROUND_ACTIVE,
		"phase=%d" % GameManager.phase)
	check("each seat has three heroes",
		MatchState.roster(0).size() == 3 and MatchState.roster(1).size() == 3,
		"p1=%s p2=%s" % [MatchState.roster(0), MatchState.roster(1)])
	check("every hero starts on two lives",
		MatchState.lives_of(0, MatchState.roster(0)[2]) == MatchState.LIVES_PER_HERO)
	check("the first hero in the roster starts active",
		MatchState.active_hero(0) == MatchState.roster(0)[0],
		"active=%s" % MatchState.active_hero(0))

func _check_swap() -> void:
	var roster: Array = MatchState.roster(0)
	check("swapping to the active hero is refused",
		not MatchState.can_swap_to(0, MatchState.active_hero(0)))
	check("swapping to a living bench hero is allowed",
		MatchState.can_swap_to(0, roster[1]))
	check("swap succeeds", MatchState.swap_to(0, roster[1]))
	check("the active hero changed", MatchState.active_hero(0) == roster[1],
		"active=%s" % MatchState.active_hero(0))

	# A dead hero can never be swapped to (DESIGN 2.2).
	kill_hero(0, roster[2])
	check("swapping to an eliminated hero is refused", not MatchState.can_swap_to(0, roster[2]))
	check("cycling skips the eliminated hero",
		MatchState.next_living_hero(0) == roster[0],
		"next=%s" % MatchState.next_living_hero(0))
	MatchState.reset_round()
	await step(1)

func _check_swap_equips_the_body() -> void:
	MatchState.reset_round()
	_p1.equip_hero(MatchState.active_hero(0))
	await step(2)
	var before := _p1.active_hero
	var frames_before := _p1.sprite.sprite_frames
	var pos_before := _p1.global_position
	_p1.velocity = Vector2(180, -90)
	var vel_before := _p1.velocity

	check("the body swaps hero", _p1.try_swap(), "active=%s" % _p1.active_hero)
	check("the equipped hero changed", _p1.active_hero != before,
		"%s -> %s" % [before, _p1.active_hero])
	check("the sprite frames changed with it", _p1.sprite.sprite_frames != frames_before)
	# DESIGN 2.4: the incoming hero inherits the outgoing hero's situation.
	check("swapping does not move the body", _p1.global_position.is_equal_approx(pos_before),
		"%s -> %s" % [pos_before, _p1.global_position])
	check("swapping keeps velocity", _p1.velocity.is_equal_approx(vel_before),
		"%s -> %s" % [vel_before, _p1.velocity])

func _check_stun_blocks_swap_and_ult() -> void:
	var active_before := _p1.active_hero
	_p1.apply_stun(0.5)
	await step(1)
	check("swap is blocked while stunned", not _p1.try_swap())
	check("the stunned player keeps their hero", _p1.active_hero == active_before,
		"active=%s" % _p1.active_hero)
	check("ultimate is blocked while stunned", not _p1.try_ultimate())
	check("a blocked ultimate is not spent", MatchState.ult_available(0))
	_p1.stun_remaining = 0.0
	await step(1)

func _check_cooldowns_tick_while_benched() -> void:
	MatchState.reset_round()
	var roster: Array = MatchState.roster(0)
	var benched: StringName = roster[1]
	MatchState.swap_to(0, roster[0])
	MatchState.start_cooldown(0, benched, 2.0)
	check("starting a cooldown registers it",
		is_equal_approx(MatchState.cooldown_remaining(0, benched), 2.0),
		"remaining=%.2f" % MatchState.cooldown_remaining(0, benched))
	check("a hero on cooldown is not ready", not MatchState.is_ability_ready(0, benched))

	# Benched cooldowns keep running — swapping out must never reset an ability
	# (CLAUDE.md checklist). GameManager ticks them during ROUND_ACTIVE.
	await step(30)
	var after := MatchState.cooldown_remaining(0, benched)
	check("a benched hero's cooldown still ticks", after < 1.75 and after > 1.0,
		"remaining=%.2f after 0.5s" % after)
	check("the benched hero is still benched", MatchState.active_hero(0) != benched)

	var ready: bool = false
	for i in 200:
		await get_tree().physics_frame
		if MatchState.is_ability_ready(0, benched):
			ready = true
			break
	check("the cooldown reaches zero and stays there", ready
		and MatchState.cooldown_remaining(0, benched) == 0.0,
		"remaining=%.2f" % MatchState.cooldown_remaining(0, benched))

func _check_ultimate_economy() -> void:
	MatchState.reset_round()
	check("the ultimate starts available", MatchState.ult_available(0))
	check("a round starts with ULTS_PER_ROUND banked",
		MatchState.ults_left(0) == MatchState.ULTS_PER_ROUND,
		"left=%d" % MatchState.ults_left(0))
	check("spending the first ultimate succeeds", MatchState.try_spend_ultimate(0))
	check("one ultimate is left", MatchState.ults_left(0) == MatchState.ULTS_PER_ROUND - 1,
		"left=%d" % MatchState.ults_left(0))
	# Banked but not usable: the gap between uses is what stops both going off at
	# once (DESIGN 2.3).
	check("the second is blocked by the cooldown", not MatchState.ult_available(0))
	check("a spend during the cooldown is refused", not MatchState.try_spend_ultimate(0))
	check("the refused spend cost nothing",
		MatchState.ults_left(0) == MatchState.ULTS_PER_ROUND - 1,
		"left=%d" % MatchState.ults_left(0))
	# Per PLAYER, shared across the trio — swapping does not hand you a fresh one.
	MatchState.swap_to(0, MatchState.next_living_hero(0))
	check("swapping heroes does not restore an ultimate",
		MatchState.ults_left(0) == MatchState.ULTS_PER_ROUND - 1)
	check("the other player's ultimates are untouched",
		MatchState.ult_available(1) and MatchState.ults_left(1) == MatchState.ULTS_PER_ROUND)

	var waited: bool = false
	for i in int(MatchState.ULT_COOLDOWN * 60.0) + 30:
		await get_tree().physics_frame
		if MatchState.ult_available(0):
			waited = true
			break
	check("the second ultimate unlocks after the cooldown", waited,
		"cd=%.2f" % MatchState.ult_cooldown_remaining(0))
	check("spending the second ultimate succeeds", MatchState.try_spend_ultimate(0))
	check("both ultimates are now gone", MatchState.ults_left(0) == 0)

	MatchState.reset_round()
	check("the round reset restores both ultimates",
		MatchState.ult_available(0) and MatchState.ults_left(0) == MatchState.ULTS_PER_ROUND)

## M4 abilities. The load-bearing check is the last one: whatever a hero does,
## it cannot cost a life. Only stomps do that (CLAUDE.md rule 1).
func _check_abilities() -> void:
	MatchState.reset_round()
	var lives_before := [
		MatchState.lives_of(0, MatchState.active_hero(0)),
		MatchState.lives_of(1, MatchState.active_hero(1)),
	]
	_p1.global_position = Vector2(300, 300)
	_p2.global_position = Vector2(360, 300)
	_p1.stun_remaining = 0.0
	_p2.stun_remaining = 0.0
	await step(2)

	var fired_any := false
	for hero_id in GameManager.roster_ids():
		MatchState.reset_round()
		# Force the hero onto seat 0 even if it is not in that seat's trio: this
		# is about the abilities, not about roster legality. Fired AIRBORNE,
		# because some abilities (Terra's slam) are air-only by design.
		_p1.global_position = Vector2(400, 260)
		_p1.velocity = Vector2.ZERO
		_p1.stun_remaining = 0.0
		_p1.disrupt_remaining = 0.0
		_p1.state_machine.change_state(&"Air")
		_p1.equip_hero(hero_id)
		await step(2)
		var ability := _p1.equipped_ability()
		check("%s equips an ability component" % hero_id, ability != null)
		if ability == null:
			continue
		check("%s ability is not flagged as an ultimate" % hero_id, not ability.is_ultimate)
		var ok: bool = _p1.try_ability()
		fired_any = fired_any or ok
		check("%s ability fires" % hero_id, ok)
		check("%s ability goes on cooldown" % hero_id,
			not MatchState.is_ability_ready(0, hero_id),
			"remaining=%.2f" % MatchState.cooldown_remaining(0, hero_id))
		if hero_id != &"slip":
			# Slip is deliberately multi-stage: her recall rides through the
			# placement's cooldown, so this refusal does not apply to her.
			check("%s ability is refused while on cooldown" % hero_id, not _p1.try_ability())
		check("%s ultimate fires" % hero_id, _p1.try_ultimate())
		check("%s ultimate goes on its between-use cooldown" % hero_id,
			not MatchState.ult_available(0),
			"cd=%.2f left=%d" % [MatchState.ult_cooldown_remaining(0), MatchState.ults_left(0)])
		if hero_id != &"slip":
			# Slip's second placement is a free recast of the SAME activation.
			check("%s ultimate is refused during that gap" % hero_id, not _p1.try_ultimate())
		await step(4)

	check("abilities actually fired", fired_any)

	# Deadeye's ultimate refunds the bolt and loads a heavier next shot.
	MatchState.reset_round()
	_p1.equip_hero(&"deadeye")
	await step(2)
	_p1.try_ability()
	check("deadeye is on cooldown before the ult",
		not MatchState.is_ability_ready(0, &"deadeye"))
	_p1.try_ultimate()
	await step(1)
	check("deadeye's ultimate refunds the bolt cooldown",
		MatchState.is_ability_ready(0, &"deadeye"),
		"remaining=%.2f" % MatchState.cooldown_remaining(0, &"deadeye"))
	var bolt := _p1.equipped_ability() as DeadeyeBolt
	check("the ultimate loads an empowered shot",
		bolt != null and bolt._empowered_stun > 0.0,
		"stun=%.2f" % (bolt._empowered_stun if bolt != null else -1.0))
	check("the empowered bolt fires", _p1.try_ability())
	check("the empowerment is spent on one shot only",
		bolt != null and bolt._empowered_stun == 0.0)

	# Skyla's ultimate replaces her cooldown for a window rather than removing it.
	MatchState.reset_round()
	_p1.equip_hero(&"fei")
	await step(2)
	_p1.try_ultimate()
	await step(1)
	var jump := _p1.equipped_ability()
	check("fei's ultimate overrides the cooldown",
		jump != null and jump.cooldown_override_remaining > 0.0
		and jump.effective_cooldown() < jump.cooldown,
		"override=%.2f normal=%.2f window=%.2f" % [
			jump.effective_cooldown() if jump else -1.0,
			jump.cooldown if jump else -1.0,
			jump.cooldown_override_remaining if jump else -1.0])
	check("firing inside the window costs the reduced cooldown", _p1.try_ability())
	check("the reduced cooldown is what got written",
		MatchState.cooldown_remaining(0, &"fei") < jump.cooldown * 0.5,
		"remaining=%.2f vs normal %.2f" % [
			MatchState.cooldown_remaining(0, &"fei"), jump.cooldown])

	# Slip's rewind: anchor, travel, blink lands back at the anchor.
	MatchState.reset_round()
	_p1.equip_hero(&"slip")
	await step(2)
	# Both points on the open street: the anchor is the only place the blink has
	# to be able to occupy, so it is the only one that must be clear.
	_p1.global_position = Vector2(320, 600)
	_p1.velocity = Vector2.ZERO
	await step(1)
	var anchor_at := _p1.global_position
	check("slip places an anchor", _p1.try_ability())
	_p1.global_position = Vector2(200, 600)
	await step(10)
	check("slip recalls through her own cooldown", _p1.try_ability())
	var returned: bool = false
	for i in 90:
		await get_tree().physics_frame
		if _p1.global_position.distance_to(anchor_at) < 24.0:
			returned = true
			break
	check("the blink arrives back at the anchor", returned,
		"at=%s anchor=%s" % [_p1.global_position, anchor_at])

	# Debuffs carry a source tag so the badges over a player can differ by cause.
	MatchState.reset_round()
	# Let every effect the sweep launched actually land first. Kid's EMP has a
	# 0.6s telegraph, so clearing state immediately would be undone a moment
	# later by a wave that had not detonated yet.
	await step(60)
	# Then wipe: those effects leave multi-second debuffs, and every apply_*
	# takes the LONGER timer.
	_p2.debuff_tags.clear()
	_p2.disrupt_remaining = 0.0
	_p2.slow_remaining = 0.0
	_p2.slow_mult = 1.0
	_p2.impair_remaining = 0.0
	_p2.impair_mult = 1.0
	_p2.apply_slow(0.5, 1.0, &"slash")
	_p2.apply_disrupt(1.0, &"emp")
	check("a debuff records its source", _p2.debuff_tags.has(&"slash")
		and _p2.debuff_tags.has(&"emp"), "tags=%s" % [_p2.debuff_tags.keys()])
	check("distinct sources get distinct badges",
		DebuffMarks.MARKS[&"slash"][1] != DebuffMarks.MARKS[&"emp"][1])
	await step(75)
	check("debuff tags clear when they expire", _p2.debuff_tags.is_empty(),
		"tags=%s" % [_p2.debuff_tags.keys()])
	check("a cleared disrupt lets the player act again", _p2.disrupt_remaining <= 0.0)

	await step(60)
	check("no ability took a life",
		MatchState.lives_of(0, MatchState.active_hero(0)) == lives_before[0]
		and MatchState.lives_of(1, MatchState.active_hero(1)) == lives_before[1],
		"p1=%d p2=%d" % [MatchState.lives_of(0, MatchState.active_hero(0)),
			MatchState.lives_of(1, MatchState.active_hero(1))])
	MatchState.reset_round()

func _check_round_win_and_reset() -> void:
	MatchState.reset_round()
	var wins_before := MatchState.wins_for(0)
	var winners: Array[int] = []
	MatchState.round_won.connect(func(team: int) -> void: winners.append(team))

	var roster: Array = MatchState.roster(1).duplicate()
	for i in roster.size():
		kill_hero(1, roster[i])
		if i < roster.size() - 1:
			check("the round is still live with %d hero(es) left" % (roster.size() - i - 1),
				winners.is_empty(), "winners=%s" % [winners])
	check("wiping the whole trio ends the round", winners == [0], "winners=%s" % [winners])
	check("the winning team banks a round win", MatchState.wins_for(0) == wins_before + 1,
		"wins=%d" % MatchState.wins_for(0))
	check("the loser is recorded for stage pick", MatchState.last_round_loser_team == 1,
		"loser=%d" % MatchState.last_round_loser_team)
	check("round 1 stage pick goes to the coinflip winner",
		MatchState.stage_picker(0, 1) == 1)
	check("later rounds are picked by the previous loser",
		MatchState.stage_picker(1, 1) == 1)

	# The arena calls end_round; GameManager holds results, then starts the next.
	# Flag lives in an array because GDScript lambdas capture locals by VALUE —
	# assigning a captured bool inside the closure updates only the copy.
	var started: Array[bool] = [false]
	GameManager.round_started.connect(func(_i: int) -> void: started[0] = true)
	for i in 400:
		await get_tree().physics_frame
		if started[0]:
			break
	check("the next round starts after the results banner", started[0],
		"phase=%d" % GameManager.phase)
	check("the reset restores every hero to full lives",
		MatchState.lives_of(1, roster[0]) == MatchState.LIVES_PER_HERO
		and MatchState.lives_of(1, roster[2]) == MatchState.LIVES_PER_HERO,
		"lives=%d,%d" % [MatchState.lives_of(1, roster[0]), MatchState.lives_of(1, roster[2])])
	check("round wins survive the reset", MatchState.wins_for(0) == wins_before + 1,
		"wins=%d" % MatchState.wins_for(0))

## The stage registry is what the select screen reads to draw a card without
## instantiating a stage — an entry missing a field would surface as a blank
## card at the worst possible moment rather than as an error.
func _check_stage_registry() -> void:
	var ids := GameManager.stage_ids()
	check("more than one stage is registered", ids.size() >= 2, "ids=%s" % [ids])
	var complete := true
	var missing := ""
	for id: StringName in ids:
		for key: String in ["scene", "name", "blurb", "features"]:
			# str(), not String() — String(x) is a constructor and rejects a
			# value that is already a String.
			if str(GameManager.stage_info(id, key, "")).is_empty():
				complete = false
				missing += " %s.%s" % [id, key]
		if not (GameManager.stage_info(id, "accent", null) is Color):
			complete = false
			missing += " %s.accent" % id
		if GameManager.stage_scene(id) == null:
			complete = false
			missing += " %s.scene(unloadable)" % id
	check("every registered stage is fully described", complete, missing)
	check("an unregistered id falls back rather than erroring",
		GameManager.stage_info(&"not_a_stage", "name", "?") == "?")
	check("an unregistered id loads no scene",
		GameManager.stage_scene(&"not_a_stage") == null)

## The stage-select round trip, driven through GameManager rather than through
## the screen: the screen is a thin shell over choose_stage, and the part that
## can silently go wrong is the phase order around it.
func _check_stage_select_flow() -> void:
	var phases: Array[int] = []
	var cb := func(phase: int) -> void: phases.append(phase)
	GameManager.phase_changed.connect(cb)

	var rosters := {0: MatchState.roster(0).duplicate(), 1: MatchState.roster(1).duplicate()}
	GameManager.start_match(rosters, {0: 0, 1: 1}, true)
	check("a match with stage select waits in STAGE_SELECT",
		GameManager.phase == GameManager.Phase.STAGE_SELECT, "phase=%d" % GameManager.phase)
	check("no round starts before a stage is chosen",
		not phases.has(GameManager.Phase.ROUND_ACTIVE), "phases=%s" % [phases])

	GameManager.choose_stage(&"cryo_lab")
	check("choosing a stage starts the round",
		GameManager.phase == GameManager.Phase.ROUND_ACTIVE, "phase=%d" % GameManager.phase)
	check("the chosen stage is what the shell will load",
		GameManager.current_stage == &"cryo_lab", "stage=%s" % GameManager.current_stage)

	var held := GameManager.current_stage
	GameManager.choose_stage(&"not_a_stage")
	check("an unknown pick leaves the current stage standing",
		GameManager.current_stage == held, "stage=%s" % GameManager.current_stage)

	# Between rounds the pick happens again — that is the whole point of the
	# rule, since it is the loser who gets to change the ground (DESIGN 2.2).
	for hero: StringName in MatchState.roster(1).duplicate():
		kill_hero(1, hero)
	GameManager.end_round()
	var returned: Array[bool] = [false]
	for i in 400:
		await get_tree().physics_frame
		if GameManager.phase == GameManager.Phase.STAGE_SELECT:
			returned[0] = true
			break
	check("the next round routes back through stage select", returned[0],
		"phase=%d round=%d" % [GameManager.phase, GameManager.round_index])
	check("the loser of that round holds the next pick",
		GameManager.stage_picker_team() == 1, "picker=%d" % GameManager.stage_picker_team())
	GameManager.choose_stage(held)

	# Back to the default so nothing after this runs on a surprise stage, and so
	# a harness re-run starts from the same place.
	GameManager.phase_changed.disconnect(cb)
	GameManager.start_match(rosters, {0: 0, 1: 1})
	check("a match without stage select drops straight into the round",
		GameManager.phase == GameManager.Phase.ROUND_ACTIVE, "phase=%d" % GameManager.phase)
