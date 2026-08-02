class_name EmpWave extends Node2D
## Kid's ultimate (DESIGN 5.2): a beat of charge-up, then every enemy on the
## stage is slowed and disrupted — no dash, no abilities, no ultimates — for the
## window. The delay is the counterplay: the ring telegraphs, and an ult spent
## into an EMP-locked scramble is an ult wasted.

var delay: float = 0.6
var slow_mult: float = 0.35
## Long: the EMP is a window the whole team plays inside, not a beat. An
## ultimate that turns the tech off should leave time to actually collect on it.
var duration: float = 9.0
const FADE: float = 0.5

var caster_team: int = -1
var accent: Color = Color(1, 0.55, 0.18)
var _age: float = 0.0
var _fired: bool = false

func charge(caster: Player) -> void:
	caster_team = caster.team_id
	global_position = caster.global_position
	if caster.hero != null:
		accent = caster.hero.accent_color

func _physics_process(delta: float) -> void:
	_age += delta
	if not _fired and _age >= delay:
		_fired = true
		var targets := get_tree().get_nodes_in_group(&"players")
		targets.sort_custom(func(a: Player, b: Player) -> bool: return a.player_id < b.player_id)
		for t in targets:
			var p := t as Player
			if p == null or p.team_id == caster_team:
				continue
			p.apply_slow(slow_mult, duration, &"emp")
			p.apply_disrupt(duration, &"emp")
	if _age >= delay + FADE:
		queue_free()
		return
	queue_redraw()

func _draw() -> void:
	if not _fired:
		# Charge-up: rings collapsing inward. Readable from across the stage.
		var t: float = _age / delay
		for i in 3:
			var r: float = (140.0 - i * 36.0) * (1.0 - t) + 8.0
			draw_arc(Vector2.ZERO, r, 0.0, TAU, 40,
				Color(accent.r, accent.g, accent.b, 0.35 + 0.5 * t), 2.0)
		return
	var fade: float = 1.0 - clampf((_age - delay) / FADE, 0.0, 1.0)
	var r := 40.0 + (_age - delay) * 3200.0
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 80, Color(accent.r, accent.g, accent.b, fade), 4.0)
	draw_arc(Vector2.ZERO, r * 0.85, 0.0, TAU, 64, Color(1, 1, 1, fade * 0.5), 1.5)
