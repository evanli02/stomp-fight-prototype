extends CanvasLayer
## Hero select (DESIGN 2.2): every player picks THREE heroes for the round, no
## duplicates inside one player's own trio. Duplicates across players are legal
## by default — two people may both bring Mason.
##
## Runs on the physics tick, not on frames: InputConfig memoises one InputFrame
## per physics tick, so polling from _process would hand the same "just pressed"
## edge back several times and eat a pick per rendered frame.

signal picks_confirmed(rosters: Dictionary, teams: Dictionary)

const SEATS: int = 2
const PICKS_REQUIRED: int = MatchState.HEROES_PER_PLAYER
## Nobody should be able to stall a match forever, and a seat with no controller
## plugged in never picks at all — when this runs out the rest is auto-filled.
const SELECT_TIME: float = 20.0
const NAV_REPEAT: float = 0.18
const NAV_DEADZONE: float = 0.5

const CARD: Vector2 = Vector2(120, 96)
const GAP: float = 14.0
const COL_BG: Color = Color(0.05, 0.03, 0.09, 0.88)
const COL_CARD: Color = Color(0.10, 0.07, 0.18)
const COL_FRAME: Color = Color(0.36, 0.36, 0.48)
const COL_TEXT: Color = Color(0.96, 0.96, 0.98)
const COL_DIM: Color = Color(0.45, 0.45, 0.55)
const SEAT_CURSOR: Array[Color] = [Color(1, 1, 1), Color(1, 0.85, 0.3)]

var _canvas: Control
var _roster: Array[StringName] = []
var _cursor: Array[int] = []
var _picks: Array = []
var _nav_cooldown: Array[float] = []
var _remaining: float = SELECT_TIME
var _done: bool = false

func _ready() -> void:
	_roster = GameManager.roster_ids()
	for i in SEATS:
		_cursor.append(0)
		_picks.append([] as Array[StringName])
		_nav_cooldown.append(0.0)
	_canvas = Control.new()
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_canvas)
	_canvas.draw.connect(_draw_screen)

func _physics_process(delta: float) -> void:
	if _done:
		return
	_remaining -= delta
	for seat in SEATS:
		_handle_seat(seat, delta)
	if _remaining <= 0.0:
		_auto_fill()
	if _all_seats_ready():
		_confirm()
	_canvas.queue_redraw()

func _handle_seat(seat: int, delta: float) -> void:
	var frame := InputConfig.poll(seat)
	_nav_cooldown[seat] = maxf(_nav_cooldown[seat] - delta, 0.0)
	if absf(frame.move.x) < NAV_DEADZONE:
		_nav_cooldown[seat] = 0.0          # release re-arms an instant step
	elif _nav_cooldown[seat] <= 0.0:
		_cursor[seat] = wrapi(_cursor[seat] + signi(int(signf(frame.move.x))), 0, _roster.size())
		_nav_cooldown[seat] = NAV_REPEAT

	if frame.jump_pressed or frame.ability_pressed:
		_pick(seat, _roster[_cursor[seat]])
	if frame.swap_pressed:
		_undo(seat)

func _pick(seat: int, hero_id: StringName) -> void:
	var picks: Array = _picks[seat]
	if picks.size() >= PICKS_REQUIRED or picks.has(hero_id):
		return  # no duplicates inside one player's trio (DESIGN 2.2)
	picks.append(hero_id)

func _undo(seat: int) -> void:
	var picks: Array = _picks[seat]
	if not picks.is_empty():
		picks.pop_back()

## Fill whatever the timer ran out on, in roster order, skipping that seat's own
## existing picks. A seat with no device attached lands here every time.
func _auto_fill() -> void:
	for seat in SEATS:
		for hero_id in _roster:
			if _picks[seat].size() >= PICKS_REQUIRED:
				break
			_pick(seat, hero_id)

func _all_seats_ready() -> bool:
	for seat in SEATS:
		if _picks[seat].size() < PICKS_REQUIRED:
			return false
	return true

