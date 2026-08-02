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
const ROW_COUNT: int = 4
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

## Joins only. Everything continuous — cursors, held directions — is polled on
## the physics tick below; this is here because a join has to identify the
## device, and only the raw event carries that.
func _input(event: InputEvent) -> void:
	if _done:
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
	elif _ready_to_start():
		_confirm()

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
		"TRAINING ROOM", "2 players, any hero, 2 dummies")

	_draw_seats(font, size)

	var msg := ""
	if _row == ROW_BALANCE or _row == ROW_TRAINING:
		msg = "press ABILITY (LMB / L1) to open"
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
