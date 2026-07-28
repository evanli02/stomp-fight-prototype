class_name VesperDeepSleep extends Ability
## Vesper's ultimate — Deep Sleep (docs/NEW_HEROES.md §Vesper). SKELETON.
##
## A huge, slow sphere that drifts along the aim and passes through EVERYTHING
## — walls, floors, platforms, allies, enemies. Nothing stops it; it just
## eventually leaves the stage. Faster than Cerebelle's Supernova ring (so it
## is a threat you dodge, not a wall you outrun) but far below any projectile.
##
## An enemy the sphere touches drops out of the air — velocity zeroed, momentum
## stripped, exactly the Supernova drop — and goes straight to SLEEP, no stacks
## needed, for ULT_SLEEP_MULT times the ability's sleep window. Each enemy is
## hit once per cast.

@export var sphere_radius: float = 96.0
## Above Supernova's 250, far below every real projectile.
@export var sphere_speed: float = 340.0
@export var range: float = 2400.0            # crosses any stage, then dies
## The ult sleep is ~1.5x the dart sleep (6.5 -> ~9.75).
@export var ult_sleep_mult: float = 1.5

func _execute(_aim: Vector2) -> void:
	# TODO(opus): implement per docs/NEW_HEROES.md §Vesper —
	#  1. A DreamSphere effect: Node2D, physics-tick travel, NO terrain
	#     raycast (it pierces by design), per-enemy once-per-cast hit set,
	#     distance-based hit test (position within sphere_radius).
	#  2. On hit: set_velocity_override(Vector2.ZERO), momentum_charge = 0,
	#     then apply_sleep(dart sleep_time * ult_sleep_mult).
	#  3. Draw: big translucent sphere, black core, neon pink rim — menacing
	#     but soft; it is sleep, not fire.
	push_warning("Deep Sleep is a skeleton — see docs/NEW_HEROES.md")
