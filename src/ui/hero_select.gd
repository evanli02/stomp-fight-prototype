extends CanvasLayer
## Hero select (DESIGN 2.2): every player picks THREE heroes for the round, no
## duplicates inside one player's own trio. Duplicates across players are legal
## by default — two people may both bring Mason.
##
## Smash-style since the roster hit twelve: ONE shared grid of hero tiles that
## every seat steers a cursor over, with a box per player up top holding their
## three picks. The old per-seat rows drew the whole roster once per player,
## which at 12 heroes x 6 seats was seventy-two cards and ran off every screen.
##
## Runs on the physics tick, not on frames: InputConfig memoises one InputFrame
## per physics tick, so polling from _process would hand the same "just pressed"
## edge back several times and eat a pick per rendered frame.

signal picks_confirmed(rosters: Dictionary, teams: Dictionary)

const PICKS_REQUIRED: int = MatchState.HEROES_PER_PLAYER
## No countdown: the screen waits until every seat has its three. The lobby is
## what makes that safe — a seat only exists once a real device claimed it.
const NAV_REPEAT: float = 0.18
const NAV_DEADZONE: float = 0.5

## The shared grid. 12 heroes at 6 across is two even rows.
const GRID_COLS: int = 6
const TILE: Vector2 = Vector2(104, 118)
## The top strip of a tile belongs to the name; the model sits under it.
const TILE_NAME_H: float = 22.0
const TILE_GAP: float = 10.0
## Hero model scale inside a tile (frames are 32x36 -> 64x72).
const MODEL_SCALE: float = 2.0

## One pick-roster box per player, up top; team 0 stacks on the left, team 1 on
## the right, mirroring how the HUD and the stage lay teams out.
const PBOX: Vector2 = Vector2(216, 96)
const PBOX_GAP: float = 10.0
const SLOT: Vector2 = Vector2(50, 58)

const COL_BG: Color = Color(0.05, 0.03, 0.09, 0.92)
const COL_PANEL: Color = Color(0.08, 0.055, 0.14)
const COL_CARD: Color = Color(0.10, 0.07, 0.18)
const COL_FRAME: Color = Color(0.36, 0.36, 0.48)
const COL_TEXT: Color = Color(0.96, 0.96, 0.98)
const COL_DIM: Color = Color(0.45, 0.45, 0.55)
## One per seat, up to a 3v3. Distinct enough to tell six cursors apart on one
## shared grid.
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
## Idle-frame texture per hero, pulled from its SpriteFrames once.
var _portraits: Dictionary = {}

func _ready() -> void:
	_roster = GameManager.roster_ids()
	_seats = GameManager.seat_count()
	for i in _seats:
		_cursor.append(0)
		_picks.append([] as Array[StringName])
		_nav_cooldown.append(0.0)
	for id in _roster:
		var data := GameManager.hero_data(id)
		if data != null and data.sprite_frames != null \
				and data.sprite_frames.has_animation(&"idle"):
			_portraits[id] = data.sprite_frames.get_frame_texture(&"idle", 0)
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

