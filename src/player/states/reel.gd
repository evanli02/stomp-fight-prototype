class_name ReelState extends PlayerState
## Sai pulling himself up the rope (DESIGN 5.2). Recasting the grapple while the
## hook is holding hands him here: a fast straight-line haul toward the anchor,
## and the other half of what a grappling hook is for. A swing repositions you
## along an arc; a reel repositions you along the rope.
##
## It stops SHORT of the anchor rather than at it. Hooks land on ceilings more
## often than anywhere else, and a reel that ran all the way to the anchor would
## drive him into the surface he is hanging from, ending the ability with a
## faceful of terrain every time. Arriving a body's length below the hook leaves
## him next to it with speed intact, which is the outcome worth having.
##
## Close range is the exception: inside CLOSE_ENOUGH the stop-short margin is
## most of the trip, so the pull would be a no-op. From there he goes to the
## anchor itself, which is where the "pull me onto that ledge" case lives.

## Fast enough to be an escape, slow enough to be seen and reacted to.
const REEL_SPEED: float = 1500.0
## How far short of the anchor the haul ends. A little past the 34px body, so he
## arrives clear of the surface rather than against it.
const STOP_SHORT: float = 40.0
## Below this the margin above would eat the whole trip, so it is dropped.
const CLOSE_ENOUGH: float = 56.0
## Arriving is a launch, not a stop: the haul's speed becomes momentum out of it,
## the way leaving a swing does.
const EXIT_KEEP: float = 0.55
## A hard ceiling on how long a haul can run, in case the target is unreachable
## and the body is grinding along a wall a pixel at a time.
const MAX_TIME: float = 0.9

var _target: Vector2 = Vector2.ZERO
var _direction: Vector2 = Vector2.ZERO
var _elapsed: float = 0.0

func enter(params: Dictionary = {}) -> void:
	var anchor: Vector2 = params.get("anchor", player.global_position)
	var gap := anchor - player.global_position
	var distance := gap.length()
	if distance < 1.0:
		machine.change_state(&"Air")
		return
	_direction = gap / distance
	_target = anchor if distance <= CLOSE_ENOUGH \
		else anchor - _direction * STOP_SHORT
	_elapsed = 0.0
	player.air_dash_locked = false

func physics_update(delta: float) -> void:
	_elapsed += delta
	var gap := _target - player.global_position
	# Velocity, not position: move_and_slide does the moving, so terrain in the
	# way stops the haul honestly instead of being tunnelled through. Clamped to
	# the remaining gap rather than run flat out, or the last frame overshoots by
	# most of a 25px step and eats a third of the stop-short margin.
	player.velocity = (gap / delta).limit_length(REEL_SPEED)

	# Arrived, overshot (the target passed behind him), stalled against
	# something, or simply out of time.
	var arrived: bool = gap.length() <= 2.0 or gap.dot(_direction) <= 0.0
	var stalled: bool = player.is_on_wall() or player.is_on_ceiling()
	if arrived or stalled or _elapsed >= MAX_TIME:
		player.velocity = _direction * REEL_SPEED * EXIT_KEEP
		machine.change_state(&"Air", {"anim": &"wall_jump"})
		return
	# Cutting the rope mid-haul is allowed, and keeps the speed built so far.
	if player.wants_crouch():
		machine.change_state(&"Air")

func animation() -> StringName: return &"dash"
