class_name SikuPillar extends Ability
## Siku — Pillar (docs/NEW_HEROES.md §Siku). SKELETON.
##
## Ground only. A solid ice pillar builds very fast under Siku, bottom-up:
## roughly 3 character widths wide and 3 character heights tall (PILLAR_SIZE),
## its top surface icy (apply_surface_slip, like the Ice element), persisting
## for PILLAR_LIFE and then melting. Everyone standing in its footprint when it
## fires — Siku, allies, enemies alike; terrain does not take sides — is
## launched up a medium distance, KEEPING their horizontal velocity (the launch
## replaces velocity.y only, exactly a JumpSpring, including the
## request_state(&"Air") that stops a grounded state erasing it).
##
## The headroom gate is the anti-stuck rule and it is part of _can_fire, not a
## patch: the cast is REFUSED (nothing spent) unless there is clear space above
## the footprint for the pillar PLUS a standing body. Refusing beats clamping —
## a half-height pillar would be a different ability every low ceiling.

## 3 body-widths x 3 body-heights (22x34 body -> 66x102, snapped to the grid).
@export var pillar_size: Vector2 = Vector2(64.0, 96.0)
@export var pillar_life: float = 5.0
## The launch: replace velocity.y, keep velocity.x. A medium distance — above a
## held jump's apex, below a stage spring.
@export var launch_velocity: float = -640.0
## Clearance above the ground the pillar needs: its height + a standing body.
@export var required_headroom: float = 140.0

func _can_fire() -> bool:
	# TODO(opus): ground check + headroom check per docs/NEW_HEROES.md §Siku:
	#  refuse unless player.is_on_floor(), and refuse unless a shape query
	#  (pillar footprint x required_headroom, upward from the ground under
	#  Siku) finds no terrain. Refused = nothing spent (base class behaviour).
	return player.is_on_floor()

func _execute(_aim: Vector2) -> void:
	# TODO(opus): implement per docs/NEW_HEROES.md §Siku —
	#  1. An IcePillar effect: StaticBody2D core (layer 1) + icy top via the
	#     Ice element's slip rule, built bottom-up over ~4 frames (visual;
	#     collision can arrive complete), melting out after pillar_life.
	#  2. Launch every body overlapping the footprint at cast: velocity.y
	#     replaced with launch_velocity, velocity.x untouched,
	#     request_state(&"Air") — the JumpSpring recipe, Siku included.
	#  3. Melt = shrink + free; bodies standing on top just fall (never
	#     teleported — see the depenetration trap in handoff.md).
	push_warning("Pillar is a skeleton — see docs/NEW_HEROES.md")