func _confirm() -> void:
	_done = true
	var rosters := {}
	var teams := {}
	for seat in SEATS:
		var ids: Array[StringName] = []
		for h in _picks[seat]:
			ids.append(h)
		rosters[seat] = ids
		teams[seat] = seat   # 1v1: one seat per team. Team sizes arrive in M6.
	picks_confirmed.emit(rosters, teams)

#region Drawing
func _draw_screen() -> void:
	var font := ThemeDB.fallback_font
	var size := _canvas.size
	_canvas.draw_rect(Rect2(Vector2.ZERO, size), COL_BG)
	_canvas.draw_string(font, Vector2(size.x * 0.5 - 90, 46), "PICK THREE HEROES",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 24, COL_TEXT)
	_canvas.draw_string(font, Vector2(size.x * 0.5 - 40, 70),
		"%0.0f" % maxf(_remaining, 0.0), HORIZONTAL_ALIGNMENT_LEFT, -1, 18,
		COL_DIM if _remaining > 5.0 else Color(1, 0.4, 0.4))

	var row_w := _roster.size() * CARD.x + (_roster.size() - 1) * GAP
	for seat in SEATS:
		var origin := Vector2(size.x * 0.5 - row_w * 0.5, 110.0 + seat * (CARD.y + 74.0))
		_draw_seat(font, seat, origin)

func _draw_seat(font: Font, seat: int, origin: Vector2) -> void:
	var picks: Array = _picks[seat]
	_canvas.draw_string(font, origin + Vector2(0, -8),
		"P%d   %s" % [seat + 1, "mouse+keyboard" if seat == 0 else "controller"],
		HORIZONTAL_ALIGNMENT_LEFT, -1, 13, COL_DIM)

	for i in _roster.size():
		var hero_id: StringName = _roster[i]
		var data := GameManager.hero_data(hero_id)
		var accent: Color = data.accent_color if data != null else Color.WHITE
		var pos := origin + Vector2(i * (CARD.x + GAP), 0)
		var taken := picks.has(hero_id)

		_canvas.draw_rect(Rect2(pos, CARD), COL_CARD)
		_canvas.draw_rect(Rect2(pos, Vector2(CARD.x, 6)), accent if not taken else accent * 0.5)
		if _cursor[seat] == i and picks.size() < PICKS_REQUIRED:
			_canvas.draw_rect(Rect2(pos, CARD), SEAT_CURSOR[seat], false, 3.0)
		else:
			_canvas.draw_rect(Rect2(pos, CARD), COL_FRAME, false, 1.0)

		var label: String = data.hero_name if data != null else String(hero_id)
		_canvas.draw_string(font, pos + Vector2(10, 32), label,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 17, COL_TEXT if not taken else COL_DIM)
		if data != null:
			_canvas.draw_string(font, pos + Vector2(10, 52), "CD %.0fs" % data.ability_cooldown,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 12, COL_DIM)
		if taken:
			var slot := picks.find(hero_id) + 1
			_canvas.draw_string(font, pos + Vector2(10, CARD.y - 12), "PICK %d" % slot,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 13, accent)

	# Picked-so-far strip, so a player can see their trio without counting cards.
	for slot in PICKS_REQUIRED:
		var box := Rect2(origin + Vector2(slot * 42, CARD.y + 12), Vector2(34, 20))
		if slot < picks.size():
			var d := GameManager.hero_data(picks[slot])
			_canvas.draw_rect(box, d.accent_color if d != null else Color.WHITE)
		else:
			_canvas.draw_rect(box, COL_CARD)
			_canvas.draw_rect(box, COL_FRAME, false, 1.0)
	_canvas.draw_string(font, origin + Vector2(PICKS_REQUIRED * 42 + 10, CARD.y + 28),
		"jump/LMB picks   swap/RMB undoes", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, COL_DIM)
#endregion
