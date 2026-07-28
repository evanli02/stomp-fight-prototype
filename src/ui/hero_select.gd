extends CanvasLayer
## Hero select (DESIGN 2.2): every player picks THREE heroes for the round, no
## duplicates inside one player's own trio. Duplicates across players are legal
## by default — two people may both bring Mason.
##
## Runs on the physics tick, not on frames: InputConfig memoises one InputFrame
## per physics tick, so polling from _process would hand the same "just pressed"
## edge back several times and eat a pick per rendered frame.

signal picks_confirmed(rosters: Dictionary, teams: Dictionary)

const PICKS_REQUIRED: int = MatchState.HEROES_PER_PLAYER
## No countdown for now: the screen waits until every seat has its three. The
## lobby is what makes that safe — a seat only exists once a real device claimed
## it, so there is no longer such a thing as a seat that will never pick. Put a
## timer back if a stalled player ever becomes a real problem in a session.
const NAV_REPEAT: float = 0.18
const NAV_DEADZONE: float = 0.5

const CARD: Vector2 = Vector2(120, 96)
const GAP: float = 14.0
## 8 cards x 120 + 7 gaps = 1058px, inside a 1280 viewport.
const COL_BG: Color = Color(0.05, 0.03, 0.09, 0.88)
const COL_CARD: Color = Color(0.10, 0.07, 0.18)
const COL_FRAME: Color = Color(0.36, 0.36, 0.48)
const COL_TEXT: Color = Color(0.96, 0.96, 0.98)
const COL_DIM: Color = Color(0.45, 0.45, 0.55)
## One per seat, up to a 3v3. Distinct enough to tell six cursors apart on one
## row of cards.
const SEAT_CURSOR: Array[Color] = [
	Color(1, 1, 1), Color(1, 0.85, 0.3), Color(0.45, 0.85, 1.0),
	Color(0.55, 1.0, 0.55), Color(1.0, 0.55, 0.75), Color(0.75, 0.6, 1.0),
]

## Seats in the current format (2 for 1v1, 6 for 3v3). Read once at _ready
## rather than every frame: the format cannot change while this screen is up.
var _seats: int = 2
var _canvas: Control
var _roster: Array[StringName] = []
var _cursor: Array[int] = []
var _picks: Array = []
var _nav_cooldown: Array[float] = []
var _done: bool = false

func _ready() -> void:
	_roster = GameManager.roster_ids()
	_seats = GameManager.seat_count()
	for i in _seats:
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
	for seat in _seats:
		_handle_seat(seat, delta)
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

func _all_seats_ready() -> bool:
	for seat in _seats:
		if _picks[seat].size() < PICKS_REQUIRED:
			return false
	return true

func _confirm() -> void:
	_done = true
	var rosters := {}
	var teams := {}
	for seat in _seats:
		var ids: Array[StringName] = []
		for h in _picks[seat]:
			ids.append(h)
		rosters[seat] = ids
		teams[seat] = GameManager.team_of_seat(seat)
	picks_confirmed.emit(rosters, teams)

## Who the screen is still waiting for. With no countdown, saying so is the only
## thing that stops a stalled select from looking like a hang.
func _waiting_on() -> String:
	var pending: Array[String] = []
	for seat in _seats:
		if _picks[seat].size() < PICKS_REQUIRED:
			pending.append("P%d" % (seat + 1))
	if pending.is_empty():
		return "starting..."
	return "waiting on %s" % ", ".join(pending)

#region Drawing
func _draw_screen() -> void:
	var font := ThemeDB.fallback_font
	var size := _canvas.size
	_canvas.draw_rect(Rect2(Vector2.ZERO, size), COL_BG)
	_canvas.draw_string(font, Vector2(size.x * 0.5 - 90, 46), "PICK THREE HEROES",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 24, COL_TEXT)
	_canvas.draw_string(font, Vector2(size.x * 0.5 - 88, 70), _waiting_on(),
		HORIZONTAL_ALIGNMENT_LEFT, -1, 14, COL_DIM)

	# Rows are packed to fit however many seats the format has: six rows at the
	# 1v1 spacing would run off the bottom of a 720px viewport.
	var row_w := _roster.size() * CARD.x + (_roster.size() - 1) * GAP
	var top := 104.0
	var pitch: float = minf(CARD.y + 106.0, (size.y - top - 24.0) / float(_seats))
	for seat in _seats:
		_draw_seat(font, seat, Vector2(size.x * 0.5 - row_w * 0.5, top + seat * pitch), pitch)

func _shadowed(font: Font, at: Vector2, msg: String, size: int, col: Color) -> void:
	_canvas.draw_string(font, at + Vector2(1, 1), msg, HORIZONTAL_ALIGNMENT_LEFT, -1, size,
		Color(0, 0, 0, 0.85))
	_canvas.draw_string(font, at, msg, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)

func _draw_seat(font: Font, seat: int, origin: Vector2, pitch: float) -> void:
	var picks: Array = _picks[seat]
	_canvas.draw_string(font, origin + Vector2(0, -8),
		"P%d   TEAM %d   %s" % [seat + 1, GameManager.team_of_seat(seat) + 1,
			"mouse+keyboard" if seat == 0 else "pad %d" % InputConfig.pad_index_of(seat)],
		HORIZONTAL_ALIGNMENT_LEFT, -1, 13, COL_DIM)
	# The kit text under each row is the first thing to go when rows are packed:
	# it is the tallest part and the least useful once you already know a roster.
	var roomy: bool = pitch > CARD.y + 70.0

	for i in _roster.size():
		var hero_id: StringName = _roster[i]
		var data := GameManager.hero_data(hero_id)
		var accent: Color = data.accent_color if data != null else Color.WHITE
		var pos := origin + Vector2(i * (CARD.x + GAP), 0)
		var taken := picks.has(hero_id)

		_canvas.draw_rect(Rect2(pos, CARD), COL_CARD)
		_canvas.draw_rect(Rect2(pos, Vector2(CARD.x, 6)), accent if not taken else accent * 0.5)
		if _cursor[seat] == i and picks.size() < PICKS_REQUIRED:
			_canvas.draw_rect(Rect2(pos, CARD), SEAT_CURSOR[seat % SEAT_CURSOR.size()], false, 3.0)
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
	_shadowed(font, origin + Vector2(PICKS_REQUIRED * 42 + 10, CARD.y + 28),
		"jump/LMB picks   swap/RMB undoes", 12, COL_DIM)
	# What the hovered hero actually does — pick screens that hide the kit force
	# players to memorise a wiki.
	var hover := GameManager.hero_data(_roster[_cursor[seat]])
	if hover != null and roomy:
		_shadowed(font, origin + Vector2(0, CARD.y + 46), hover.ability_text, 11,
			Color(0.85, 0.88, 0.95))
		_shadowed(font, origin + Vector2(0, CARD.y + 60), hover.ultimate_text, 11,
			Color(0.75, 0.72, 0.60))
#endregion
