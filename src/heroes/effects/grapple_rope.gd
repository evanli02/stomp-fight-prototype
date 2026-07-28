class_name GrappleRope extends Node2D
## Sai's hook and the rope behind it, from the throw to the moment he lets go.
##
## One node owns the whole lifecycle rather than a projectile handing off to a
## rope, because the two can never disagree that way: the head is wherever this
## node says it is, and the rope is always drawn to it.
##
## Three phases:
##   FLYING   the head travels along the aim, rope trailing behind it
##   ANCHORED the head has bitten; Sai swings or reels, rope taut
##   RETRACT  a miss (or a bite he could not act on) — the head comes home
##
## The throw is instant in the fiction but not on screen. Before this, the hook
## resolved by raycast and the swing began the same frame, so nothing about the
## ability was ever visible except a rope that appeared already taut. The anchor
## is still chosen by that same raycast at cast time — a hook that re-resolves
## mid-flight could bite something that walked into the way, and where the swing
## goes should be decided by where you aimed.

enum Phase { FLYING, ANCHORED, RETRACT }

## Fast enough that the flight is a beat rather than a wind-up. Range is now
## effectively unlimited, so the head has to move: a cross-stage throw at this
## speed still lands in under a fifth of a second.
const HOOK_SPEED: float = 5400.0
const RETRACT_SPEED: float = 3600.0
## States the rope stays attached through. Recasting mid-swing hands Sai to Reel,
## and the rope has to survive that or the ability visibly breaks halfway.
const HOLDING_STATES: Array[StringName] = [&"Swing", &"Reel"]

var owner_player: Player
## Where the hook bites, or the far end of a miss.
var anchor: Vector2 = Vector2.ZERO
## False when the raycast found nothing: the head still flies, then comes back.
var bites: bool = true
var accent: Color = Color(1, 0.43, 0.78)

var _phase: Phase = Phase.FLYING
var _head: Vector2 = Vector2.ZERO
var _origin: Vector2 = Vector2.ZERO

func _ready() -> void:
	if owner_player != null:
		_origin = owner_player.global_position
		_head = _origin
	z_index = 5

## Biting and still holding him — the condition the ability reads to decide
## whether a press is a new throw or a reel.
func is_attached() -> bool:
	return _phase == Phase.ANCHORED

## On the physics tick, not the render tick: arriving is what starts the swing,
## and a state change owes the rest of the frame the same clock everything else
## is on (CLAUDE.md: no gameplay logic in _process).
func _physics_process(delta: float) -> void:
	if owner_player == null or not is_instance_valid(owner_player):
		queue_free()
		return
	match _phase:
		Phase.FLYING:
			_fly(delta)
		Phase.ANCHORED:
			if not HOLDING_STATES.has(owner_player.state_machine.state_name()):
				_phase = Phase.RETRACT
		Phase.RETRACT:
			_retract(delta)
	queue_redraw()

func _fly(delta: float) -> void:
	var gap := anchor - _head
	if gap.length() > HOOK_SPEED * delta:
		_head += gap.normalized() * HOOK_SPEED * delta
		return
	_head = anchor
	# A hook that bit while Sai was stunned, frozen or already busy elsewhere
	# does not get to yank him: the throw is spent, the swing is not owed.
	if not bites or not owner_player.can_act():
		_phase = Phase.RETRACT
		return
	_phase = Phase.ANCHORED
	owner_player.request_state(&"Swing", {"anchor": anchor})

func _retract(delta: float) -> void:
	var gap := owner_player.global_position - _head
	if gap.length() <= RETRACT_SPEED * delta:
		queue_free()
		return
	_head += gap.normalized() * RETRACT_SPEED * delta

func _draw() -> void:
	if owner_player == null or not is_instance_valid(owner_player):
		return
	var from := to_local(_head)
	var to := to_local(owner_player.global_position)
	draw_line(from, to, Color(0.05, 0.03, 0.09), 3.0)
	draw_line(from, to, accent, 1.5)
	_draw_head(from, (from - to).normalized())

## The claw itself: two barbs off a short shank, pointing the way it is going.
## It reads as a thrown object at 32px sprites where a dot would read as a spark.
func _draw_head(at: Vector2, dir: Vector2) -> void:
	if dir.length() < 0.5:
		dir = Vector2.UP
	var side := dir.orthogonal()
	var outline := Color(0.05, 0.03, 0.09)
	var tip := at + dir * 3.0
	for s: float in [-1.0, 1.0]:
		var barb := at + side * s * 4.0 - dir * 3.0
		draw_line(tip, barb, outline, 3.5)
		draw_line(tip, barb, accent, 2.0)
	draw_circle(at, 3.0, outline)
	draw_circle(at, 2.0, Color.WHITE if _phase == Phase.ANCHORED else accent)
