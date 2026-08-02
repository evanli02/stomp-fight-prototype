extends CanvasLayer
## Lobby (DESIGN 10): the format, the match length, and who is playing. The first
## screen of a session and the only one that decides how many seats exist —
## everything after it reads GameManager.team_size.
##
## Players join by pressing a button on the device they want to play with, and
## that press is what binds the device to a seat. Reading the raw event rather
## than a namespaced action is the point: before a device has a seat it has no
## actions, and over Steam Remote Play Together each remote player's controller
## shows up as its own virtual pad with an id nobody can predict in advance. The
## device tells us which id it is at the moment it presses, which is the only
## mapping that survives pads connecting in any order.
##
## The host (whoever takes the keyboard seat) owns the format and match length;
## everyone else only joins or leaves.

signal lobby_confirmed()
## The two development destinations. They hang off the lobby rather than the
## pause menu because both want a session that has not started yet: the balance
## sheet reads hero data with no match in flight, and the training room starts
## its own.
signal balance_sheet_requested()
signal training_room_requested()

const FORMATS: Array[int] = [1, 2, 3]
const BEST_OF: Array[int] = [1, 3, 5]
## Rows the host cursor moves through: two settings, then the two dev tools.
const ROW_FORMAT: int = 0
const ROW_BESTOF: int = 1
const ROW_BALANCE: int = 2
const ROW_TRAINING: int = 3
const ROW_HOST: int = 4
const ROW_JOIN: int = 5
const ROW_COUNT: int = 6
const NAV_REPEAT: float = 0.2
const NAV_DEADZONE: float = 0.5

const COL_BG: Color = Color(0.05, 0.03, 0.09, 0.94)
const COL_CARD: Color = Color(0.10, 0.07, 0.18)
const COL_FRAME: Color = Color(0.36, 0.36, 0.48)
const COL_TEXT: Color = Color(0.96, 0.96, 0.98)
const COL_DIM: Color = Color(0.45, 0.45, 0.55)
const COL_READY: Color = Color(0.24, 0.86, 0.52)
const SEAT: Vector2 = Vector2(180, 76)
const SEAT_GAP: float = 12.0

var _canvas: Control
var _format_index: int = 0
var _bestof_index: int = 1
## Which of the two host settings the cursor is on.
var _row: int = 0
var _nav_cooldown: float = 0.0
var _done: bool = false
## The IP entry box, alive only while the JOIN row is being answered. A real
## Control in a code-drawn UI, because typing an address needs a text field and
## nothing else here does.
var _ip_edit: LineEdit = null
## One line of session state under the online cards ("hosting :30567 - 1
## connected", "could not reach 1.2.3.4", ...). Cosmetic only.
var _net_status: String = ""

func _ready() -> void:
	InputConfig.clear_seats()
	_format_index = FORMATS.find(GameManager.team_size)
	if _format_index < 0:
		_format_index = 0
	_bestof_index = BEST_OF.find(GameManager.best_of)
	if _bestof_index < 0:
		_bestof_index = 1
	_canvas = Control.new()
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_canvas)
	_canvas.draw.connect(_draw_screen)
	# Coming back to the lobby ends any online session: the lobby re-seats
	# everyone from scratch (clear_seats above), and a half-remembered session
	# whose seats were just wiped is worse than no session.
	Net.leave("returned to lobby")
	Net.session_ended.connect(func(reason: String) -> void:
		_net_status = reason)

