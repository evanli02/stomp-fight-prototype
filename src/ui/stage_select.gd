extends CanvasLayer
## Stage select (DESIGN 2.2): one seat picks the stage for the round about to
## start. Round 1 goes to the coinflip winner; every round after goes to the
## team that just lost — the losing side gets to change the ground.
##
## Only the picking seat has input here. The other seat watching a cursor they
## cannot move is the point: it is the one moment in a round where the score
## visibly buys somebody something.
##
## Runs on the physics tick for the same reason hero select does: InputConfig
## memoises one InputFrame per physics tick, so polling from _process would hand
## the same "just pressed" edge back on several rendered frames and eat a pick.

signal stage_confirmed(stage_id: StringName)

## Nobody should be able to stall a match forever, and a seat with no controller
## plugged in never picks at all — when this runs out the highlighted stage is
## taken.
const SELECT_TIME: float = 15.0
const NAV_REPEAT: float = 0.18
const NAV_DEADZONE: float = 0.5

const CARD: Vector2 = Vector2(300, 176)
const GAP: float = 24.0
const COL_BG: Color = Color(0.05, 0.03, 0.09, 0.88)
const COL_CARD: Color = Color(0.10, 0.07, 0.18)
const COL_FRAME: Color = Color(0.36, 0.36, 0.48)
const COL_TEXT: Color = Color(0.96, 0.96, 0.98)
const COL_DIM: Color = Color(0.45, 0.45, 0.55)
const SEAT_CURSOR: Array[Color] = [Color(1, 1, 1), Color(1, 0.85, 0.3)]

var _canvas: Control
var _stages: Array[StringName] = []
var _cursor: int = 0
var _picker: int = 0
var _nav_cooldown: float = 0.0
var _remaining: float = SELECT_TIME
var _done: bool = false

func _ready() -> void:
	_stages = GameManager.stage_ids()
	_picker = GameManager.stage_picker_team()
	# Start on the stage that is already loaded, so "keep playing here" is the
	# zero-input answer and the timeout never feels like it stole a pick.
	_cursor = maxi(_stages.find(GameManager.current_stage), 0)
	_canvas = Control.new()
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_canvas)
	_canvas.draw.connect(_draw_screen)

func _physics_process(delta: float) -> void:
	if _done:
		return
	_remaining -= delta
	_handle_picker(delta)
	if _remaining <= 0.0:
		_confirm()
	_canvas.queue_redraw()

func _handle_picker(delta: float) -> void:
	# In 1v1 the picking team and the picking seat are the same number. Teams
	# with more than one player need a rule for which of them holds the cursor
	# (TODO M6, same open question as MatchState.stage_picker).
	var frame := InputConfig.poll(_picker)
	_nav_cooldown = maxf(_nav_cooldown - delta, 0.0)
	if absf(frame.move.x) < NAV_DEADZONE:
		_nav_cooldown = 0.0            # release re-arms an instant step
	elif _nav_cooldown <= 0.0:
		var step := 1 if frame.move.x > 0.0 else -1
		_cursor = wrapi(_cursor + step, 0, _stages.size())
		_nav_cooldown = NAV_REPEAT
	if frame.jump_pressed or frame.ability_pressed:
		_confirm()

func _confirm() -> void:
	if _done:
		return
	_done = true
	stage_confirmed.emit(_stages[_cursor])

#region Drawing
func _draw_screen() -> void:
	var font := ThemeDB.fallback_font
	var size := _canvas.size
	_canvas.draw_rect(Rect2(Vector2.ZERO, size), COL_BG)

	var heading := "P%d PICKS THE STAGE" % [_picker + 1]
	_shadowed(font, Vector2(size.x * 0.5 - 120, 60), heading, 24, COL_TEXT)
	_shadowed(font, Vector2(size.x * 0.5 - 120, 84), _why(), 13, COL_DIM)
	_shadowed(font, Vector2(size.x * 0.5 - 12, 112), "%0.0f" % maxf(_remaining, 0.0), 18,
		COL_DIM if _remaining > 5.0 else Color(1, 0.4, 0.4))

	var row_w := _stages.size() * CARD.x + (_stages.size() - 1) * GAP
	var origin := Vector2(size.x * 0.5 - row_w * 0.5, 160.0)
	for i in _stages.size():
		_draw_card(font, i, origin + Vector2(i * (CARD.x + GAP), 0.0))

	_shadowed(font, Vector2(size.x * 0.5 - 130, origin.y + CARD.y + 44),
		"move to browse   jump/LMB confirms", 13, COL_DIM)

## Says out loud why this seat is choosing, because the rule is not obvious from
## the screen alone.
func _why() -> String:
	if GameManager.round_index == 0:
		return "round 1 — coinflip"
	return "round %d — the last round's loser picks" % [GameManager.round_index + 1]

func _draw_card(font: Font, index: int, at: Vector2) -> void:
	var id: StringName = _stages[index]
	var accent: Color = GameManager.stage_info(id, "accent", Color.WHITE)
	var current: bool = id == GameManager.current_stage

	_canvas.draw_rect(Rect2(at, CARD), COL_CARD)
	_canvas.draw_rect(Rect2(at, Vector2(CARD.x, 8)), accent)
	if _cursor == index:
		_canvas.draw_rect(Rect2(at, CARD), SEAT_CURSOR[_picker % SEAT_CURSOR.size()], false, 3.0)
	else:
		_canvas.draw_rect(Rect2(at, CARD), COL_FRAME, false, 1.0)

	_shadowed(font, at + Vector2(16, 44), GameManager.stage_info(id, "name", String(id)),
		22, COL_TEXT)
	_shadowed(font, at + Vector2(16, 70), GameManager.stage_info(id, "blurb", ""), 13,
		Color(0.85, 0.88, 0.95))
	# What is actually underfoot. A stage list that only gives names makes the
	# first round on a new stage a surprise rather than a choice.
	_shadowed(font, at + Vector2(16, 92), GameManager.stage_info(id, "features", ""), 12, accent)
	if current:
		_shadowed(font, at + Vector2(16, CARD.y - 18), "CURRENT STAGE", 12, COL_DIM)

func _shadowed(font: Font, at: Vector2, msg: String, size: int, col: Color) -> void:
	_canvas.draw_string(font, at + Vector2(1, 1), msg, HORIZONTAL_ALIGNMENT_LEFT, -1, size,
		Color(0, 0, 0, 0.85))
	_canvas.draw_string(font, at, msg, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)
#endregion
