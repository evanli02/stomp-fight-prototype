class_name BounceBlock extends TerrainElement
## Mason's placed block (DESIGN 5.2 #3). Everyone ricochets off it — ally, enemy,
## and Mason himself. It is terrain, and terrain does not take sides.
##
## Keystone (the ultimate) is the same block with two extras: enemies passing
## through are knocked back and stunned, allies get a speed buff.

const SIZE: Vector2 = Vector2(40, 40)

var bounce_force: float = 520.0
var lifetime: float = 8.0
var is_keystone: bool = false
var owner_team: int = -1
var stun_time: float = 0.5
var buff_mult: float = 1.15
var buff_time: float = 4.0
var accent: Color = Color(1, 0.71, 0.33)

var _area: Area2D
var _age: float = 0.0

func _ready() -> void:
	_area = Area2D.new()
	_area.collision_layer = 0
	_area.collision_mask = 2          # watch player bodies only
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = SIZE
	shape.shape = rect
	_area.add_child(shape)
	add_child(_area)
	_area.body_entered.connect(_on_area_body_entered)

func _physics_process(delta: float) -> void:
	lifetime -= delta
	_age += delta
	if lifetime <= 0.0:
		queue_free()
		return
	queue_redraw()

func _on_area_body_entered(body: Node2D) -> void:
	var p := body as Player
	if p != null:
		on_body_entered(p)

## The TerrainElement contract: act on players only through the public API.
func on_body_entered(p: Player) -> void:
	var offset := p.global_position - global_position
	var dir := offset.normalized() if offset.length() > 1.0 else Vector2.UP
	p.apply_impulse(dir * bounce_force)
	if not is_keystone:
		return
	if p.team_id == owner_team:
		p.grant_speed_buff(buff_mult, buff_time)
	else:
		p.apply_stun(stun_time)

func _draw() -> void:
	var half := SIZE * 0.5
	var pulse: float = 0.65 + 0.35 * sin(_age * 6.0)
	draw_rect(Rect2(-half, SIZE), Color(0.06, 0.04, 0.10, 0.85))
	draw_rect(Rect2(-half, SIZE), accent * Color(1, 1, 1, pulse), false, 2.0)
	draw_rect(Rect2(-half + Vector2(4, 4), SIZE - Vector2(8, 8)),
		accent * Color(1, 1, 1, 0.25 * pulse))
	if is_keystone:
		draw_line(-half, half, accent, 1.5)
		draw_line(Vector2(half.x, -half.y), Vector2(-half.x, half.y), accent, 1.5)