## Joins only. Everything continuous — cursors, held directions — is polled on
## the physics tick below; this is here because a join has to identify the
## device, and only the raw event carries that.
func _input(event: InputEvent) -> void:
	if _done:
		return
	# While the IP box is up, the keyboard is typing an address, not joining.
	if _ip_edit != null:
		return
	# A connected client's devices drive its own machine's seat 0; pressing the
	# join keys here must not also claim seats in a lobby the host owns.
	if Net.is_client():
		return
	if event is InputEventJoypadButton and event.pressed:
		var pad := event as InputEventJoypadButton
		if pad.button_index == JOY_BUTTON_RIGHT_SHOULDER or pad.button_index == JOY_BUTTON_A:
			InputConfig.claim_seat(InputConfig.Device.PAD, pad.device)
	elif event is InputEventKey and event.pressed and not event.echo:
		var key := event as InputEventKey
		if key.keycode == KEY_SPACE:
			InputConfig.claim_seat(InputConfig.Device.KBM)
		# The second keyboard seat joins on its own jump key, which is also the
		# only way to tell it apart from the first: over a stream both seats type
		# on the same keyboard, so the key pressed IS the identity.
		elif key.keycode == KEY_KP_ENTER or key.keycode == KEY_KP_0:
			InputConfig.claim_seat(InputConfig.Device.KBM_ALT)

func _physics_process(delta: float) -> void:
	if _done:
		return
	# A client's lobby is a waiting room: the host owns every setting and the
	# start button, and the client's next screen arrives as a Net round event.
	if not Net.is_client() and _ip_edit == null:
		_handle_host(delta)
	_canvas.queue_redraw()

## Seat 0 is the host. Before anyone has joined nobody holds seat 0, so its
## bindings are the startup defaults and the keyboard drives them either way —
## which is what lets one person set the format up before the others arrive.
func _handle_host(delta: float) -> void:
	var frame := InputConfig.poll(0)
	_nav_cooldown = maxf(_nav_cooldown - delta, 0.0)
	if absf(frame.move.x) < NAV_DEADZONE and absf(frame.move.y) < NAV_DEADZONE:
		_nav_cooldown = 0.0
	elif _nav_cooldown <= 0.0:
		if absf(frame.move.y) >= NAV_DEADZONE:
			_row = wrapi(_row + (1 if frame.move.y > 0.0 else -1), 0, ROW_COUNT)
		else:
			var step := 1 if frame.move.x > 0.0 else -1
			if _row == ROW_FORMAT:
				_format_index = wrapi(_format_index + step, 0, FORMATS.size())
			elif _row == ROW_BESTOF:
				_bestof_index = wrapi(_bestof_index + step, 0, BEST_OF.size())
		_nav_cooldown = NAV_REPEAT
	# Ability, not jump: jump is the join button, and the host pressing start
	# should not read as one more person sitting down.
	if not frame.ability_pressed:
		return
	if _row == ROW_BALANCE:
		balance_sheet_requested.emit()
	elif _row == ROW_TRAINING:
		_start_training()
	elif _row == ROW_HOST:
		_toggle_hosting()
	elif _row == ROW_JOIN:
		_open_ip_entry()
	elif _ready_to_start():
		_confirm()

#region Online
func _toggle_hosting() -> void:
	if Net.is_host():
		Net.leave("stopped hosting")
		_net_status = "stopped hosting"
		return
	var err := Net.host()
	_net_status = "hosting on port %d" % Net.DEFAULT_PORT if err == OK \
		else "could not host (port in use?)"

## A real LineEdit dropped into the code-drawn screen: typing an address needs a
## text field, and nothing else in this UI does. Enter joins, Esc cancels.
func _open_ip_entry() -> void:
	if _ip_edit != null or Net.is_online():
		return
	_ip_edit = LineEdit.new()
	_ip_edit.text = "127.0.0.1"
	_ip_edit.placeholder_text = "host ip"
	_ip_edit.position = Vector2(_canvas.size.x * 0.5 - 120, _canvas.size.y - 120)
	_ip_edit.size = Vector2(240, 34)
	add_child(_ip_edit)
	_ip_edit.grab_focus()
	_ip_edit.select_all()
	_ip_edit.text_submitted.connect(_join_submitted)
	_ip_edit.gui_input.connect(func(ev: InputEvent) -> void:
		var key := ev as InputEventKey
		if key != null and key.pressed and key.keycode == KEY_ESCAPE:
			_close_ip_entry())

