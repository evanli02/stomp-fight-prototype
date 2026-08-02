extends SceneTree
## The CLIENT half of tests/net_harness.tscn — launched by it, never run by
## hand. Joins localhost, claims a seat, presses its own local inputs, and
## asserts the two things only this side can see: snapshots move its puppet, and
## the MatchState mirror feeds a HUD. Verdict goes to user:// because a detached
## process's stdout goes nowhere.
##
## A --script SceneTree runs before autoload NAME bindings exist, so everything
## goes through root.get_node — the same trap as every scratchpad driver.

const PORT: int = 30599
const REPORT: String = "user://net_client_report.txt"
const TIMEOUT_TICKS: int = 900

var _lines: PackedStringArray = []

func _initialize() -> void:
	_run.call_deferred()

func check(label: String, ok: bool, detail: String = "") -> void:
	_lines.append("%s [client] %s %s" % ["PASS" if ok else "FAIL", label, detail])

func wait_until(cond: Callable) -> bool:
	for i in TIMEOUT_TICKS:
		await physics_frame
		if cond.call():
			return true
	return false

func _run() -> void:
	var net: Node = root.get_node("Net")
	var ic: Node = root.get_node("InputConfig")
	var ms: Node = root.get_node("MatchState")
	var gm: Node = root.get_node("GameManager")

	check("join call accepted", net.join("127.0.0.1", PORT) == OK)
	check("the host assigns a seat",
		await wait_until(func() -> bool: return net.my_seat >= 0),
		"seat=%d" % net.my_seat)

	# Wait for the host's round event, then stand the stage up the way main.gd
	# would on a real client.
	var started: Array = [false]
	net.client_round_started.connect(func(_sid: StringName, _i: int) -> void:
		started[0] = true)
	check("the round event arrives", await wait_until(func() -> bool: return started[0]))
	check("the mirror registered both players", ms.players.size() == 2,
		"players=%d" % ms.players.size())
	var stage: Node = gm.stage_scene(gm.current_stage).instantiate()
	root.add_child(stage)
	for i in 5:
		await physics_frame

	# Press OUR devices: move right, and tap jump every half second. Net ships
	# these frames; nothing in this process simulates anything.
	Input.action_press(ic.action(0, &"move_right"))
	var puppet: Node = null
	for node in get_nodes_in_group(&"players"):
		if node.player_id == net.my_seat:
			puppet = node
	check("this seat has a puppet body", puppet != null)
	if puppet == null:
		_finish()
		return
	check("the puppet is a puppet, not a simulation", puppet.puppet)

	# One loop for both proofs, and it keeps tapping jump until the jump has
	# been SEEN coming back — stopping the taps the moment the move lands is
	# what starved the host's own jump assertion in the first run of this
	# harness. The streamed velocity going negative is the full round trip:
	# local press, wire, host simulation, snapshot, puppet.
	var start_x: float = puppet.global_position.x
	var moved: bool = false
	var jumped: bool = false
	for i in TIMEOUT_TICKS:
		await physics_frame
		if i % 30 == 0:
			Input.action_press(ic.action(0, &"jump"))
		elif i % 30 == 5:
			Input.action_release(ic.action(0, &"jump"))
		moved = moved or puppet.global_position.x > start_x + 60.0
		jumped = jumped or puppet.velocity.y < -100.0
		if moved and jumped:
			break
	check("snapshots move this client's own puppet", moved,
		"x %.0f -> %.0f" % [start_x, puppet.global_position.x])
	check("the streamed velocity shows this client's own jump", jumped,
		"vy=%.0f" % puppet.velocity.y)
	# Hold the session a beat so the host's own jump assertion, which runs
	# after its movement one, sees a live jump too.
	for i in 120:
		await physics_frame
		if i % 30 == 0:
			Input.action_press(ic.action(0, &"jump"))
		elif i % 30 == 5:
			Input.action_release(ic.action(0, &"jump"))
	check("the puppet wears a streamed animation",
		String(puppet.puppet_anim) != "", "anim=%s" % puppet.puppet_anim)
	check("the mirror carries HUD-readable state",
		ms.has_player(0) and ms.lives_of(0, ms.active_hero(0)) > 0,
		"active=%s" % ms.active_hero(0))
	_finish()

func _finish() -> void:
	var f := FileAccess.open(REPORT, FileAccess.WRITE)
	f.store_string("\n".join(_lines))
	f.close()
	quit(0)
