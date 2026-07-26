class_name CrouchState extends PlayerState
## Grounded, holding down (DESIGN 4.6). The body is half height, so a crouching
## player fits under things and presents a lower head — being crouched is not
## protection, it just moves the target.
##
## Standing still is the whole state: leftover speed bleeds off, and running out
## of a crouch has to go through Idle/Run. Sliding is the fast version, and it is
## reached from Run, never from here.

func enter(_params: Dictionary = {}) -> void:
	player.set_crouched(true)

func exit() -> void:
	player.set_crouched(false)

func physics_update(delta: float) -> void:
	if try_dash():
		return
	if try_ground_jump():  # crouch-jumping stands you up on the way out
		return
	if not player.is_on_floor():
		machine.change_state(&"Air")
		return
	player.velocity.y = 0.0
	player.velocity.x = move_toward(player.velocity.x, 0.0, player.movement.ground_friction * delta)
	if not player.wants_crouch():
		machine.change_state(&"Idle" if is_zero_approx(player.input.move.x) else &"Run")

func animation() -> StringName: return &"crouch"
