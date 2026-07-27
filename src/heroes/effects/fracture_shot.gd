class_name FractureShot extends Node2D
## Terra's ultimate (DESIGN 5.2): a wide slab of force that drags whoever it
## catches along with it, then detonates against the first terrain it meets.
## The caught fall to the ground slowed and unable to dash or jump for a beat —
## grounded, in both senses. It cannot take a life (CLAUDE.md 1).

const SIZE: Vector2 = Vector2(64, 76)
const SPEED: float = 480.0
const RANGE: float = 900.0
const BLAST_RADIUS: float = 230.0
const SLOW_MULT: float = 0.805
const SLOW_TIME: float = 6.5
const IMPAIR_TIME: float = 5.0

var owner_team: int = -1
var accent: Color = Color(0.71, 0.40, 0.11)
var _direction: Vector2 = Vector2.RIGHT
var _travelled: float = 0.0
var _area: Area2D
var _dragged: Dictionary = {}
## Where the slab has been, so the path it carved stays readable after it passes.
var _trail: Array = []

func launch(from: Player, dir: Vector2) -> void:
	owner_team = from.team_id
	_direction = dir.normalized()
	global_position = from.global_position + _direction * 30.0
	if from.hero != null:
		accent = from.hero.accent_color

func _ready() -> void:
	_area = Area2D.new()
	_area.collision_layer = 0
	_area.collision_mask = 2
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = SIZE
	shape.shape = rect
	_area.add_child(shape)
	add_child(_area)
	rotation = _direction.angle()

func _physics_process(delta: float) -> void:
	var motion := _direction * SPEED * delta
	# Terrain ends it — raycast so the slab cannot skip a thin wall.
	var space := get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.create(global_position, global_position + motion
		+ _direction * SIZE.x * 0.5)
	query.collision_mask = 1
	var hit := space.intersect_ray(query)
	global_position += motion
	_travelled += motion.length()
	_trail.append(global_position)
	if _trail.size() > 26:
		_trail.pop_front()

	# Drag: caught enemies ride the slab. Sorted for deterministic multi-drag.
	var bodies := _area.get_overlapping_bodies()
	bodies.sort_custom(func(a: Node2D, b: Node2D) -> bool:
		return a.get_instance_id() < b.get_instance_id())
	for body in bodies:
		var p := body as Player
		if p == null or p.team_id == owner_team:
			continue
		_dragged[p.get_instance_id()] = p
		p.global_position += motion
		p.set_velocity_override(_direction * SPEED)

	if not hit.is_empty():
		_detonate()
	elif _travelled >= RANGE:
		queue_free()
	queue_redraw()

func _detonate() -> void:
	for body in get_tree().get_nodes_in_group(&"players"):
		var p := body as Player
		if p == null or p.team_id == owner_team:
			continue
		if p.global_position.distance_to(global_position) > BLAST_RADIUS \
				and not _dragged.has(p.get_instance_id()):
			continue
		# Dropped, slowed, and grounded: no dash, no jump, for a beat.
		p.set_velocity_override(Vector2(0.0, 320.0))
		p.apply_slow(SLOW_MULT, SLOW_TIME, &"fracture")
		p.apply_impairment(0.0, IMPAIR_TIME, &"fracture")
	queue_free()

func _draw() -> void:
	var half := SIZE * 0.5
	# Travel trail, drawn in local space behind the slab.
	for i in _trail.size():
		var at := to_local(_trail[i])
		var fade := float(i) / maxf(float(_trail.size()), 1.0)
		draw_rect(Rect2(at - Vector2(half.x * 0.5, half.y), Vector2(half.x, SIZE.y)),
			Color(accent.r, accent.g, accent.b, 0.05 + 0.22 * fade))
	draw_rect(Rect2(-half, SIZE), Color(accent.r, accent.g, accent.b, 0.8))
	draw_rect(Rect2(-half, SIZE), Color(1, 1, 1, 0.9), false, 2.0)
	draw_rect(Rect2(Vector2(half.x - 6, -half.y), Vector2(6, SIZE.y)), Color(1, 1, 1, 0.7))
