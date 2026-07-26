class_name ExplosionHazard extends TerrainElement
## Telegraphed periodic blast (DESIGN 6.2): a warning glow, then knockback and a
## stun. Never removes a life — the blast makes an opening, someone else has to
## take it (CLAUDE.md 1).
##
## The telegraph is the design: a hazard you cannot read is noise, and one you
## can read becomes a zone the other player has to respect.

@export var period: float = 6.0
@export var warning_time: float = 2.0
@export var knockback: float = 420.0
@export var blast_radius: float = 72.0

var _timer: float = 0.0

func tick(delta: float) -> void:
	_timer += delta
	if _timer >= period:
		_timer = 0.0
		_detonate()
	queue_redraw()

func warning_progress() -> float:
	var into := _timer - (period - warning_time)
	return clampf(into / maxf(warning_time, 0.001), 0.0, 1.0)

func _detonate() -> void:
	for body in get_tree().get_nodes_in_group(&"players"):
		var p := body as Player
		if p == null:
			continue
		var offset := p.global_position - global_position
		if offset.length() > blast_radius:
			continue
		var dir := offset.normalized() if offset.length() > 1.0 else Vector2.UP
		p.apply_impulse(dir * knockback)
		p.apply_stun(p.combat.stun_explosion)

func _draw() -> void:
	var half := size * 0.5
	draw_rect(Rect2(-half, size), Color(0.2, 0.2, 0.3))
	var warn := warning_progress()
	if warn <= 0.0:
		draw_rect(Rect2(-half + Vector2(3, 3), size - Vector2(6, 6)), Color(0.1, 0.08, 0.14))
		return
	# Glow ramps gold -> red as the blast approaches (STYLE_GUIDE telegraphy).
	var col := Color(1.0, 0.82, 0.25).lerp(Color(0.90, 0.22, 0.27), warn)
	draw_rect(Rect2(-half + Vector2(3, 3), size - Vector2(6, 6)),
		Color(col.r, col.g, col.b, 0.25 + 0.55 * warn))
	draw_arc(Vector2.ZERO, blast_radius * warn, 0.0, TAU, 40,
		Color(col.r, col.g, col.b, 0.45), 2.0)
