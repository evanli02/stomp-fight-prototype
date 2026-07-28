class_name FreezeBlock extends TerrainElement
## Mason's ultimate — Keystone (DESIGN 5.2 #3). Not solid: Mason and his allies
## walk straight through it. An enemy who touches it is frozen in place and
## stunned, and when the freeze ends they simply fall — gravity, not a push.
##
## No speed buff. The block does one thing: it takes a lane away from the other
## team for a moment, which in a game about landing on heads is enough.

## Bigger than the bumper: the ultimate takes a lane away, and a lane needs
## width. The ability block stays small.
const SIZE: Vector2 = Vector2(40, 40)
## How long a body falls freely between one freeze wearing off and the block
## being allowed to freeze it again. This is the number that decides how many
## times a body falling straight down through the block gets stunned: each
## cycle it drops from rest for FALL_GAP seconds (~24px at gravity 1900), and
## the overlap zone is block + body (~74px), so a clean vertical fall eats
## 3-4 freezes before dropping out the bottom. The old fixed retrigger was
## SHORTER than the freeze, which re-froze a body the frame its stun ended —
## anyone who fell in was stuck until the block expired.
const FALL_GAP: float = 0.16

var lifetime: float = 10.0
var owner_team: int = -1
var freeze_time: float = 0.5
var accent: Color = Color(1, 0.71, 0.33)

var _hitbox: Area2D
var _recent: Dictionary = {}
var _age: float = 0.0

func _ready() -> void:
	_hitbox = Area2D.new()
	_hitbox.collision_layer = 0
	_hitbox.collision_mask = 2
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = SIZE
	shape.shape = rect
	_hitbox.add_child(shape)
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
		# Derived, not fixed: the gap must outlive the freeze or the block
		# re-freezes a body the instant its stun ends and never lets go.
		_recent[p.get_instance_id()] = freeze_time + FALL_GAP
		on_body_entered(p)
	queue_redraw()

func on_body_entered(p: Player) -> void:
	if p.team_id == owner_team:
		return  # Mason and allies pass through untouched
	# Freeze and stun together, so control comes back at the same moment gravity
	# does and the drop reads as "let go", not "knocked down". Never a life
	# (CLAUDE.md 1).
	p.apply_freeze(freeze_time)
	p.apply_stun(freeze_time)

func _draw() -> void:
	var half := SIZE * 0.5
	var pulse: float = 0.55 + 0.45 * sin(_age * 4.0)
	# Hollow and frosted, to read as "walk through me" rather than "solid".
	draw_rect(Rect2(-half, SIZE), Color(0.55, 0.85, 1.0, 0.14 * pulse))
	draw_rect(Rect2(-half, SIZE), accent * Color(1, 1, 1, pulse), false, 2.0)
	for i in 3:
		var inset := 4.0 + i * 3.0
		draw_rect(Rect2(-half + Vector2.ONE * inset, SIZE - Vector2.ONE * inset * 2.0),
			Color(0.75, 0.95, 1.0, 0.20 * pulse), false, 1.0)
