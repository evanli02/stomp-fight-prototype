class_name AirState extends PlayerState
## Jump, fall, variable height, coyote/buffer, and the handoff to WallSlide
## (DESIGN 4.2). Air control is deliberately weak — you commit to your arcs.

var _hold_time: float = 0.0
var _holding: bool = false

func enter(params: Dictionary = {}) -> void:
	_hold_time = 0.0
	_holding = false
	if params.get("jump", false):
		# Stomp bounces come in through the same door as jumps so they inherit
		# hold-extension for free (DESIGN 3.2); the slide jump opts out of it.
		player.velocity.y = params.get("impulse_y", player.movement.jump_impulse_min)
		_holding = params.get("extendable", true)
		if params.get("perfect", false):
			# B-hop: the landing never gets to charge friction, so 100% of the
			# horizontal momentum survives (DESIGN 4.2).
			player.landing_settled = true
			player.note_perfect(&"bhop")

func physics_update(delta: float) -> void:
	if try_dash():
		return
	if try_ground_jump():  # coyote window
		return
	if _holding:
		var can_extend := player.input.jump_held \
			and _hold_time < player.movement.jump_hold_time_max \
			and player.velocity.y < 0.0
		if can_extend:
			player.velocity.y += player.movement.jump_hold_force * delta
			_hold_time += delta
		else:
			_holding = false  # releasing early ends the rise for good
	player.velocity.y = minf(
		player.velocity.y + player.movement.gravity * delta,
		player.movement.fall_speed_max)
	_air_control(delta)

	if player.is_on_floor():
		machine.change_state(&"Idle" if is_zero_approx(player.input.move.x) else &"Run")
		return
	var n := player.get_wall_normal()
	# Only cling when moving into the wall — otherwise the frame right after a
	# wall jump, while contact still reads true, would re-capture the jump.
	if player.is_on_wall() and player.wall_is_jumpable(n) and player.velocity.x * n.x <= 0.0:
		machine.change_state(&"WallSlide")

func _air_control(delta: float) -> void:
	var dir := player.input.move.x
	if is_zero_approx(dir):
		return
	var cap := player.speed_cap()
	# Air control may nudge you toward the cap but never bleeds off over-cap
	# speed carried in from springs, pads, or a dash boost (DESIGN 4.1).
	if absf(player.velocity.x) > cap and signf(player.velocity.x) == signf(dir):
		return
	player.velocity.x = move_toward(player.velocity.x, signf(dir) * cap, player.air_accel() * delta)
