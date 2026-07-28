class_name BoltProjectile extends Area2D
## The shared body of a small aimed shot: travels in a straight line, dies on
## the first terrain it meets (raycast, not collision, so it cannot tunnel
## through a thin rooftop at speed), dies on timeout, and hands the first enemy
## it touches to `_on_hit`.
##
## Deadeye's stun bolt and Vesper's sleep dart are the same object with
## different payloads, so the flight lives here once and the subclasses say only
## what happens on contact. Neither can reach a life — a projectile that could
## would break the one rule the whole game is built on (CLAUDE.md 1).

const LENGTH: float = 10.0
const THICKNESS: float = 3.0

var owner_player: Player
var team_id: int = -1
var speed: float = 620.0
var lifetime: float = 1.4
var accent: Color = Color(1, 0.18, 0.53)
## Fly through terrain instead of dying on it (Deadeye's loaded shot).
var piercing: bool = false

var _direction: Vector2 = Vector2.RIGHT

func launch(from: Player, direction: Vector2, shot_speed: float) -> void:
	owner_player = from
	team_id = from.team_id
	speed = shot_speed
	_direction = direction.normalized()
	rotation = _direction.angle()
	if from.hero != null:
		accent = from.hero.accent_color

func _ready() -> void:
	# Layer 0 / mask 2: the shot watches for player bodies without being
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
	_on_hit(hit)
	queue_free()

## What this shot does to the enemy it caught. Override; never touch lives.
func _on_hit(_victim: Player) -> void:
	pass
