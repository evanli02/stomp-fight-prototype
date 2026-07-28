extends CanvasLayer
## Pause (Escape, or Start on any pad). Volume, restart, and the way back to the
## lobby — the three things a playtest session actually needs mid-match.
##
## Runs with PROCESS_MODE_ALWAYS, which is the whole trick: pausing the tree is
## what stops the bodies, the cooldowns and the results countdown, so the one
## node that has to keep working while paused must opt out of the pause it
## caused. Audio is ALWAYS for the same reason, so the volume slider is audible
## while you are dragging it.
##
## Any seat can drive this, not just whoever opened it. Six people share one
## screen and one of them is holding the pad that paused; making everyone wait
## for that person is worse than the occasional argument over the cursor.
##
## Nothing here is gameplay: it reads MatchState and calls GameManager, and the
## only state it owns is which row the cursor is on.

signal resumed()

enum Row { RESUME, VOLUME, RESTART, LOBBY }

const ROWS: Array[StringName] = [&"RESUME", &"VOLUME", &"RESTART MATCH", &"QUIT TO LOBBY"]
const NAV_REPEAT: float = 0.16
const NAV_DEADZONE: float = 0.5
const VOLUME_STEP: float = 0.1

const PANEL: Vector2 = Vector2(420, 300)
const COL_SHADE: Color = Color(0.03, 0.02, 0.06, 0.72)
const COL_PANEL: Color = Color(0.09, 0.06, 0.16, 0.98)
const COL_FRAME: Color = Color(0.36, 0.36, 0.48)
const COL_TEXT: Color = Color(0.96, 0.96, 0.98)
const COL_DIM: Color = Color(0.45, 0.45, 0.55)
const COL_PICK: Color = Color(1.0, 0.82, 0.25)

var _canvas: Control
var _row: int = 0
var _nav_cooldown: float = 0.0
var _open: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 100                       # above every HUD and the F3 overlay
	_canvas = Control.new()
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_canvas)
	_canvas.draw.connect(_draw_screen)
	visible = false

func _physics_process(delta: float) -> void:
	if InputConfig.pause_pressed():
		if _open:
			_close()
		elif _can_pause():
			_open_menu()
		return
	if not _open:
		return
	_handle_nav(delta)
	_canvas.queue_redraw()

## Only while a stage is up. Pausing a select screen would be pausing a screen
## that is already waiting for somebody, and the lobby has nothing to pause.
func _can_pause() -> bool:
	return GameManager.phase in [
		GameManager.Phase.ROUND_ACTIVE,
		GameManager.Phase.ROUND_RESULTS,
		GameManager.Phase.MATCH_RESULTS,
	]

func _open_menu() -> void:
	_open = true
	_row = 0
	visible = true
	get_tree().paused = true
	_canvas.queue_redraw()

func _close() -> void:
	_open = false
	visible = false
	get_tree().paused = false
	resumed.emit()

## Polls every seat and takes whichever one is saying something. Reading them all
## rather than tracking an owner is what lets anyone reach the menu.
func _handle_nav(delta: float) -> void:
	var move := Vector2.ZERO
	var confirm := false
	for seat in InputConfig.MAX_LOCAL_PLAYERS:
		var frame := InputConfig.poll(seat)
		if frame.move.length() > move.length():
			move = frame.move
		confirm = confirm or frame.jump_pressed or frame.ability_pressed

	_nav_cooldown = maxf(_nav_cooldown - delta, 0.0)
	if move.length() < NAV_DEADZONE:
		_nav_cooldown = 0.0            # release re-arms an instant step
	elif _nav_cooldown <= 0.0:
		if absf(move.y) >= NAV_DEADZONE:
			_row = wrapi(_row + (1 if move.y > 0.0 else -1), 0, ROWS.size())
		elif _row == Row.VOLUME:
			_set_volume(Audio.master_volume + (VOLUME_STEP if move.x > 0.0 else -VOLUME_STEP))
		_nav_cooldown = NAV_REPEAT

	if confirm:
		_activate()

func _set_volume(value: float) -> void:
	Audio.master_volume = clampf(snappedf(value, VOLUME_STEP), 0.0, 1.0)
	# Play the change so the number is not the only feedback for a volume knob.
	Audio.play(&"swap", 1.0)

func _activate() -> void:
	match _row:
		Row.RESUME:
			_close()
		Row.VOLUME:
			pass                       # left/right only; confirm does nothing
		Row.RESTART:
			_close()
			GameManager.restart_match()
		Row.LOBBY:
			_close()
			GameManager.return_to_lobby()

#region Drawing
func _draw_screen() -> void:
	if not _open:
		return
	var font := ThemeDB.fallback_font
	var size := _canvas.size
	_canvas.draw_rect(Rect2(Vector2.ZERO, size), COL_SHADE)

	var at := (size - PANEL) * 0.5
	_canvas.draw_rect(Rect2(at, PANEL), COL_PANEL)
	_canvas.draw_rect(Rect2(at, PANEL), COL_FRAME, false, 2.0)
	_shadowed(font, at + Vector2(28, 52), "PAUSED", 30, COL_TEXT)
	_shadowed(font, at + Vector2(28, 76), "any player can steer this", 12, COL_DIM)

	for i in ROWS.size():
		_draw_row(font, i, at + Vector2(28, 126 + i * 42))

	_shadowed(font, at + Vector2(28, PANEL.y - 22),
		"ESC / START closes   ·   jump or ability confirms", 12, COL_DIM)

func _draw_row(font: Font, index: int, at: Vector2) -> void:
	var picked: bool = _row == index
	if picked:
		_canvas.draw_rect(Rect2(at + Vector2(-12, -20), Vector2(PANEL.x - 32, 30)),
			Color(COL_PICK.r, COL_PICK.g, COL_PICK.b, 0.14))
	_shadowed(font, at, String(ROWS[index]), 18, COL_PICK if picked else COL_TEXT)
	if index != Row.VOLUME:
		return
	# The slider, drawn as ten cells so the step size is visible rather than
	# something you have to discover by holding the stick.
	var bar := at + Vector2(190, -13)
	for cell in 10:
		var box := Rect2(bar + Vector2(cell * 17, 0), Vector2(14, 14))
		var filled: bool = float(cell) < Audio.master_volume * 10.0 - 0.01
		_canvas.draw_rect(box, COL_PICK if filled else COL_PANEL)
		_canvas.draw_rect(box, COL_FRAME, false, 1.0)
	_shadowed(font, at + Vector2(190 + 10 * 17 + 8, 0),
		"%d%%" % roundi(Audio.master_volume * 100.0), 14, COL_DIM)

func _shadowed(font: Font, at: Vector2, msg: String, size: int, col: Color) -> void:
	_canvas.draw_string(font, at + Vector2(1, 1), msg, HORIZONTAL_ALIGNMENT_LEFT, -1, size,
		Color(0, 0, 0, 0.85))
	_canvas.draw_string(font, at, msg, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)
#endregion
