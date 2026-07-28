class_name DreamSphere extends Node2D
## Vesper's ultimate: a huge, slow sphere that drifts along the aim and passes
## through EVERYTHING — walls, floors, platforms, allies, enemies. Nothing stops
## it; it runs out of range and dies. There is no terrain query here at all, and
## that is deliberate, not an omission.
##
## An enemy it touches drops out of the air — velocity zeroed, momentum
## stripped, the same drop Supernova uses — and goes straight to sleep, no
## stacks needed. Each enemy is caught once per cast. It cannot take a life
## (CLAUDE.md 1).

var radius: float = 96.0
var speed: float = 340.0
var range: float = 2400.0
var sleep_time: float = 9.75
var team_id: int = -1
var accent: Color = Color(1, 0.18, 0.77)

var _direction: Vector2 = Vector2.RIGHT
var _travelled: float = 0.0
var _hit: Dictionary = {}
var _age: float = 0.0

func launch(from: Player, dir: Vector2) -> void:
	global_position = from.global_position
	team_id = from.team_id
	_direction = dir.normalized()
	if from.hero != null:
		accent = from.hero.accent_color

func _physics_process(delta: float) -> void:
	var step := speed * delta
	global_position += _direction * step
	_travelled += step
	_age += delta
	if _travelled >= range:
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
		if victim.global_position.distance_to(global_position) > radius:
			continue
		_hit[id] = true
		# Dropped first, then slept. Air is requested explicitly because a
		# grounded state would zero the drop on its own next frame, and a body
		# caught mid-dash or mid-swing has to be taken out of that state before
		# the sleep can hold it (CLAUDE.md checklist).
		victim.set_velocity_override(Vector2.ZERO)
		victim.momentum_charge = 0.0
		victim.request_state(&"Air")
		victim.apply_sleep(sleep_time)
	queue_redraw()

func _draw() -> void:
	# Black-bodied with a neon rim: menacing, but soft. It is sleep, not fire.
	var breathe: float = 1.0 + sin(_age * 2.2) * 0.03
	var r := radius * breathe
	draw_circle(Vector2.ZERO, r, Color(0.04, 0.03, 0.07, 0.55))
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 64, Color(accent.r, accent.g, accent.b, 0.9), 3.0)
	draw_arc(Vector2.ZERO, r * 0.82, 0.0, TAU, 48,
		Color(accent.r, accent.g, accent.b, 0.35), 2.0)
	# Slow inner drift, so a sphere crossing empty space still reads as moving.
	for i in 3:
		var ang := _age * 0.9 + float(i) * TAU / 3.0
		draw_circle(Vector2(cos(ang), sin(ang)) * r * 0.45, 4.0,
			Color(1, 1, 1, 0.22))
