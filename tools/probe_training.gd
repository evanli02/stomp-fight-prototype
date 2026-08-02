extends Node
## Throwaway headless probe for the training room. Not a harness — just proves
## the room's behaviour end to end before a human touches it:
##   Godot --headless --path . res://tools/probe_training.tscn

var _fails: int = 0

func check(label: String, ok: bool, detail: String = "") -> void:
	if not ok:
		_fails += 1
	print("%s %s %s" % ["PASS" if ok else "FAIL", label, detail])

func _ready() -> void:
	var room: Node2D = load("res://src/stage/training_room.tscn").instantiate()
	add_child(room)
	for i in 30:
		await get_tree().physics_frame

	var players: Array = room.players
	check("four bodies are seated", players.size() == 4, "n=%d" % players.size())
	check("ultimates are free on entry", MatchState.free_ultimates)
	check("cooldowns are real on entry", not MatchState.free_cooldowns)

	# Cycling: press swap 14 times and record every hero seat 0 wears. All 12
	# must appear — this is the "only 3 characters" bug, tested for real.
	var human: Player = players[0]
	var seen: Array[StringName] = [human.active_hero]
	var swap_action := InputConfig.action(0, &"swap")
	for i in 14:
		Input.action_press(swap_action)
		await get_tree().physics_frame
		Input.action_release(swap_action)
		# A release must be observed before the next press reads as a new edge.
		for f in 3:
			await get_tree().physics_frame
		if not seen.has(human.active_hero):
			seen.append(human.active_hero)
	check("swap walks the FULL roster", seen.size() == GameManager.roster_ids().size(),
		"saw %d of %d: %s" % [seen.size(), GameManager.roster_ids().size(), seen])
	check("swap did not rotate the 3-hero roster underneath",
		MatchState.roster(0).size() == 3)

	# Free ultimates: fire two back to back with the budget untouched.
	var before := MatchState.ults_left(0)
	check("first ultimate fires", human.try_ultimate())
	await get_tree().physics_frame
	check("second ultimate fires immediately", human.try_ultimate())
	check("the ult budget is untouched", MatchState.ults_left(0) == before)

	# Bots: two movers, one idle, and they behave that way over real frames.
	var start_x: Array = [players[1].global_position.x,
		players[2].global_position.x, players[3].global_position.x]
	var jumped := [false]
	for i in 240:
		await get_tree().physics_frame
		if not players[2].is_on_floor() or not players[3].is_on_floor():
			jumped[0] = true
	check("the ally bot stands still",
		absf(players[1].global_position.x - start_x[0]) < 4.0,
		"moved %.1f" % absf(players[1].global_position.x - start_x[0]))
	check("both enemy bots move",
		absf(players[2].global_position.x - start_x[1]) > 20.0
		and absf(players[3].global_position.x - start_x[2]) > 20.0,
		"moved %.1f / %.1f" % [absf(players[2].global_position.x - start_x[1]),
			absf(players[3].global_position.x - start_x[2])])
	check("the movers jump occasionally", jumped[0])

	# Leaving the room takes the switches with it.
	room.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	check("exiting clears both switches",
		not MatchState.free_ultimates and not MatchState.free_cooldowns)

	print("\n%s" % ("ALL CHECKS PASSED" if _fails == 0 else "%d CHECK(S) FAILED" % _fails))
	get_tree().quit(1 if _fails > 0 else 0)
