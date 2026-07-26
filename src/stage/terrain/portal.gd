class_name Portal extends TerrainElement
## Paired teleport (DESIGN 6.2). The velocity VECTOR is preserved and rotated
## into the exit's orientation, so a portal redirects momentum without giving or
## taking any — enter fast, leave fast, pointing somewhere new.
##
## Both ends lock out briefly on use, or the pair ping-pongs a body forever.

@export var linked_portal: NodePath
@export var lockout: float = 0.35
## Direction this portal faces. The exit's facing is what incoming velocity gets
## rotated onto.
@export var facing: Vector2 = Vector2.RIGHT

var _lock: float = 0.0

func tick(delta: float) -> void:
	if _lock > 0.0:
		_lock = maxf(_lock - delta, 0.0)
	queue_redraw()

func lock() -> void:
	_lock = lockout

func on_body_entered(p: Player) -> void:
	if _lock > 0.0 or linked_portal.is_empty():
		return
	var exit := get_node_or_null(linked_portal) as Portal
	if exit == null:
		return
	# Both ends lock: the arriving body is standing in the exit, and without this
	# it would immediately be sent back.
	lock()
	exit.lock()
	var turn := exit.facing.angle() - facing.angle()
	p.global_position = exit.global_position
	p.set_velocity_override(p.velocity.rotated(turn))

func _draw() -> void:
	var t := float(Time.get_ticks_msec()) * 0.004
	var rx := size.x * 0.5
	var ry := size.y * 0.5
	var dim := 0.35 if _lock > 0.0 else 1.0
	for i in 3:
		var scale := 1.0 - i * 0.22 - 0.05 * sin(t + i)
		draw_arc(Vector2.ZERO, minf(rx, ry) * scale, 0.0, TAU, 28,
			Color(0.62, 0.31, 0.87, dim * (1.0 - i * 0.2)), 2.0)
	draw_arc(Vector2.ZERO, minf(rx, ry) * 0.25, 0.0, TAU, 20,
		Color(0.78, 0.49, 1.0, dim), 3.0)
