class_name DashState extends PlayerState
## Short burst, not a teleport (DESIGN 4.3): surface dashes are constrained
## parallel to the surface, airborne dashes are omnidirectional but cannot be
## chained until you touch something.

var _remaining: float = 0.0
var _velocity: Vector2 = Vector2.ZERO
## A straight-down air dash forfeits the post-dash speed boost as well as most
## of its distance.
var _grants_boost: bool = true

func enter(_params: Dictionary = {}) -> void:
	Audio.play(&"dash", 0.7)
	player.consume_dash_charge()
	_remaining = player.movement.dash_duration
	var on_surface := player.is_on_floor() or player.is_on_wall()
	# No two consecutive dashes airborne; any surface touch clears the lock.
	if not on_surface:
		player.air_dash_locked = true
	var distance := player.movement.dash_distance
	if player.is_on_floor():
		distance = player.movement.dash_distance_ground
	elif player.is_on_wall():
		distance = player.movement.dash_distance_wall
	# Impairment shortens every dash variant; empowerment lengthens it.
	distance *= maxf(player.launch_mult(), 0.05)
	var dir := _resolve_direction()
	_grants_boost = true
	if not on_surface and dir.y > 0.0 			and absf(dir.x) < player.movement.air_dash_down_deadzone:
		# Straight down only. A dive dash is the best stomp approach there is, so
		# the pure-input version is cut hard and pays no boost; aim it diagonally
		# and it is untouched.
		distance *= player.movement.air_dash_down_mult
		_grants_boost = false
	_velocity = dir * (distance / player.movement.dash_duration)
	if not on_surface and _velocity.y < 0.0:
		# Airborne dashes buy height at a heavy discount — a full-strength upward
		# dash outclimbs the jump and flattens the whole vertical game (DESIGN 4.3).
		_velocity.y *= player.movement.air_dash_up_mult
	player.velocity = _velocity

func physics_update(delta: float) -> void:
	_remaining -= delta
	player.velocity = _velocity  # constant-velocity burst: gravity is suspended
	if _remaining <= 0.0:
		if _grants_boost:
			player.dash_boost_remaining = player.movement.dash_boost_time
		machine.change_state(&"Run" if player.is_on_floor() else &"Air")

func _resolve_direction() -> Vector2:
	var move := player.input.move
	if player.is_on_floor():
		return Vector2(signf(move.x) if not is_zero_approx(move.x) else float(player.facing), 0.0)
	if player.is_on_wall() and player.wall_is_jumpable(player.get_wall_normal()):
		# Along the wall; neutral input climbs.
		return Vector2(0.0, signf(move.y) if not is_zero_approx(move.y) else -1.0)
	# Airborne: movement input, else facing (DESIGN 4.3). The dash is steered by
	# the stick you are already moving with, not by the aim vector — aim belongs
	# to abilities, and stealing it for movement made the two fight each other.
	if move.length() > 0.1:
		return move.normalized()
	return Vector2(float(player.facing), 0.0)

func animation() -> StringName: return &"dash"
