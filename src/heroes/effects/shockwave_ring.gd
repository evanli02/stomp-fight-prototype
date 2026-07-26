class_name ShockwaveRing extends Node2D
## Cerebelle's ultimate — Supernova (DESIGN 5.2 #4). One ring leaves her body and
## expands until it has covered the whole stage.
##
## It grows slowly on purpose — slower than a capped run — so an enemy who reacts
## immediately can stay ahead of it. But it covers the entire map, so outrunning
## it only buys time: there is no edge to escape past, and until teleports or
## phase terrain exist there is no way to dodge it outright. Reacting early is
## the difference between being caught at speed and being caught cornered.
##
## Being caught costs no life (CLAUDE.md 1): you are stunned, stripped of all
## momentum, and dropped under normal gravity.

var speed: float = 220.0
var max_radius: float = 1600.0
var stun_time: float = 1.0
var team_id: int = -1
var accent: Color = Color(0.62, 0.31, 0.87)

var _radius: float = 0.0
var _hit: Dictionary = {}

func launch(from: Player, ring_speed: float, reach: float, stun: float) -> void:
	global_position = from.global_position
	team_id = from.team_id
	speed = ring_speed
	max_radius = reach
	stun_time = stun
	if from.hero != null:
		accent = from.hero.accent_color

func _physics_process(delta: float) -> void:
	_radius += speed * delta
	if _radius >= max_radius:
		queue_free()
		return
	var targets := get_tree().get_nodes_in_group(&"players")
	targets.sort_custom(func(a: Player, b: Player) -> bool: return a.player_id < b.player_id)
	for t in targets:
		var victim := t as Player
		if victim == null or victim.team_id == team_id:
			continue
		var id := victim.get_instance_id()
		if _hit.has(id):
			continue
		if victim.global_position.distance_to(global_position) > _radius:
			continue
		_hit[id] = true
		# All momentum gone, not redirected: the ring does not throw anyone, it
		# takes their speed away and lets them drop.
		victim.set_velocity_override(Vector2.ZERO)
		victim.momentum_charge = 0.0
		victim.apply_stun(stun_time)
	queue_redraw()

func _draw() -> void:
	var fade: float = clampf(1.0 - _radius / max_radius, 0.25, 1.0)
	draw_arc(Vector2.ZERO, _radius, 0.0, TAU, 96,
		Color(accent.r, accent.g, accent.b, fade), 4.0)
	draw_arc(Vector2.ZERO, maxf(_radius - 5.0, 0.0), 0.0, TAU, 96,
		Color(1, 1, 1, fade * 0.55), 2.0)
	draw_arc(Vector2.ZERO, maxf(_radius - 12.0, 0.0), 0.0, TAU, 96,
		Color(accent.r, accent.g, accent.b, fade * 0.3), 6.0)