func _join_submitted(text: String) -> void:
	_close_ip_entry()
	var parts := text.strip_edges().split(":")
	var port := int(parts[1]) if parts.size() > 1 and parts[1].is_valid_int() \
		else Net.DEFAULT_PORT
	var err := Net.join(parts[0], port)
	_net_status = "joining %s..." % parts[0] if err == OK else "bad address"

func _close_ip_entry() -> void:
	if _ip_edit != null:
		_ip_edit.queue_free()
		_ip_edit = null
#endregion

## The training room seats two people and two standing targets, and assigns its
## own devices (keyboard + first pad), so it does not care who joined the lobby.
func _start_training() -> void:
	_done = true
	training_room_requested.emit()

func _seats_needed() -> int:
	return GameManager.TEAMS * FORMATS[_format_index]

## Every seat filled. An unclaimed seat would put a body on the stage that
## nobody is driving, which in a stomp game is a free life for the other team.
func _ready_to_start() -> bool:
	return InputConfig.claimed_count() >= _seats_needed()

func _confirm() -> void:
	_done = true
	GameManager.team_size = FORMATS[_format_index]
	GameManager.best_of = BEST_OF[_bestof_index]
	lobby_confirmed.emit()

#region Drawing
func _draw_screen() -> void:
	var font := ThemeDB.fallback_font
	var size := _canvas.size
	_canvas.draw_rect(Rect2(Vector2.ZERO, size), COL_BG)

	_shadowed(font, Vector2(size.x * 0.5 - 70, 64), "OVERSTOMP", 34, COL_TEXT)
	_shadowed(font, Vector2(size.x * 0.5 - 150, 92),
		"stomp heads. nothing else takes a life.", 13, COL_DIM)

	_draw_setting(font, Vector2(size.x * 0.5 - 250, 160), ROW_FORMAT, "FORMAT",
		"%dv%d" % [FORMATS[_format_index], FORMATS[_format_index]])
	_draw_setting(font, Vector2(size.x * 0.5 + 50, 160), ROW_BESTOF, "MATCH",
		"best of %d" % BEST_OF[_bestof_index])
	# Dev tools, visually quieter than the match settings above them — they are
	# always available but are not what most sessions are here for.
	_draw_tool(font, Vector2(size.x * 0.5 - 250, 232), ROW_BALANCE,
		"BALANCE SHEET", "every hero's numbers on one page")
	_draw_tool(font, Vector2(size.x * 0.5 + 50, 232), ROW_TRAINING,
		"TRAINING ROOM", "any hero, 3 bots, free ultimates")
	# Online, flanking the dev tools. Host on the left, join on the right.
	_draw_tool(font, Vector2(size.x * 0.5 - 460, 232), ROW_HOST,
		"STOP HOSTING" if Net.is_host() else "HOST ONLINE",
		"%d connected" % Net.client_count() if Net.is_host() else "port %d" % Net.DEFAULT_PORT)
	_draw_tool(font, Vector2(size.x * 0.5 + 260, 232), ROW_JOIN,
		"JOIN", "connect to a host by ip")
	if not _net_status.is_empty():
		_shadowed(font, Vector2(size.x * 0.5 - 150, 322), _net_status, 12, COL_READY)

	_draw_seats(font, size)

	# A connected client sees a waiting room, not controls it does not have.
	if Net.is_client():
		var who := "connected — you are P%d" % (Net.my_seat + 1) if Net.my_seat >= 0 \
			else "connecting..."
		_shadowed(font, Vector2(size.x * 0.5 - 150, size.y - 56),
			who + "   ·   waiting for the host to start", 15, COL_READY)
		return

	var msg := ""
	if _row == ROW_BALANCE or _row == ROW_TRAINING:
		msg = "press ABILITY (LMB / L1) to open"
	elif _row == ROW_HOST or _row == ROW_JOIN:
		msg = "press ABILITY (LMB / L1) to select"
	elif _ready_to_start():
		msg = "press ABILITY (LMB / L1) to start"
	else:
		msg = "waiting for %d more" % (_seats_needed() - InputConfig.claimed_count())
	_shadowed(font, Vector2(size.x * 0.5 - 130, size.y - 56), msg, 15,
		COL_READY if (_ready_to_start() or _row >= ROW_BALANCE) else COL_DIM)
	_shadowed(font, Vector2(size.x * 0.5 - 190, size.y - 32),
		"join: SPACE (WASD) · NUMPAD 0 (arrows) · R1/A on a pad   ·   host steers with WASD", 12, COL_DIM)

