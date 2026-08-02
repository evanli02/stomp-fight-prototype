class_name WindBeam extends Node2D
## Kid's wind cannon (DESIGN 5.2): a stage-crossing column of air along the aim,
## applied the instant it fires. It ignores terrain — wind does not care about
## walls — and it blows EVERYONE in the column, allies included, except Kid
## himself. Pure displacement, no stun, no life.

var width: float = 44.0
var push: float = 1000.0
const LIFE: float = 0.28

var from_point: Vector2 = Vector2.ZERO
var direction: Vector2 = Vector2.RIGHT
var accent: Color = Color(1, 0.55, 0.18)
var _age: float = 0.0

func blow(caster: Player, dir: Vector2) -> void:
	from_point = caster.global_position
	direction = dir.normalized()
	global_position = from_point
	if caster.hero != null:
		accent = caster.hero.accent_color
	var targets := caster.get_tree().get_nodes_in_group(&"players")
	targets.sort_custom(func(a: Player, b: Player) -> bool: return a.player_id < b.player_id)
	for t in targets:
		var p := t as Player
		if p == null or p == caster:
			continue
		# Distance from the ray, forward side only: a cannon, not a wall of wind.
		var offset := p.global_position - from_point
		var along := offset.dot(direction)
		if along < 0.0:
			continue
		var lateral := (offset - direction * along).length()
		if lateral > width:
			continue
		p.apply_impulse(direction * push)

func _process(delta: float) -> void:
	_age += delta
	if _age >= LIFE:
		queue_free()
		return
	queue_redraw()

func _draw() -> void:
	var fade: float = 1.0 - clampf(_age / LIFE, 0.0, 1.0)
	var dir := direction
	var n := Vector2(-dir.y, dir.x)
	var reach := 1400.0
	for lane: float in [-1.0, 0.0, 1.0]:
		var off := n * lane * width * 0.5
		draw_line(off, dir * reach + off,
			Color(accent.r, accent.g, accent.b, fade * (0.7 - absf(lane) * 0.25)), 2.0)
	for i in 6:
		var at := dir * (80.0 + i * 200.0 + _age * 900.0)
		draw_line(at - n * width * 0.5, at + n * width * 0.5,
			Color(1, 1, 1, fade * 0.4), 1.0)
