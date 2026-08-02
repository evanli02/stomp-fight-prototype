class_name KidEmp extends Ability
## Kid's ultimate (DESIGN 5.2): the EMP. A telegraphed beat of charge-up, then
## every enemy on the stage is slowed and locked out of dash, ability, and
## ultimate for the window. It touches no one's position and no one's lives —
## it just turns the tech off.

## Telegraph before it lands — the counterplay, and the reason an ult spent
## into an EMP-locked scramble is an ult wasted.
@export var delay: float = 0.6
## Speed-cap multiplier on every enemy for the window.
@export var slow_mult: float = 0.35
## How long the slow AND the dash/ability/ultimate lockout run.
@export var duration: float = 14.0

func _execute(_aim: Vector2) -> void:
	var wave := EmpWave.new()
	wave.delay = delay
	wave.slow_mult = slow_mult
	wave.duration = duration
	player.spawn_effect(wave)
	wave.charge(player)
