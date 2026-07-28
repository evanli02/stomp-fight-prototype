class_name VesperSleepDart extends Ability
## Vesper — Sleep Dart (docs/NEW_HEROES.md §Vesper).
##
## A projectile with Deadeye's bolt for a body — same size, same speed, dying on
## terrain the same way (both are `BoltProjectile`). On hit it applies a short
## movement slow and one sleep STACK. Stacks live on the victim for `stack_life`
## and share one timer, so a new stack resets the whole set; the third consumes
## them all and puts the target to SLEEP.
##
## Sleep is not a stun: the victim can still walk, at a crawl, with no momentum
## and nothing else. That sliver of agency is what makes watching the third dart
## come at you frightening rather than merely fatal — and their head hurtbox
## stays live the whole time, which is what the kit is actually buying.

## Faster than Deadeye's 620 (owner pass 2026-07-28): the dart is a needle and
## should fly like one. Same body and size as the bolt, just quicker.
@export var dart_speed: float = 780.0
@export var dart_slow_mult: float = 0.6
@export var dart_impair_mult: float = 0.65
@export var dart_slow_time: float = 2.0
@export var stack_life: float = 13.0         # 12-15 band; reset on a new stack
@export var stacks_to_sleep: int = 3
@export var sleep_time: float = 6.5          # 6-7 band

func _execute(aim: Vector2) -> void:
	var dart := SleepDart.new()
	dart.global_position = player.global_position
	dart.launch(player, aim_or_facing(aim), dart_speed)
	dart.slow_mult = dart_slow_mult
	dart.impair_mult = dart_impair_mult
	dart.slow_time = dart_slow_time
	dart.stack_life = stack_life
	dart.stacks_to_sleep = stacks_to_sleep
	dart.sleep_time = sleep_time
	player.spawn_effect(dart)
