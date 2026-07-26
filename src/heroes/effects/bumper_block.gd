class_name BumperBlock extends TerrainElement
## Mason's ability block (DESIGN 5.2 #3). A Smash-style bumper: SOLID, so nobody
## walks through it, wrapped in a slightly larger active hitbox that reflects
## whoever touches it.
##
## Reflection is vector-based, not a fixed shove: your outgoing direction is your
## incoming direction mirrored about the contact normal, so the block is a tool
## you aim with your own approach rather than a button that pushes people away.
## Fast in, fast out.
##
## The hitbox lingers — it re-checks overlaps every tick instead of waiting for
## an enter signal, so a body resting against it or re-entering quickly still
## gets thrown. Relying on body_entered is what let players walk through the old
## version.

const CORE: Vector2 = Vector2(30, 30)
## The active hitbox reaches past the solid core so contact is detected while the
## player is still moving freely — after the solid body has stopped them, their
## velocity is already gone and there is nothing left to reflect.
const HITBOX_PAD: float = 7.0
const RETRIGGER: float = 0.18

## How much of the incoming speed comes back out.
var elasticity: float = 1.15
## Floor on the outgoing speed, so drifting into it still pops you.
var min_bounce: float = 320.0
var lifetime: float = 4.0
var accent: Color = Color(1, 0.71, 0.33)

var _body: StaticBody2D
var _hitbox: Area2D
var _recent: Dictionary = {}
var _age: float = 0.0

func _ready() -> void:
	# Solid core on the terrain layer: players collide with it like any wall.
	_body = StaticBody2D.new()
	_body.collision_layer = 1
	_body.collision_mask = 0
	var core_shape := CollisionShape2D.new()
	var core_rect := RectangleShape2D.new()
	core_rect.size = CORE
	core_shape.shape = core_rect
	_body.add_child(core_shape)
	add_child(_body)

	_hitbox = Area2D.new()
	_hitbox.collision_layer = 0
	_hitbox.collision_mask = 2      # player bodies
	var hit_shape := CollisionShape2D.new()
	var hit_rect := RectangleShape2D.new()
	hit_rect.size = CORE + Vector2.ONE * HITBOX_PAD * 2.0
	hit_shape.shape = hit_rect
	_hitbox.add_child(hit_shape)
	add_child(_hitbox)

func _physics_process(delta: float) -> void:
	lifetime -= delta
	_age += delta
	if lifetime <= 0.0:
		queue_free()
		return
	for id in _recent.keys():
		_recent[id] -= delta
		if _recent[id] <= 0.0:
			_recent.erase(id)
	var bodies := _hitbox.get_overlapping_bodies()
	bodies.sort_custom(func(a: Node2D, b: Node2D) -> bool:
		return a.get_instance_id() < b.get_instance_id())
	for body in bodies:
		var p := body as Player
		if p == null or _recent.has(p.get_instance_id()):
			continue
		_recent[p.get_instance_id()] = RETRIGGER
		on_body_entered(p)
	queue_redraw()

## TerrainElement contract. Everyone bounces — ally, enemy, and Mason himself.
## Terrain does not take sides.
func on_body_entered(p: Player) -> void:
	var offset := p.global_position - global_position
	# Normal of the face being touched: whichever axis the player is furthest out
	# on. A rectangle has four faces and reflecting off the wrong one sends
	# people sideways through the block.
	var normal := Vector2.RIGHT * signf(offset.x) if absf(offset.x) > absf(offset.y) \
		else Vector2.DOWN * signf(offset.y)
	if normal == Vector2.ZERO:
		normal = Vector2.UP
	var incoming := p.velocity
	var out := incoming.bounce(normal) * elasticity if incoming.length() > 1.0 \
		else normal * min_bounce
	if out.length() < min_bounce:
		out = out.normalized() * min_bounce if out.length() > 1.0 else normal * min_bounce
	# Push clear of the core so the solid body cannot immediately re-stop them.
	p.global_position += normal * 2.0
	p.set_velocity_override(out)
	# A bounce is not a landing: it should not hand back a wall-jump chain.
	p.air_dash_locked = false

func _draw() -> void:
	var half := CORE * 0.5
	var pulse: float = 0.65 + 0.35 * sin(_age * 7.0)
	draw_rect(Rect2(-half, CORE), Color(0.06, 0.04, 0.10, 0.92))
	draw_rect(Rect2(-half, CORE), accent * Color(1, 1, 1, pulse), false, 2.0)
	draw_rect(Rect2(-half + Vector2(4, 4), CORE - Vector2(8, 8)),
		accent * Color(1, 1, 1, 0.22 * pulse))
	# Ring showing the lingering hitbox reach.
	var reach := half + Vector2.ONE * HITBOX_PAD
	draw_rect(Rect2(-reach, reach * 2.0), accent * Color(1, 1, 1, 0.30 * pulse), false, 1.0)
