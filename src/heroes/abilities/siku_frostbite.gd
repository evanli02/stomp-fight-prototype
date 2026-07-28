class_name SikuFrostbite extends Ability
## Siku's ultimate — Frostbite (docs/NEW_HEROES.md §Siku). SKELETON.
##
## Six expanding pulses from Siku's position, one every PULSE_GAP seconds, each
## a Supernova-shaped ring travelling much faster than Cerebelle's. An enemy a
## ring catches is stunned for STUN_TIME and dropped — velocity zeroed,
## momentum stripped, the Supernova drop. Each ring hits each enemy once, but
## the NEXT ring is a fresh threat: staying near Siku for the whole window
## means eating pulse after pulse.
##
## The rings launch from where Siku is when each one fires, not where the ult
## was cast — the storm follows her. Sequencing lives on an effect node, not a
## timer web on the ability: one FrostbitePulses node owns the schedule and
## dies with the round.

@export var pulse_count: int = 6
## 3-4s band between pulses.
@export var pulse_gap: float = 3.5
## Significantly faster than Supernova's 250 — dodging is jumping the wave,
## not walking away from it.
@export var pulse_speed: float = 520.0
@export var pulse_reach: float = 1800.0
@export var stun_time: float = 1.5

func _execute(_aim: Vector2) -> void:
	# TODO(opus): implement per docs/NEW_HEROES.md §Siku —
	#  1. A FrostbitePulses effect node: physics-tick schedule, fires
	#     pulse_count rings pulse_gap apart, each an ice-blue ShockwaveRing
	#     (launch() already takes speed/reach/stun — reuse it, do not fork it)
	#     centred on Siku's CURRENT body.
	#  2. Rings stun stun_time + strip momentum; ShockwaveRing already does
	#     both. Survives Siku swapping out (effects are stage-parented);
	#     remaining pulses keep firing from the body her player is driving —
	#     the storm belongs to the player, not the skin.
	push_warning("Frostbite is a skeleton — see docs/NEW_HEROES.md")
