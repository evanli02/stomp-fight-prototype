class_name WallSlideState extends PlayerState
## Cling and descend at a rate set by input (DESIGN 4.4). Wall contact opens the
## perfect wall-jump window (tracked on the player) and resets the air dash.

## Just enough inward speed to keep is_on_wall() true against the collider —
## a contact epsilon, not a feel number.
const WALL_STICK_SPEED: float = 10.0

func enter(_params: Dictionary = {}) -> void:
	player.wall_normal = player.get_wall_normal()

func physics_update(delta: float) -> void:
	if try_dash():
		return
	if player.has_buffered_jump():
		player.consume_jump_buffer()
		machine.change_state(&"WallJump")
		return
	if player.is_on_floor():
		machine.change_state(&"Idle")
		return
	if not player.is_on_wall() or not player.wall_is_jumpable(player.get_wall_normal()):
		machine.change_state(&"Air")
		return

	player.wall_normal = player.get_wall_normal()
	var slide_speed := player.movement.wall_slide_speed_neutral
	if player.input.move.y > 0.5:
		slide_speed = player.movement.fall_speed_max  # down input drops
	elif not is_zero_approx(player.input.move.x) \
			and signf(player.input.move.x) == -signf(player.wall_normal.x):
		slide_speed = player.movement.wall_slide_speed_hold  # holding into the wall
	player.velocity.y = minf(player.velocity.y + player.movement.gravity * delta, slide_speed)
	player.velocity.x = -player.wall_normal.x * WALL_STICK_SPEED

func animation() -> StringName: return &"wall_slide"
