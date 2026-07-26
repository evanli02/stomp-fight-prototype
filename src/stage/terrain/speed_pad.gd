class_name SpeedPad extends TerrainElement
## Directional pad (DESIGN 6.2): sets you to (or over) the momentum cap along its
## own direction. Borrows the dash's boost window so the raised speed is not
## clamped away on the very next grounded frame.

@export var direction: Vector2 = Vector2.RIGHT
@export var boost_speed: float = 520.0
@export var retrigger: float = 0.3
var _cooldown: Dictionary = {}

func tick(delta: float) -> void:
	for id in _cooldown.keys():
		_cooldown[id] -= delta
		if _cooldown[id] <= 0.0:
			_cooldown.erase(id)

func on_body_entered(p: Player) -> void:
	var id := p.get_instance_id()
	if _cooldown.has(id):
		return
	_cooldown[id] = retrigger
	p.set_velocity_override(direction.normalized() * boost_speed)
	p.dash_boost_remaining = p.movement.dash_boost_time
	p.momentum_charge = 1.0
	p.facing = 1 if direction.x > 0.0 else -1

func _draw() -> void:
	var half := size * 0.5
	draw_rect(Rect2(-half, size), Color(0.12, 0.23, 0.29))
	var sign_x := 1.0 if direction.x >= 0.0 else -1.0
	for i in 3:
		var x := -half.x + 6 + i * 12
		var tip := Vector2(x + 8 * sign_x, 0)
		draw_colored_polygon(PackedVector2Array([
			Vector2(x, -6), tip, Vector2(x, 6)]), Color(0.18, 0.89, 0.90))