func _draw_setting(font: Font, at: Vector2, row: int, label: String, value: String) -> void:
	var box := Rect2(at, Vector2(200, 64))
	_canvas.draw_rect(box, COL_CARD)
	_canvas.draw_rect(box, Color(1, 1, 1) if _row == row else COL_FRAME, false,
		3.0 if _row == row else 1.0)
	_shadowed(font, at + Vector2(14, 24), label, 12, COL_DIM)
	_shadowed(font, at + Vector2(14, 50), value, 22, COL_TEXT)

func _draw_tool(font: Font, at: Vector2, row: int, label: String, hint: String) -> void:
	var box := Rect2(at, Vector2(200, 44))
	var selected: bool = _row == row
	_canvas.draw_rect(box, COL_CARD)
	_canvas.draw_rect(box, Color(1, 1, 1) if selected else COL_FRAME, false,
		3.0 if selected else 1.0)
	_shadowed(font, at + Vector2(14, 20), label, 14,
		COL_TEXT if selected else COL_DIM)
	_shadowed(font, at + Vector2(14, 36), hint, 10, COL_DIM)

func _draw_seats(font: Font, size: Vector2) -> void:
	var needed := _seats_needed()
	var per_team: int = FORMATS[_format_index]
	var row_w := per_team * SEAT.x + (per_team - 1) * SEAT_GAP
	for team in GameManager.TEAMS:
		var top := 300.0 + team * (SEAT.y + 50.0)
		_shadowed(font, Vector2(size.x * 0.5 - row_w * 0.5, top - 8), "TEAM %d" % (team + 1),
			13, COL_DIM)
		for slot in per_team:
			var seat := team * per_team + slot
			_draw_seat(font, seat,
				Vector2(size.x * 0.5 - row_w * 0.5 + slot * (SEAT.x + SEAT_GAP), top))
	# Seats claimed beyond what the format needs — someone joined, then the host
	# shrank the format. Say so rather than silently dropping them.
	if InputConfig.claimed_count() > needed:
		_shadowed(font, Vector2(size.x * 0.5 - 150, size.y - 80),
			"%d joined, %dv%d only seats %d" % [InputConfig.claimed_count(),
				per_team, per_team, needed], 12, Color(1, 0.55, 0.4))

func _draw_seat(font: Font, seat: int, at: Vector2) -> void:
	var claimed := InputConfig.seat_claimed(seat)
	_canvas.draw_rect(Rect2(at, SEAT), COL_CARD)
	_canvas.draw_rect(Rect2(at, SEAT), COL_READY if claimed else COL_FRAME, false,
		2.0 if claimed else 1.0)
	if claimed:
		_shadowed(font, at + Vector2(12, 30), "P%d" % (seat + 1), 20, COL_TEXT)
		_shadowed(font, at + Vector2(12, 56), InputConfig.device_label(seat), 12, COL_READY)
	else:
		_shadowed(font, at + Vector2(12, 30), "P%d" % (seat + 1), 20, COL_DIM)
		_shadowed(font, at + Vector2(12, 56), "press to join", 12, COL_DIM)

func _shadowed(font: Font, at: Vector2, msg: String, size: int, col: Color) -> void:
	_canvas.draw_string(font, at + Vector2(1, 1), msg, HORIZONTAL_ALIGNMENT_LEFT, -1, size,
		Color(0, 0, 0, 0.85))
	_canvas.draw_string(font, at, msg, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)
#endregion
