class_name FrostbitePulses extends Node2D
## Siku's ultimate sequencer: fires a fixed number of ice rings, spaced out,
## each centred on the CASTING PLAYER'S CURRENT BODY rather than on where the
## ult was cast. The storm follows her — and because it tracks the player rather
## than the hero, it keeps firing from whoever that player is driving after a
## swap, which is the right owner for an ultimate.
##
## One node owns the schedule instead of a web of timers on the ability, because
## the ability node is freed the moment its hero is swapped out and cannot be
## the thing remembering. The rings themselves are ordinary ShockwaveRings —
## Cerebelle's ult object, reused rather than forked.

var caster: Player
var pulses_left: int = 5
var gap: float = 3.5
var pulse_speed: float = 520.0
var reach: float = 1800.0
var stun_time: float = 1.5
var accent: Color = Color(0.62, 0.87, 1.0)

var _until_next: float = 0.0

func begin(from: Player, count: int, interval: float, speed: float,
		ring_reach: float, stun: float) -> void:
	caster = from
	pulses_left = count
	gap = interval
	pulse_speed = speed
	reach = ring_reach
	stun_time = stun
	if from.hero != null:
		accent = from.hero.accent_color
	_until_next = 0.0   # the first pulse goes out immediately

func _physics_process(delta: float) -> void:
	if caster == null or not is_instance_valid(caster) or pulses_left <= 0:
		queue_free()
		return
	_until_next -= delta
	if _until_next > 0.0:
		return
	_until_next = gap
	pulses_left -= 1
	var ring := ShockwaveRing.new()
	get_parent().add_child(ring)
	# launch() takes the colour off the caster's hero itself, so the rings stay
	# whoever-is-currently-equipped's colour rather than a stale copy.
	ring.launch(caster, pulse_speed, reach, stun_time)
	# ShockwaveRing already strips momentum and drops whoever it catches, and
	# already hits each enemy only once — per ring, which is what makes the next
	# pulse a fresh threat.
