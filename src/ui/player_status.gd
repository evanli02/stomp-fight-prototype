extends Node2D
## The little readout floating over a player's head: dash charges, the recharge
## in progress, and the active hero's ability cooldown.
##
## Dash charges are movement state a player has to plan around mid-air, and the
## main HUD is at the top of the screen — too far from where you are looking
## during a chase. This sits where the attention already is.
##
## Sibling of the sprite, not a child, so it does not flip with facing.

const PIP: Vector2 = Vector2(6, 4)
const PIP_GAP: float = 2.0
const BAR: Vector2 = Vector2(24, 3)
const HEIGHT_ABOVE_HEAD: float = -36.0

const COL_EMPTY: Color = Color(0.16, 0.14, 0.24, 0.9)
const COL_CHARGE: Color = Color(0.86, 0.94, 1.0)
const COL_RECHARGE: Color = Color(0.45, 0.52, 0.72)
const COL_OUTLINE: Color = Color(0.05, 0.03, 0.09, 0.85)

@onready var _player: Player = get_parent() as Player

func _ready() -> void:
	position.y = HEIGHT_ABOVE_HEAD
	z_index = 10

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	if _player == null:
		return
	_draw_dash_pips()
	_draw_ability_cooldown()

func _draw_dash_pips() -> void:
	var total: int = _player.movement.dash_charges
	var have: int = _player.dash_charges_left
	var row_w := total * PIP.x + (total - 1) * PIP_GAP
	var x := -row_w * 0.5
	# Only one charge refills at a time (DESIGN 4.3), so exactly one pip is ever
	# partially filled — the next one up.
	var recharge_frac := 0.0
	if have < total and _player.movement.dash_recharge > 0.0:
		recharge_frac = clampf(
			1.0 - _player.dash_recharge_remaining / _player.movement.dash_recharge, 0.0, 1.0)
	for i in total:
		var at := Vector2(x + i * (PIP.x + PIP_GAP), 0.0)
		draw_rect(Rect2(at - Vector2.ONE, PIP + Vector2(2, 2)), COL_OUTLINE)
		draw_rect(Rect2(at, PIP), COL_EMPTY)
		if i < have:
			draw_rect(Rect2(at, PIP), COL_CHARGE)
		elif i == have and recharge_frac > 0.0:
			draw_rect(Rect2(at, Vector2(PIP.x * recharge_frac, PIP.y)), COL_RECHARGE)
	# Airborne lock: the charges are there but unusable until you touch something.
	if _player.air_dash_locked:
		draw_line(Vector2(x, PIP.y + 2), Vector2(x + row_w, PIP.y + 2),
			Color(0.9, 0.35, 0.35, 0.9), 1.0)

func _draw_ability_cooldown() -> void:
	if not MatchState.has_player(_player.player_id):
		return
	var hero_id := _player.active_hero
	var remaining := MatchState.cooldown_remaining(_player.player_id, hero_id)
	if remaining <= 0.0:
		return
	var data := GameManager.hero_data(hero_id)
	var full: float = data.ability_cooldown if data != null and data.ability_cooldown > 0.0 else 1.0
	var accent: Color = data.accent_color if data != null else Color.WHITE
	var frac: float = clampf(1.0 - remaining / full, 0.0, 1.0)
	var at := Vector2(-BAR.x * 0.5, -BAR.y - 4.0)
	draw_rect(Rect2(at - Vector2.ONE, BAR + Vector2(2, 2)), COL_OUTLINE)
	draw_rect(Rect2(at, BAR), COL_EMPTY)
	draw_rect(Rect2(at, Vector2(BAR.x * frac, BAR.y)), accent)
