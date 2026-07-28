class_name DeadeyeBolt extends Ability
## Deadeye — aim and fire a stun bolt (DESIGN 5.2 #1). On hit the enemy is
## stunned for combat.stun_deadeye_bolt. No knockback, no life: the value is
## that a stunned player is a stompable player, which is the whole setup game.

@export var bolt_speed: float = 620.0

## Set by the ultimate: the next bolt only, fired faster and with a longer stun.
var _empowered_speed_mult: float = 1.0
var _empowered_stun: float = 0.0

func load_empowered_shot(speed_mult: float, stun: float) -> void:
	_empowered_speed_mult = speed_mult
	_empowered_stun = stun

func _execute(aim: Vector2) -> void:
	var stun := _empowered_stun if _empowered_stun > 0.0 else player.combat.stun_deadeye_bolt
	var speed := bolt_speed * _empowered_speed_mult
	var bolt := StunBolt.new()
	bolt.global_position = player.global_position
	bolt.launch(player, aim_or_facing(aim), speed)
	bolt.stun_time = stun
	bolt.empowered = _empowered_stun > 0.0
	# The loaded shot ignores terrain: nowhere on the stage is cover from it.
	bolt.piercing = bolt.empowered
	player.spawn_effect(bolt)
	_empowered_speed_mult = 1.0
	_empowered_stun = 0.0
