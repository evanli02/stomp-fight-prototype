class_name DashState extends PlayerState
## Short burst, not a teleport (DESIGN 4.3): surface dashes are constrained
## parallel to the surface, airborne dashes are omnidirectional but cannot be
## chained until you touch something.

var _remaining: float = 0.0
var _velocity: Vector2 = Vector2.ZERO

func enter(_params: Dictionary = {}) -> void:
	player.consume_dash_charge()
	_remaining = player.movement.dash_duration
	var on_surface := player.is_on_floor() or player.is_on_wall()
	# No two consecutive dashes airborne; any surface touch clears the lock.
	if not on_surface:
		player.air_dash_locked = true
	_velocity = _resolve_direction() * (player.movement.dash_distance / player.movement.dash_duration)
	player.velocity = _velocity

func physics_update(delta: float) -> void:
	_remaining -= delta
	player.velocity = _velocity  # constant-velocity burst: gravity is suspended
	if _remaining <= 0.0:
		player.dash_boost_remaining = player.movement.dash_boost_time
		machine.change_state(&"Run" if player.is_on_floor() else &"Air")

func _resolve_direction() -> Vector2:
	var move := player.input.move
	if player.is_on_floor():
		return Vector2(signf(move.x) if not is_zero_approx(move.x) else float(player.facing), 0.0)
	if player.is_on_wall() and player.wall_is_jumpable(player.get_wall_normal()):
		# Along the wall; neutral input climbs.
		return Vector2(0.0, signf(move.y) if not is_zero_approx(move.y) else -1.0)
	# Airborne: aim, else input, else facing (DESIGN 4.3).
	if player.input.aim.length() > 0.1:
		return player.input.aim.normalized()
	if move.length() > 0.1:
		return move.normalized()
	return Vector2(float(player.facing), 0.0)
