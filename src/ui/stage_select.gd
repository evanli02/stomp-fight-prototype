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

## No countdown for now: the pick waits for the picking seat. The lobby
## guarantees that seat has a real device on it, so there is nobody who cannot
## answer. Put a timer back if a stalled pick ever becomes a real problem.
const NAV_REPEAT: float = 0.18
const NAV_DEADZONE: float = 0.5

## Taller than the old card: the bottom half is a miniature of the layout, so a
## first round on an unseen stage is a choice rather than a surprise.
const CARD: Vector2 = Vector2(300, 240)
const GAP: float = 24.0
## Where the layout miniature sits inside a card.
const PREVIEW: Rect2 = Rect2(16, 104, 268, 108)
const COL_BG: Color = Color(0.05, 0.03, 0.09, 0.88)
const COL_CARD: Color = Color(0.10, 0.07, 0.18)
const COL_FRAME: Color = Color(0.36, 0.36, 0.48)
const COL_TEXT: Color = Color(0.96, 0.96, 0.98)
const COL_DIM: Color = Color(0.45, 0.45, 0.55)
const SEAT_CURSOR: Array[Color] = [Color(1, 1, 1), Color(1, 0.85, 0.3)]

var _canvas: Control
var _stages: Array[StringName] = []
var _cursor: int = 0
## The seat holding the cursor, and the team it plays for. On a team of more
## than one they are different numbers, and the heading names the team.
var _picker: int = 0
var _picker_team: int = 0
var _nav_cooldown: float = 0.0
var _done: bool = false

func _ready() -> void:
	_stages = GameManager.stage_ids()
	_picker = GameManager.stage_picker_seat()
	_picker_team = GameManager.stage_picker_team()
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
	_handle_picker(delta)
	_canvas.queue_redraw()

func _handle_picker(delta: float) -> void:
	# One seat drives, even though the pick belongs to the team: the first seat on
	# the picking team holds the cursor (GameManager.stage_picker_seat).
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

	var heading := "TEAM %d PICKS THE STAGE  (P%d)" % [_picker_team + 1, _picker + 1]
	_shadowed(font, Vector2(size.x * 0.5 - 120, 60), heading, 24, COL_TEXT)
	_shadowed(font, Vector2(size.x * 0.5 - 120, 84), _why(), 13, COL_DIM)

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
	# Shrunk until it fits the card rather than clipped mid-word.
	var blurb: String = GameManager.stage_info(id, "blurb", "")
	var blurb_size := 13
	while blurb_size > 9 and font.get_string_size(blurb, HORIZONTAL_ALIGNMENT_LEFT,
			-1, blurb_size).x > CARD.x - 32.0:
		blurb_size -= 1
	_shadowed(font, at + Vector2(16, 70), blurb, blurb_size, Color(0.85, 0.88, 0.95))
	# What is actually underfoot. A stage list that only gives names makes the
	# first round on a new stage a surprise rather than a choice.
	_shadowed(font, at + Vector2(16, 92), GameManager.stage_info(id, "features", ""), 12, accent)
	_draw_preview(id, Rect2(at + PREVIEW.position, PREVIEW.size))
	if current:
		_shadowed(font, at + Vector2(16, CARD.y - 10), "CURRENT STAGE", 12, COL_DIM)

## The layout miniature: terrain silhouette plus terrain elements in their
## gameplay colours, from the hand-kept "preview" data in STAGE_ROSTER. Purely
## visual — nothing here is measured against, and drawing it never builds a
## stage.
func _draw_preview(id: StringName, box: Rect2) -> void:
	_canvas.draw_rect(box, Color(0.03, 0.02, 0.06))
	_canvas.draw_rect(box, COL_FRAME, false, 1.0)
	var preview: Dictionary = GameManager.stage_info(id, "preview", {})
	if preview.is_empty():
		return
	var stage_size: Vector2 = preview.get("size", Vector2.ONE)
	# Fit, preserving aspect, centred: a squashed stage is a lie about distances.
	var scale: float = minf((box.size.x - 8.0) / stage_size.x, (box.size.y - 8.0) / stage_size.y)
	var origin: Vector2 = box.position + (box.size - stage_size * scale) * 0.5
	for r: Rect2 in preview.get("blocks", []):
		_canvas.draw_rect(Rect2(origin + r.position * scale, (r.size * scale).max(Vector2.ONE)),
			Color(0.32, 0.30, 0.44))
	for mark: Dictionary in preview.get("marks", []):
		var r: Rect2 = mark["rect"]
		var col: Color = mark["color"]
		_canvas.draw_rect(Rect2(origin + r.position * scale, (r.size * scale).max(Vector2.ONE)),
			Color(col.r, col.g, col.b, 0.9))

func _shadowed(font: Font, at: Vector2, msg: String, size: int, col: Color) -> void:
	_canvas.draw_string(font, at + Vector2(1, 1), msg, HORIZONTAL_ALIGNMENT_LEFT, -1, size,
		Color(0, 0, 0, 0.85))
	_canvas.draw_string(font, at, msg, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)
#endregion
