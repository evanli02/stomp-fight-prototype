class_name DummyDriver extends RefCounted
## A scripted stand-in for a device, for the training room's practice dummies.
##
## Deliberately dumb: walk one way for `leg_time`, walk the other way, repeat.
## A dummy that dodged would make it impossible to tell whether a kit missed
## because the numbers are wrong or because the dummy moved — the point of a
## practice target is that it is predictable, so anything surprising is the
## thing being tested.
##
## It also turns around at walls, because a dummy grinding into a corner for the
## rest of the session is not a target either.
##
## Plugs into `Player.input_source` (a Callable taking the body, returning an
## InputFrame), which is the same seam a rollback layer would use to replay
## received input — nothing downstream can tell this from a device.

enum Mode {
	IDLE,      ## stand still: the baseline for measuring anything
	PATROL,    ## walk back and forth
	HOP,       ## patrol, and jump on a fixed cadence
}

## Seconds per leg of the patrol.
const LEG_TIME: float = 1.6
## How long a jump is held, for the HOP mode's fixed-height hop.
const HOP_HOLD: float = 0.12
const HOP_PERIOD: float = 1.1

var mode: Mode = Mode.PATROL
## Staggered per dummy so a row of them does not move as one block, which reads
## as a single wide object rather than as several targets.
var phase: float = 0.0

var _elapsed: float = 0.0
var _frame: InputFrame = InputFrame.new()

func poll(body: Player) -> InputFrame:
	_elapsed += 1.0 / 60.0     # physics tick; the driver is only ever called there
	var t := _elapsed + phase

	_frame.move = Vector2.ZERO
	_frame.jump_pressed = false
	_frame.jump_held = false
	_frame.dash_pressed = false
	_frame.ability_pressed = false
	_frame.swap_pressed = false
	_frame.ultimate_pressed = false
	# Aim is always live on a real player and some code reads it; give the dummy
	# a sane forward aim rather than a zero vector.
	_frame.aim = Vector2(float(body.facing), 0.0)

	if mode == Mode.IDLE:
		return _frame

	# Square wave: +1 for a leg, -1 for the next.
	var leg := int(floor(t / LEG_TIME))
	var direction := 1.0 if leg % 2 == 0 else -1.0
	# Walls flip it early, so a dummy never grinds into a corner. Reading the
	# body's own contact rather than tracking positions means this works on any
	# stage without the driver knowing anything about the layout.
	if body.is_on_wall():
		direction = -signf(body.get_wall_normal().x) if not is_zero_approx(
			body.get_wall_normal().x) else direction
	_frame.move.x = direction

	if mode == Mode.HOP and fmod(t, HOP_PERIOD) < HOP_HOLD:
		_frame.jump_pressed = fmod(t, HOP_PERIOD) < (1.0 / 60.0) + 0.001
		_frame.jump_held = true
	return _frame

func label() -> String:
	match mode:
		Mode.IDLE: return "idle"
		Mode.HOP: return "hopping"
		_: return "patrolling"

## Step to the next mode. GDScript enums are plain ints, so this is arithmetic
## rather than a cast.
func cycle() -> void:
	mode = (mode + 1) % Mode.size()
