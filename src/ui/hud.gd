extends CanvasLayer
## In-round HUD (DESIGN 10): each player's 3 hero cards with 2 life pips, the
## active hero highlighted, an ability cooldown bar, and the ultimate marker.
##
## Reads MatchState and never mutates it. Drawn in code rather than laid out as
## nodes because the layout is entirely a function of the roster and the format,
## neither of which is known until the round starts.
##
## Laid out by TEAM, not by seat: team 0 stacks down the left edge and team 1
## down the right, so which side of the screen a block is on always answers
## "whose side is that". The previous version put seat 0 on the left and every
## other seat at the same spot on the right, which was fine at 1v1 and drew three
## blocks on top of each other at 3v3.
##
## Blocks shrink as the format grows. Six full-size blocks do not fit above the
## play area, and a HUD that overlaps the fight is worse than a terse one.

const CARD_W: float = 84.0
const CARD_H: float = 38.0
const CARD_GAP: float = 6.0
const MARGIN: Vector2 = Vector2(18, 12)
## Gap between one seat's block and the next one down.
const ROW_GAP: float = 10.0

const COL_BG: Color = Color(0.06, 0.03, 0.09, 0.72)
const COL_FRAME: Color = Color(0.36, 0.36, 0.48)
const COL_ACTIVE: Color = Color(1, 1, 1)
const COL_PIP_OFF: Color = Color(0.24, 0.22, 0.32)
const COL_DEAD: Color = Color(0.5, 0.5, 0.5, 0.35)
const COL_ULT: Color = Color(1, 0.82, 0.25)
const COL_SEAT: Color = Color(0.62, 0.64, 0.78)

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

## How much of the full-size block a seat gets. One block per seat at full size
## is 1v1's luxury; six of them would cover a third of the screen, and the HUD
## must never be the reason you lost track of a body.
func _scale() -> float:
	match MatchState.players.size():
		0, 1, 2:
			return 1.0
		3, 4:
			return 0.80
	return 0.64

## Seats grouped by team, in seat order. Teams come from MatchState rather than
## GameManager because a debug scene can register whatever teams it likes.
func _teams() -> Dictionary:
	var out := {}
	var seats: Array = MatchState.players.keys()
	seats.sort()
	for pid in seats:
		var team: int = MatchState.team_of(pid)
		if not out.has(team):
			out[team] = []
		out[team].append(pid)
	return out

func _draw_hud() -> void:
	if MatchState.players.is_empty():
		return
	var font := ThemeDB.fallback_font
	var s := _scale()
	var width := _canvas.size.x
	for team in _teams():
		var seats: Array = _teams()[team]
		# Team 0 hugs the left edge; every other team mirrors to the right. Two
		# teams is the format (DESIGN 2.1), so in practice this is left and right.
		var mirrored: bool = team != 0
		for row in seats.size():
			var pid: int = seats[row]
			var roster: Array = MatchState.roster(pid)
			var block_w: float = roster.size() * CARD_W * s + (roster.size() - 1) * CARD_GAP * s
			var origin := Vector2(
				width - MARGIN.x - block_w if mirrored else MARGIN.x,
				MARGIN.y + row * (_block_h(s) + ROW_GAP * s))
			_draw_player(font, pid, roster, origin, s, mirrored)

## Header line, card row, ultimate row.
func _block_h(s: float) -> float:
	return (12.0 + CARD_H + 6.0 + 14.0) * s

