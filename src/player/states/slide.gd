class_name SlideState extends PlayerState
## Crouching out of a run (DESIGN 4.6): half-height body, speed and momentum
## bleeding away, and one way to spend what is left — the slide jump, which
## trades almost all of its height for horizontal launch.
##
## Dashing out of a slide is deliberately blocked. Dash is the instant-redirect
## tool, and letting it cancel the slide's decay would make sliding a free
## speed-preserving state instead of a commitment.

var _held: float = 0.0

func enter(_params: Dictionary = {}) -> void:
	player.set_crouched(true)
	_held = 0.0

func exit() -> void:
	player.set_crouched(false)

func physics_update(delta: float) -> void:
	if player.has_buffered_jump():
		player.consume_jump_buffer()
		_slide_jump()
		return
	if not player.is_on_floor():
		machine.change_state(&"Air")
		return

	player.velocity.y = 0.0
	_held += delta
	# The opening of the slide costs nothing: whatever you carried in, you keep.
	# After that it bleeds, gently enough that a slide still crosses ground.
	if _held > player.movement.slide_hold_time:
		player.velocity.x = move_toward(player.velocity.x, 0.0,
			player.movement.slide_friction * delta)
		player.momentum_charge = maxf(
			player.momentum_charge - player.movement.slide_momentum_decay * delta, 0.0)

	if not player.wants_crouch():
		machine.change_state(&"Idle" if is_zero_approx(player.input.move.x) else &"Run")
		return
	if absf(player.velocity.x) < player.movement.slide_exit_speed:
		machine.change_state(&"Crouch")

## Low and long. Not hold-extendable: the slide jump is a committed leap, and
## letting it grow with a held button would just be a better jump.
func _slide_jump() -> void:
	var cfg := player.movement
	player.velocity.x *= cfg.slide_jump_speed_mult
	# The launch outruns the current cap, so borrow the dash's boost window to
	# keep it from being clamped away on the next grounded frame.
	player.dash_boost_remaining = cfg.dash_boost_time
	machine.change_state(&"Air", {
		"jump": true,
		"impulse_y": cfg.jump_impulse_min * cfg.slide_jump_up_mult,
		"extendable": false,
		"anim": &"slide_jump",
	})

func animation() -> StringName: return &"slide"
