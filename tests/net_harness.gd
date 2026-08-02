extends Node
## Online-play harness (IMPLEMENTATION.md 9a). Two REAL processes over real
## ENet on localhost — not a mocked peer — because the thing being tested is the
## seam: a remote press crossing the wire, entering through InputConfig.poll,
## moving a body the host simulates, and coming back as a snapshot that moves
## the client's puppet.
##
## This process is the HOST. It spawns the client process itself (same Godot
## binary, --script), hosts a session, seats itself on the keyboard seat, waits
## for the client to claim the other seat, starts a quick match, and asserts the
## remote seat's body obeys input this process never generated. The client
## asserts the mirror half and writes its verdict to user://net_client_report.txt
## (a detached process's stdout goes nowhere); this side folds that report into
## its own output, so one run prints both halves.
##
##   Godot --headless --path . res://tests/net_harness.tscn

const PORT: int = 30599
const REPORT: String = "user://net_client_report.txt"
const TIMEOUT_TICKS: int = 900   ## 15s at 60Hz for each wait

var _failures: int = 0
var _client_pid: int = -1

func _ready() -> void:
	await _run()
	if _client_pid > 0 and OS.is_process_running(_client_pid):
		OS.kill(_client_pid)
	print("\n%s" % ("ALL CHECKS PASSED" if _failures == 0 else "%d CHECK(S) FAILED" % _failures))
	get_tree().quit(1 if _failures > 0 else 0)

func check(label: String, ok: bool, detail: String = "") -> void:
	if not ok:
		_failures += 1
	print("%s %s %s" % ["PASS" if ok else "FAIL", label, detail])

func step(frames: int) -> void:
	for i in frames:
		await get_tree().physics_frame

## Wait until a condition holds or the timeout runs out; returns whether it held.
func wait_until(cond: Callable) -> bool:
	for i in TIMEOUT_TICKS:
		await get_tree().physics_frame
		if cond.call():
			return true
	return false

func _run() -> void:
	var stale := ProjectSettings.globalize_path(REPORT)
	if FileAccess.file_exists(stale):
		DirAccess.remove_absolute(stale)

	check("hosting starts", Net.host(PORT) == OK)
	InputConfig.clear_seats()
	check("the host takes seat 0", InputConfig.claim_seat(InputConfig.Device.KBM) == 0)

	_client_pid = OS.create_process(OS.get_executable_path(),
		["--headless", "--path", ProjectSettings.globalize_path("res://"),
		"--script", "res://tests/net_harness_client.gd"])
	check("the client process launches", _client_pid > 0, "pid=%d" % _client_pid)

	check("the client connects and claims the second seat",
		await wait_until(func() -> bool: return InputConfig.seat_claimed(1)),
		"claimed=%d" % InputConfig.claimed_count())
	check("the remote seat reads as an online device",
		InputConfig.device_of(1) == InputConfig.Device.NET)

	# Start the match exactly the way the shell would, then stand the stage up
	# the way the shell would — the harness plays the part of main.gd.
	GameManager.team_size = 1
	GameManager.current_stage = &"rooftop_rumble"
	GameManager.start_quick_match()
	var stage := GameManager.stage_scene(GameManager.current_stage).instantiate()
	add_child(stage)
	await step(5)

	# The client holds move-right and taps jump. Everything this asserts was
	# caused by input THIS process never read from a device.
	var body: Player = null
	for node in get_tree().get_nodes_in_group(&"players"):
		if (node as Player).player_id == 1:
			body = node
	check("the remote seat has a body", body != null)
	if body == null:
		return
	var start_x := body.global_position.x
	check("remote input moves the remote body",
		await wait_until(func() -> bool: return body.global_position.x > start_x + 60.0),
		"x %.0f -> %.0f" % [start_x, body.global_position.x])
	check("a remote jump edge survives the wire",
		await wait_until(func() -> bool: return body.velocity.y < -100.0),
		"vy=%.0f" % body.velocity.y)

	# The client's own verdict: snapshots moved its puppet, the mirror fed its
	# HUD. It writes the report and exits; fold its lines into this run.
	var report := ProjectSettings.globalize_path(REPORT)
	check("the client reports back",
		await wait_until(func() -> bool: return FileAccess.file_exists(report)))
	if FileAccess.file_exists(report):
		await step(30)   # let the client finish writing and quit
		var f := FileAccess.open(report, FileAccess.READ)
		var lines := f.get_as_text().strip_edges().split("\n")
		for line in lines:
			print(line)
			if line.begins_with("FAIL"):
				_failures += 1
		check("the client ran its full check list", lines.size() >= 4,
			"lines=%d" % lines.size())
	Net.leave("harness done")
