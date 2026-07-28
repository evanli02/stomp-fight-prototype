class_name StunBolt extends Area2D
## Deadeye's projectile. Travels in a straight line, stuns the first enemy it
## touches, and dies on terrain or on timeout.
##
## It applies a stun and nothing else. A projectile that could take a life would
## break the one rule the whole game is built on (CLAUDE.md 1) — only stomps do
## that, so this cannot reach lives even indirectly.

const LENGTH: float = 10.0
const THICKNESS: float = 3.0

var owner_player: Player
var team_id: int = -1
var stun_time: float = 0.8
var speed: float = 620.0
var lifetime: float = 1.4
var accent: Color = Color(1, 0.18, 0.53)
## Deadeye's ultimate shot: drawn heavier so the loaded bolt is legible.
var empowered: bool = false
## The empowered shot flies through terrain — walls are not cover from the
## loaded bolt. The ordinary bolt still dies on the first surface it meets.
var piercing: bool = false

var _direction: Vector2 = Vector2.RIGHT

func launch(from: Player, direction: Vector2, stun: float, bolt_speed: float) -> void:
	owner_player = from
	team_id = from.team_id
	stun_time = stun
	speed = bolt_speed
	_direction = direction.normalized()
	rotation = _direction.angle()
	if from.hero != null:
		accent = from.hero.accent_color

func _ready() -> void:
	# Layer 0 / mask 2: the bolt watches for player bodies without being
	# something anyone can collide with.
	collision_layer = 0
	collision_mask = 2
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(LENGTH, THICKNESS)
	shape.shape = rect
	add_child(shape)
	body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	position += _direction * speed * delta
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()
		return
	# Terrain ends the bolt. Raycast rather than collide so it cannot tunnel
	# through a thin rooftop at speed. The empowered shot skips the check —
	# it exists to punish hiding behind geometry.
	if piercing:
		return
	var space := get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.create(
		position - _direction * speed * delta, position)
	query.collision_mask = 1
	if not space.intersect_ray(query).is_empty():
		queue_free()

func _on_body_entered(body: Node2D) -> void:
	var hit := body as Player
	if hit == null or hit == owner_player or hit.team_id == team_id:
		return
	hit.apply_stun(stun_time)
	queue_free()

func _draw() -> void:
	var length := LENGTH * (1.6 if empowered else 1.0)
	var thick := THICKNESS * (1.8 if empowered else 1.0)
	if empowered:
		draw_rect(Rect2(-length * 0.5 - 3.0, -thick * 0.5 - 1.0,
			length + 6.0, thick + 2.0), Color(1, 1, 1, 0.35))
	draw_rect(Rect2(-length * 0.5, -thick * 0.5, length, thick), accent)
	draw_rect(Rect2(length * 0.5 - 2.0, -thick * 0.5, 2.0, thick), Color.WHITE)
