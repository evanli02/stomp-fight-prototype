class_name VesperSleepDart extends Ability
## Vesper — Sleep Dart (docs/NEW_HEROES.md §Vesper). SKELETON.
##
## A projectile with Deadeye's bolt for a body — same size, same speed, dies on
## terrain the same way. On hit it applies two things to the enemy:
##  - a short movement slow (apply_slow + apply_impairment, DART_SLOW_TIME), and
##  - one sleep STACK. Stacks live on the victim for STACK_LIFE, and adding a
##    stack resets the timer on ALL of them. The third stack consumes every
##    stack and puts the victim to SLEEP (see below).
##
## Sleep is the new debuff: the victim can only walk left and right at a hard
## speed cap, builds no momentum while walking, and cannot jump, dash, wall
## jump, slide, swap, or use ability/ultimate for the window. It is NOT a stun:
## they keep a sliver of agency, which is what makes watching the third dart
## come at you scary rather than merely fatal. Head hurtbox stays live — a
## sleeping player is the most stompable player in the game.
##
## Visual contract: a victim shows one pip per stack over their head (the
## debuff-marks row), and a sleeping victim is unmistakable (z's + desaturate).

@export var dart_speed: float = 620.0        # Deadeye's bolt speed exactly
@export var dart_slow_mult: float = 0.6
@export var dart_impair_mult: float = 0.65
@export var dart_slow_time: float = 2.0
@export var stack_life: float = 13.0         # 12-15 band; reset on new stack
@export var stacks_to_sleep: int = 3
@export var sleep_time: float = 6.5          # 6-7 band
## While asleep: walk speed as a fraction of run_speed_base, momentum locked.
@export var sleep_walk_mult: float = 0.35

func _execute(_aim: Vector2) -> void:
	# TODO(opus): implement per docs/NEW_HEROES.md §Vesper —
	#  1. A SleepDart effect cloned from StunBolt's shape (Area2D, raycast
	#     terrain death, first-enemy hit) in Vesper's colours.
	#  2. On hit: apply_slow/apply_impairment (tag &"dart"), then
	#     victim.add_sleep_stack(stack_life) [new API: increments, resets the
	#     shared timer; at stacks_to_sleep, clears stacks and calls
	#     apply_sleep(sleep_time)].
	#  3. apply_sleep [new API + a Sleeping movement state: walk-only at
	#     sleep_walk_mult of base, zero momentum build, everything else
	#     refused; swap blocked; head hurtbox LIVE; cleansable].
	push_warning("Sleep Dart is a skeleton — see docs/NEW_HEROES.md")
