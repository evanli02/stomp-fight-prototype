class_name VesperDeepSleep extends Ability
## Vesper's ultimate — Deep Sleep (docs/NEW_HEROES.md §Vesper).
##
## A huge, slow sphere that drifts along the aim and passes through everything:
## walls, floors, platforms, allies, enemies. Faster than Cerebelle's Supernova
## ring — so it is a threat you dodge rather than a wall you outrun — and far
## below any real projectile.
##
## Enemies it touches drop out of the air and sleep for 1.5× the dart's window,
## with no stacks needed.

@export var sphere_radius: float = 96.0
## Above Supernova's 250, far below every real projectile.
@export var sphere_speed: float = 340.0
@export var travel_range: float = 2400.0     ## crosses any stage, then dies
## The ult's sleep is half again as long as the dart's, read off the equipped
## dart so the two can never drift apart.
@export var ult_sleep_mult: float = 1.5
## Used only if the basic ability is missing (debug scenes with no full kit).
@export var fallback_sleep_time: float = 6.5

func _execute(aim: Vector2) -> void:
	var sphere := DreamSphere.new()
	sphere.radius = sphere_radius
	sphere.speed = sphere_speed
	sphere.range = travel_range
	sphere.sleep_time = _dart_sleep_time() * ult_sleep_mult
	sphere.launch(player, aim_or_facing(aim))
	player.spawn_effect(sphere)

func _dart_sleep_time() -> float:
	var basic := player.equipped_ability() as VesperSleepDart
	return basic.sleep_time if basic != null else fallback_sleep_time