func _draw_player(font: Font, pid: int, roster: Array, origin: Vector2, s: float,
		mirrored: bool) -> void:
	var active := MatchState.active_hero(pid)
	var card := Vector2(CARD_W, CARD_H) * s
	var gap := CARD_GAP * s
	# Which seat this is. At 1v1 the side of the screen already says it; from 2v2
	# up there are three identical-looking blocks per side and the label is the
	# only thing telling them apart.
	_text(font, origin + Vector2(2, 9 * s), "P%d" % (pid + 1), int(maxf(10.0, 11.0 * s)),
		COL_SEAT)
	var top := origin + Vector2(0, 12.0 * s)

	for i in roster.size():
		var hero_id: StringName = roster[i]
		var pos := top + Vector2(i * (card.x + gap), 0)
		var rect := Rect2(pos, card)
		var lives := MatchState.lives_of(pid, hero_id)
		var data := GameManager.hero_data(hero_id)
		var accent: Color = data.accent_color if data != null else Color.WHITE

		_canvas.draw_rect(rect, COL_BG)
		# The accent stripe is the hero's identity; it greys out when eliminated
		# so a dead hero reads as gone at a glance, not just as empty pips. It is
		# also what carries identity once the format is too tight for names.
		_canvas.draw_rect(Rect2(pos, Vector2(card.x, 4.0 * s)),
			accent if lives > 0 else COL_DEAD)
		_canvas.draw_rect(rect, COL_ACTIVE if hero_id == active else COL_FRAME,
			false, 2.0 if hero_id == active else 1.0)

		# Names are the first thing to go when blocks shrink: they are the widest
		# element and the least useful once you know the roster, and the accent
		# stripe still says which hero it is.
		if s >= 0.9:
			var name_text: String = data.hero_name if data != null else String(hero_id)
			_text(font, pos + Vector2(6, 18) * s, name_text, 12,
				Color.WHITE if lives > 0 else COL_DEAD)

		var pip_y: float = (18.0 if s < 0.9 else 22.0) * s
		for pip in MatchState.LIVES_PER_HERO:
			var filled := pip < lives
			var box := Rect2(pos + Vector2(6.0 * s + pip * 10.0 * s, pip_y),
				Vector2(7, 7) * s)
			_canvas.draw_rect(box, accent if filled else COL_PIP_OFF)

		# Cooldown: a draining bar AND the number of seconds. The number is the
		# accessible half — bars alone are unreadable at a glance mid-fight.
		var cd := MatchState.cooldown_remaining(pid, hero_id)
		if cd > 0.0 and data != null and data.ability_cooldown > 0.0:
			var frac: float = clampf(cd / data.ability_cooldown, 0.0, 1.0)
			_canvas.draw_rect(Rect2(pos + Vector2(0, card.y - 3.0 * s),
				Vector2(card.x * frac, 3.0 * s)), accent * Color(1, 1, 1, 0.55))
			_text(font, pos + Vector2(card.x - 22.0 * s, 16.0 * s), "%.0f" % ceilf(cd),
				int(maxf(9.0, 11.0 * s)), accent)

	# ONE ultimate per HERO per round (DESIGN 2.3), so there is a lamp per hero
	# in roster order, lit while that hero still holds theirs — the lamp row
	# lines up with the portrait row above it, which is what makes "which of my
	# three has an ult left" answerable at a glance. The player-wide gap drains
	# across whichever lamp belongs to the hero currently out.
	var ult_pos := top + Vector2(0, card.y + 6.0 * s)
	var left := MatchState.ults_left(pid)
	var cd_ult := MatchState.ult_cooldown_remaining(pid)
	var lamp := 14.0 * s
	# `active` is already in scope from the portrait row above — same hero, same
	# question, so the lamp row and the portraits cannot disagree about who is out.
	for i in roster.size():
		var hero_id: StringName = roster[i]
		var box := Rect2(ult_pos + Vector2(i * (lamp + 4.0 * s), 0), Vector2(lamp, lamp))
		var held: bool = not MatchState.ult_spent(pid, hero_id)
		_canvas.draw_rect(box, COL_ULT if held else COL_PIP_OFF)
		if held and hero_id == active and cd_ult > 0.0:
			# Draining fill: this hero's ult is unspent but the player is still
			# inside the gap, so it is banked and not yet usable.
			var frac: float = clampf(1.0 - cd_ult / MatchState.ULT_COOLDOWN, 0.0, 1.0)
			_canvas.draw_rect(box, COL_PIP_OFF)
			_canvas.draw_rect(Rect2(box.position, Vector2(lamp * frac, lamp)), COL_ULT)
		# The hero who is actually out is outlined, so the row says whose ult the
		# ULT button would spend right now.
		if hero_id == active:
			_canvas.draw_rect(box, COL_ACTIVE, false, maxf(1.0, s))
	var label := "ULT x%d" % left
	if cd_ult > 0.0:
		label = "ULT %.0fs" % cd_ult
	elif MatchState.ult_spent(pid, active):
		label = "ult spent"
	elif left == 0:
		label = "no ults"
	# Mirrored blocks put the label on the inboard side, so it never runs off the
	# right edge of the screen at 3v3 where the block is already at the margin.
	var label_at := ult_pos + Vector2(roster.size() * (lamp + 4.0 * s) + 6.0 * s,
		lamp * 0.85)
	if mirrored:
		label_at = ult_pos + Vector2(-6.0 * s - 52.0 * s, lamp * 0.85)
	_text(font, label_at, label, int(maxf(9.0, 12.0 * s)),
		COL_ULT if MatchState.ult_available(pid) else COL_PIP_OFF)