## Grid navigation: left/right walk the whole roster in reading order (so a
## row edge rolls onto the next row), up/down move a full row and wrap.
func _handle_seat(seat: int, delta: float) -> void:
	var frame := InputConfig.poll(seat)
	_nav_cooldown[seat] = maxf(_nav_cooldown[seat] - delta, 0.0)
	var step := 0
	if absf(frame.move.x) >= NAV_DEADZONE:
		step = 1 if frame.move.x > 0.0 else -1
	elif absf(frame.move.y) >= NAV_DEADZONE:
		step = GRID_COLS if frame.move.y > 0.0 else -GRID_COLS
	if step == 0:
		_nav_cooldown[seat] = 0.0          # release re-arms an instant step
	elif _nav_cooldown[seat] <= 0.0:
		_cursor[seat] = wrapi(_cursor[seat] + step, 0, _roster.size())
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
	_centered(font, Vector2(size.x * 0.5, 40), "PICK THREE HEROES", 24, COL_TEXT)
	_centered(font, Vector2(size.x * 0.5, 62), _waiting_on(), 13, COL_DIM)

	# Player boxes: team 0 down the left, team 1 down the right, VS between —
	# which side a box is on always answers whose it is (same rule as the HUD).
	# At 3v3 the boxes compress, or three per side plus the grid plus the kit
	# lines runs off a 720px viewport.
	var per_team := maxi(_seats / 2, 1)
	var box_h: float = PBOX.y if per_team <= 2 else 68.0
	var boxes_h := per_team * box_h + (per_team - 1) * PBOX_GAP
	var boxes_top := 78.0
	for seat in _seats:
		var team := GameManager.team_of_seat(seat)
		var slot_in_team := GameManager.index_in_team(seat)
		var x := 70.0 if team == 0 else size.x - 70.0 - PBOX.x
		var y := boxes_top + slot_in_team * (box_h + PBOX_GAP)
		_draw_player_box(font, seat, Vector2(x, y), box_h)
	_centered(font, Vector2(size.x * 0.5, boxes_top + boxes_h * 0.5 + 8.0), "VS", 30,
		Color(0.85, 0.30, 0.35))

	# The shared roster grid, centred under the boxes.
	var rows := ceili(float(_roster.size()) / GRID_COLS)
	var grid_w := GRID_COLS * TILE.x + (GRID_COLS - 1) * TILE_GAP
	var grid_h := rows * TILE.y + (rows - 1) * TILE_GAP
	var grid_top := boxes_top + boxes_h + 26.0
	var origin := Vector2(size.x * 0.5 - grid_w * 0.5, grid_top)
	for i in _roster.size():
		var col := i % GRID_COLS
		var row := i / GRID_COLS
		_draw_tile(font, i, origin + Vector2(col * (TILE.x + TILE_GAP), row * (TILE.y + TILE_GAP)))

	# Hovered kits, one line per seat: the pick screen must not force players to
	# memorise a wiki, but six full kit blocks would drown the grid.
	var info_top := grid_top + grid_h + 20.0
	for seat in _seats:
		var hover := GameManager.hero_data(_roster[_cursor[seat]])
		if hover == null:
			continue
		var cursor_col: Color = SEAT_CURSOR[seat % SEAT_CURSOR.size()]
		_shadowed(font, Vector2(origin.x, info_top + seat * 14.0),
			"P%d  %s — %s" % [seat + 1, hover.hero_name, hover.ability_text],
			11, Color(cursor_col.r, cursor_col.g, cursor_col.b, 0.9))
	_centered(font, Vector2(size.x * 0.5, minf(info_top + _seats * 14.0 + 18.0, size.y - 10.0)),
		"move browses   jump/LMB picks   swap/RMB undoes", 12, COL_DIM)

## One player's identity and their three pick slots, model portraits inside.
## `box_h` compresses the box (and its slots with it) for the bigger formats.
func _draw_player_box(font: Font, seat: int, at: Vector2, box_h: float) -> void:
	var cursor_col: Color = SEAT_CURSOR[seat % SEAT_CURSOR.size()]
	var picks: Array = _picks[seat]
	var box_size := Vector2(PBOX.x, box_h)
	_canvas.draw_rect(Rect2(at, box_size), COL_PANEL)
	_canvas.draw_rect(Rect2(at, box_size), cursor_col if picks.size() < PICKS_REQUIRED else COL_FRAME,
		false, 2.0)
	_shadowed(font, at + Vector2(10, 15),
		"P%d  TEAM %d  %s" % [seat + 1, GameManager.team_of_seat(seat) + 1, _device_label(seat)],
		11, cursor_col)

	var slot := Vector2(SLOT.x, minf(SLOT.y, box_h - 26.0))
	var slots_w := PICKS_REQUIRED * slot.x + (PICKS_REQUIRED - 1) * 8.0
	var slot_origin := at + Vector2(box_size.x * 0.5 - slots_w * 0.5, 22.0)
	for i in PICKS_REQUIRED:
		var box := Rect2(slot_origin + Vector2(i * (slot.x + 8.0), 0.0), slot)
		_canvas.draw_rect(box, COL_CARD)
		if i < picks.size():
			var id: StringName = picks[i]
			var data := GameManager.hero_data(id)
			var accent: Color = data.accent_color if data != null else Color.WHITE
			_draw_portrait(id, box, 1.4 if slot.y >= SLOT.y else 1.0)
			_canvas.draw_rect(Rect2(box.position, Vector2(slot.x, 4)), accent)
			_canvas.draw_rect(box, accent, false, 1.0)
		else:
			_canvas.draw_rect(box, COL_FRAME, false, 1.0)

