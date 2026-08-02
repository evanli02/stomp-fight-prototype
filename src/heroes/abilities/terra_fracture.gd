class_name TerraFracture extends Ability
## Terra's ultimate (DESIGN 5.2): the fracture wave. An instantaneous, very wide
## wall of force along the aim that stops at the first terrain it meets — every
## enemy in the corridor is stunned, hurled against that surface, and left
## slowed with jump and dash gutted for a long beat. The old version was a slab
## that travelled and dragged; the rework trades the travel for width and
## immediacy.

## Half-width of the corridor: 2x Kid's cannon, because this is the ultimate
## version of that shape. Dodging it should mean not being in the half of the
## stage it crossed.
@export var half_width: float = 90.0
## How hard the caught are thrown at the surface the wave stopped on.
@export var push_speed: float = 2600.0
## Speed-cap multiplier left on the victims, and for how long.
@export var slow_mult: float = 0.805
@export var slow_time: float = 11.0
## Jump and dash are gutted outright (0x) for this long.
@export var impair_time: float = 8.5
## The stun itself lives in the shared table (combat_config.stun_terra_ult), so
## it is tuned alongside every other stun rather than in isolation.

func _execute(aim: Vector2) -> void:
	var wave := FractureWave.new()
	wave.half_width = half_width
	wave.push_speed = push_speed
	wave.slow_mult = slow_mult
	wave.slow_time = slow_time
	wave.impair_time = impair_time
	player.spawn_effect(wave)
	wave.launch(player, aim_or_facing(aim))
