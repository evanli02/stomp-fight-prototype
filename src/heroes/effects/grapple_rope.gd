class_name GrappleRope extends Node2D
## The visible rope between Sai and his hook point, alive exactly as long as he
## is swinging. Watches the state machine rather than being told to die, so no
## exit path from Swing can strand a rope on screen.

var owner_player: Player
var anchor: Vector2 = Vector2.ZERO
var accent: Color = Color(1, 0.43, 0.78)

func _process(_delta: float) -> void:
	if owner_player == null or not is_instance_valid(owner_player) \
			or owner_player.state_machine.state_name() != &"Swing":
		queue_free()
		return
	queue_redraw()

func _draw() -> void:
	if owner_player == null:
		return
	var from := to_local(anchor)
	var to := to_local(owner_player.global_position)
	draw_line(from, to, Color(0.05, 0.03, 0.09), 3.0)
	draw_line(from, to, accent, 1.5)
	draw_circle(from, 3.0, accent)
	draw_circle(from, 1.5, Color.WHITE)
