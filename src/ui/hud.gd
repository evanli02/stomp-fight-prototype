extends CanvasLayer
## In-round HUD (DESIGN 10): each player's 3 hero cards with 2 life pips, the
## active hero highlighted, an ability cooldown bar, and the ultimate marker.
##
## Reads MatchState and never mutates it. Drawn in code rather than laid out as
## nodes because the layout is entirely a function of the roster, which is not
## known until the round starts.

const CARD_W: float = 84.0
const CARD_H: float = 38.0
const CARD_GAP: float = 6.0
const MARGIN: Vector2 = Vector2(18, 14)

const COL_BG: Color = Color(0.06, 0.03, 0.09, 0.72)
const COL_FRAME: Color = Color(0.36, 0.36, 0.48)
const COL_ACTIVE: Color = Color(1, 1, 1)
const COL_PIP_OFF: Color = Color(0.24, 0.22, 0.32)
const COL_DEAD: Color = Color(0.5, 0.5, 0.5, 0.35)
const COL_ULT: Color = Color(1, 0.82, 0.25)

var _canvas: Control

## Every string on the HUD gets a hard 1px drop shadow: cheap, and it keeps text
## readable over any stage colour — the accessibility floor for a moving game.
func _text(font: Font, at: Vector2, msg: String, size: int, col: Color) -> void:
	_canvas.draw_string(font, at + Vector2(1, 1), msg, HORIZONTAL_ALIGNMENT_LEFT, -1, size,
		Color(0, 0, 0, 0.85))
	_canvas.draw_string(font, at, msg, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)

func _ready() -> void:
	_canvas = Control.new()
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_canvas)
	_canvas.draw.connect(_draw_hud)
	# Any of these can change what the HUD shows; redraw rather than poll.
	for sig in [MatchState.life_lost, MatchState.hero_eliminated,
			MatchState.hero_swapped, MatchState.ultimate_spent,
			MatchState.round_won, MatchState.cooldown_started]:
		sig.connect(func(_a = null, _b = null, _c = null) -> void: _canvas.queue_redraw())

func _process(_delta: float) -> void:
	_canvas.queue_redraw()  # cooldown bars are continuous; the rest is signal-driven

func _draw_hud() -> void:
	if MatchState.players.is_empty():
		return
	var font := ThemeDB.fallback_font
	var width := _canvas.size.x
	for pid in MatchState.players:
		# Seat 0 hugs the left edge, everyone else mirrors to the right.
		var mirrored: bool = pid != 0
		var roster: Array = MatchState.roster(pid)
		var block_w := roster.size() * CARD_W + (roster.size() - 1) * CARD_GAP
		var origin := Vector2(width - MARGIN.x - block_w if mirrored else MARGIN.x, MARGIN.y)
		_draw_player(font, pid, roster, origin)

func _draw_player(font: Font, pid: int, roster: Array, origin: Vector2) -> void:
	var active := MatchState.active_hero(pid)
	for i in roster.size():
		var hero_id: StringName = roster[i]
		var pos := origin + Vector2(i * (CARD_W + CARD_GAP), 0)
		var rect := Rect2(pos, Vector2(CARD_W, CARD_H))
		var lives := MatchState.lives_of(pid, hero_id)
		var data := GameManager.hero_data(hero_id)
		var accent: Color = data.accent_color if data != null else Color.WHITE

		_canvas.draw_rect(rect, COL_BG)
		# The accent stripe is the hero's identity; it greys out when eliminated
		# so a dead hero reads as gone at a glance, not just as empty pips.
		var stripe := Rect2(pos, Vector2(CARD_W, 4))
		_canvas.draw_rect(stripe, accent if lives > 0 else COL_DEAD)
		_canvas.draw_rect(rect, COL_ACTIVE if hero_id == active else COL_FRAME,
			false, 2.0 if hero_id == active else 1.0)

		var name_text: String = data.hero_name if data != null else String(hero_id)
		_text(font, pos + Vector2(6, 18), name_text, 12,
			Color.WHITE if lives > 0 else COL_DEAD)

		for pip in MatchState.LIVES_PER_HERO:
			var filled := pip < lives
			var p := Rect2(pos + Vector2(6 + pip * 10, 22), Vector2(7, 7))
			_canvas.draw_rect(p, accent if filled else COL_PIP_OFF)

		# Cooldown: a draining bar AND the number of seconds. The number is the
		# accessible half — bars alone are unreadable at a glance mid-fight.
		var cd := MatchState.cooldown_remaining(pid, hero_id)
		if cd > 0.0 and data != null and data.ability_cooldown > 0.0:
			var frac: float = clampf(cd / data.ability_cooldown, 0.0, 1.0)
			_canvas.draw_rect(Rect2(pos + Vector2(0, CARD_H - 3),
				Vector2(CARD_W * frac, 3)), accent * Color(1, 1, 1, 0.55))
			_text(font, pos + Vector2(CARD_W - 24, 18), "%.0f" % ceilf(cd), 11, accent)

	# Ultimates are per PLAYER, not per hero (DESIGN 2.3): one lamp each, plus the
	# gap between uses when one is still cooling down.
	var ult_pos := origin + Vector2(0, CARD_H + 6)
	var left := MatchState.ults_left(pid)
	var cd := MatchState.ult_cooldown_remaining(pid)
	for i in MatchState.ULTS_PER_ROUND:
		var box := Rect2(ult_pos + Vector2(i * 18, 0), Vector2(14, 14))
		_canvas.draw_rect(box, COL_ULT if i < left else COL_PIP_OFF)
		if i < left and cd > 0.0:
			# Draining fill: the charge is banked but not yet usable.
			var frac: float = clampf(1.0 - cd / MatchState.ULT_COOLDOWN, 0.0, 1.0)
			_canvas.draw_rect(box, COL_PIP_OFF)
			_canvas.draw_rect(Rect2(box.position, Vector2(14 * frac, 14)), COL_ULT)
	var label := "ULT x%d" % left
	if cd > 0.0:
		label = "ULT %.0fs" % cd
	elif left == 0:
		label = "no ults left"
	_text(font, ult_pos + Vector2(MatchState.ULTS_PER_ROUND * 18 + 6, 12), label, 12,
		COL_ULT if MatchState.ult_available(pid) else COL_PIP_OFF)