func _device_label(seat: int) -> String:
	return "kbm" if seat == 0 else "pad %d" % InputConfig.pad_index_of(seat)

## One hero tile on the shared grid: name band up top (clipped to the tile so a
## long name can never bleed into the neighbour), model beneath, accent base,
## and one cursor ring per seat hovering it.
func _draw_tile(font: Font, index: int, at: Vector2) -> void:
	var hero_id: StringName = _roster[index]
	var data := GameManager.hero_data(hero_id)
	var accent: Color = data.accent_color if data != null else Color.WHITE

	_canvas.draw_rect(Rect2(at, TILE), COL_CARD)
	_canvas.draw_rect(Rect2(at + Vector2(0, TILE.y - 5), Vector2(TILE.x, 5)), accent)

	# Name on top of the square. Shrunk until it fits rather than clipped
	# mid-word: a truncated name is a quiz, a smaller one is just a name.
	var label: String = data.hero_name if data != null else String(hero_id)
	var font_size := 15
	while font_size > 9 and font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT,
			-1, font_size).x > TILE.x - 10.0:
		font_size -= 1
	_centered(font, at + Vector2(TILE.x * 0.5, TILE_NAME_H - 5.0), label, font_size, COL_TEXT)

	_draw_portrait(hero_id, Rect2(at + Vector2(0, TILE_NAME_H), TILE - Vector2(0, TILE_NAME_H + 5)),
		MODEL_SCALE)

	# Every seat hovering this tile draws its own ring, nested so two cursors on
	# one hero stay two visible cursors.
	var inset := 0.0
	for seat in _seats:
		if _cursor[seat] != index or _picks[seat].size() >= PICKS_REQUIRED:
			continue
		_canvas.draw_rect(Rect2(at + Vector2.ONE * inset, TILE - Vector2.ONE * inset * 2.0),
			SEAT_CURSOR[seat % SEAT_CURSOR.size()], false, 2.0)
		inset += 3.0
	if inset == 0.0:
		_canvas.draw_rect(Rect2(at, TILE), COL_FRAME, false, 1.0)

## The hero's idle frame, centred in a rect at a pixel-art-friendly scale.
func _draw_portrait(hero_id: StringName, rect: Rect2, scale: float) -> void:
	var tex: Texture2D = _portraits.get(hero_id)
	if tex == null:
		return
	var draw_size := Vector2(32, 36) * scale
	var pos := rect.position + (rect.size - draw_size) * 0.5
	_canvas.draw_texture_rect(tex, Rect2(pos.floor(), draw_size), false)

func _centered(font: Font, at: Vector2, msg: String, size: int, col: Color) -> void:
	var w := font.get_string_size(msg, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	_shadowed(font, at - Vector2(w * 0.5, 0.0), msg, size, col)

func _shadowed(font: Font, at: Vector2, msg: String, size: int, col: Color) -> void:
	_canvas.draw_string(font, at + Vector2(1, 1), msg, HORIZONTAL_ALIGNMENT_LEFT, -1, size,
		Color(0, 0, 0, 0.85))
	_canvas.draw_string(font, at, msg, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)
#endregion
