class_name CombatConfig extends Resource
## All combat feel tunables (DESIGN 3, 5.4). Edit in combat_config.tres.

@export_group("Stomp")
@export var stomp_stun_time: float = 0.6
@export var stomp_grace_time: float = 1.2       ## head hurtbox disabled
@export var stomp_victim_bounce: float = 260.0  ## impulse magnitude, direction from contact
@export var stomp_attacker_bounce: float = -420.0 ## upward, hold-extendable like a jump
## Below roughly 100 there is no daylight between falling onto a head and
## settling onto one: a body released at zero height is already doing 47 after
## two physics frames, which would make standing on shoulders (DESIGN 3.4)
## impossible without stomping.
@export var stomp_min_relative_fall_speed: float = 120.0
## How long a fall's downward speed stays eligible to register as a stomp after
## a collision has already zeroed it. Bodies stop on contact one frame before
## the feet/head areas report their overlap, so without this the speed that
## earned the stomp is gone by the time the check runs (DESIGN 3.1).
@export var stomp_fall_memory_time: float = 0.12

@export_group("Stun table (DESIGN 5.4)")
@export var stun_duel_loss: float = 0.3
@export var stun_deadeye_bolt: float = 0.8
@export var stun_line: float = 0.4
@export var stun_explosion: float = 0.5
@export var stun_nova_ult: float = 1.0
@export var stun_mason_ult_block: float = 0.5

@export_group("Spawn")
@export var spawn_protection_time: float = 2.0  ## or until first action
