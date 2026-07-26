class_name RecallState extends PlayerState
## Slip's rewind (DESIGN 5.2): retrace the exact path travelled since the anchor
## was placed, at very high speed, back to where it was dropped.
##
## The path is replayed rather than teleported through so the rewind is visible
## and chaseable — Tracer, not a blink. It follows positions that were valid
## when the player was actually there, so it cannot tunnel anywhere the player
## could not have gone.

const RETRACE_SPEED: float = 2400.0

var _path: Array = []          ## breadcrumbs, oldest (anchor) first
var _index: int = 0            ## walked from the END back to 0

func enter(params: Dictionary = {}) -> void:
	_path = params.get("path", [])
	_index = _path.size() - 1
	player.air_dash_locked = false

func physics_update(delta: float) -> void:
	var budget := RETRACE_SPEED * delta
	while budget > 0.0 and _index >= 0:
		var target: Vector2 = _path[_index]
		var gap := target - player.global_position
		if gap.length() <= budget:
			budget -= gap.length()
			player.global_position = target
			_index -= 1
		else:
			# Velocity, not position, covers the partial step: move_and_slide
			# does the moving, so a stray wall still stops the rewind honestly.
			player.velocity = gap.normalized() * RETRACE_SPEED
			return
	if _index < 0:
		player.velocity = Vector2.ZERO
		machine.change_state(&"Air")

func animation() -> StringName: return &"dash"
