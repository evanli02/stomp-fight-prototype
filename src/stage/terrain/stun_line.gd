class_name StunLine extends TerrainElement
## Glowing tripwire (DESIGN 6.2): touching it stuns, momentum is kept, and the
## head hurtbox stays ACTIVE. That last part is the whole point — a stun line is
## the classic stomp setup, not a safe zone.
##
## Optionally on a duty cycle, which is what makes a laser *grid* (DESIGN 6.3,
## Cryo Lab) rather than a set of walls: a timed line is a rhythm to move
## through, and phase offsets between lines turn a grid into a pattern you learn.
## Always-on is still the default, because a line you have to time is a much
## stronger tool and not every stage wants one.

@export var retrigger: float = 0.8
## Seconds for one off->on->off cycle. Zero or less means always on.
@export var cycle_time: float = 0.0
## Share of the cycle the line is live for.
@export var on_ratio: float = 0.5
## Offset into the cycle at spawn, 0..1. Lines in one grid stagger with this.
@export var phase_offset: float = 0.0
## Lead-in before the line goes live, drawn as a thin warning beam. A laser that
## appears on top of you is a coin flip; one that announces itself is a timing
## problem, which is the interesting version.
@export var warn_time: float = 0.35

var _cooldown: Dictionary = {}
## Cycle clock. Driven by delta, never by wall time — gameplay stays
## deterministic (IMPLEMENTATION.md 9).
var _clock: float = 0.0

func _ready() -> void:
	_clock = phase_offset * maxf(cycle_time, 0.0)
	super()

## Whether the line stuns right now.
func is_live() -> bool:
	if cycle_time <= 0.0:
		return true
	return _clock < cycle_time * on_ratio

## Whether the line is in its lead-in and about to go live.
func is_warning() -> bool:
	if cycle_time <= 0.0:
		return false
	return not is_live() and _clock >= cycle_time - warn_time

func tick(delta: float) -> void:
	if cycle_time > 0.0:
		_clock = fmod(_clock + delta, cycle_time)
	for id in _cooldown.keys():
		_cooldown[id] -= delta
		if _cooldown[id] <= 0.0:
			_cooldown.erase(id)
	queue_redraw()

## Stun from the per-tick pass rather than from entry: a timed line has to catch
## the body that walked in while it was dark and is still standing there when it
## comes on. For an always-on line this fires on the same tick entry would have,
## so nothing changes for the stages that use one.
func physics_effect(p: Player, _delta: float) -> void:
	if not is_live():
		return
	var id := p.get_instance_id()
	if _cooldown.has(id):
		return
	_cooldown[id] = retrigger
	# Stun only. Never a life, never knockback (CLAUDE.md 1).
	p.apply_stun(p.combat.stun_line)

func _draw() -> void:
	var half := size * 0.5
	if is_live():
		var pulse: float = 0.6 + 0.4 * sin(_beat() * 6.0)
		draw_rect(Rect2(-half, size), Color(1.0, 0.82, 0.25, 0.22 * pulse))
		draw_rect(Rect2(Vector2(-half.x, -1), Vector2(size.x, 2)),
			Color(1.0, 0.82, 0.25, pulse))
		for i in int(size.x / 8.0):
			draw_rect(Rect2(-half + Vector2(i * 8, -3), Vector2(2, 6)),
				Color(1.0, 0.95, 0.69, pulse))
		return
	# Dark: emitters only, so the line's position is still readable when it is
	# safe to cross. A hazard you cannot see coming back is a memory test.
	var warn: float = 1.0 if is_warning() else 0.0
	var flick: float = 0.35 + 0.5 * warn * absf(sin(_beat() * 22.0))
	draw_rect(Rect2(Vector2(-half.x, -1), Vector2(size.x, 2)),
		Color(1.0, 0.82, 0.25, 0.10 + 0.35 * warn))
	for i in [0, int(size.x / 8.0) - 1]:
		draw_rect(Rect2(-half + Vector2(i * 8, -3), Vector2(2, 6)),
			Color(1.0, 0.95, 0.69, flick))

func _beat() -> float:
	# Timed lines animate off their own clock so the flicker lines up with the
	# cycle; always-on ones have no clock and fall back to render time.
	return _clock if cycle_time > 0.0 else float(Time.get_ticks_msec()) * 0.001
