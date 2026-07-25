class_name Player extends CharacterBody2D
## One instance per PLAYER (not per hero). Hero swaps re-skin and re-equip this
## body in place — position, velocity, and stun persist across swaps (DESIGN 2.4).
## Movement logic lives in the StateMachine child; abilities and terrain interact
## with this class ONLY through the public API section below (IMPLEMENTATION.md 3).

signal stomped(attacker: Player)
signal stun_applied(duration: float)

@export var player_id: int = 0
@export var team_id: int = 0
@export var movement: MovementConfig
@export var combat: CombatConfig

var momentum_charge: float = 0.0        ## 0..1, scales run cap (DESIGN 4.1)
var dash_charges_left: int = 2
var air_dash_locked: bool = false       ## set after airborne dash, cleared on surface touch
var stun_remaining: float = 0.0
var grace_remaining: float = 0.0
var active_hero: StringName = &""

@onready var state_machine: Node = %StateMachine
@onready var head_hurtbox: Area2D = %HeadHurtbox
@onready var stomp_box: Area2D = %StompBox
@onready var ability_slot: Node = %AbilitySlot

#region Public API — the ONLY surface abilities/terrain may use
func apply_impulse(v: Vector2) -> void:
	velocity += v

func set_velocity_override(v: Vector2) -> void:
	## Springs, portals, grapples: replaces velocity outright.
	velocity = v

func apply_stun(duration: float) -> void:
	## Refresh rule: max(remaining, new). Never additive (CLAUDE.md checklist).
	stun_remaining = maxf(stun_remaining, duration)
	stun_applied.emit(duration)
	# TODO(M2): force StateMachine into Stunned

func request_state(state_name: StringName, params: Dictionary = {}) -> void:
	# TODO(M1): forward to state machine (used by e.g. Skyla's double jump)
	pass

func grant_speed_buff(mult: float, dur: float) -> void:
	pass # TODO(M4)

func set_head_hurtbox_enabled(on: bool) -> void:
	## Grace period and Wisp ult ONLY. Body collision stays on — players remain
	## terrain to each other even while graced (CLAUDE.md checklist).
	head_hurtbox.monitorable = on
#endregion

#region Stomp resolution — victim-authoritative (IMPLEMENTATION.md 5)
func receive_stomp(attacker: Player) -> void:
	if grace_remaining > 0.0:
		return
	MatchState.lose_life(player_id, active_hero)
	apply_stun(combat.stomp_stun_time)
	grace_remaining = combat.stomp_grace_time
	set_head_hurtbox_enabled(false)
	# Directional bounce from contact point; momentum is KEPT (DESIGN 3.2).
	var dir := (global_position - attacker.global_position).normalized()
	apply_impulse(dir * combat.stomp_victim_bounce)
	stomped.emit(attacker)
	attacker.on_stomp_landed()

func on_stomp_landed() -> void:
	## Attacker bounce — roughly a jump, hold-extendable (DESIGN 3.2).
	velocity.y = combat.stomp_attacker_bounce
	# TODO(M2): route through Air state so hold-extension applies
#endregion

func _physics_process(delta: float) -> void:
	if grace_remaining > 0.0:
		grace_remaining -= delta
		if grace_remaining <= 0.0:
			set_head_hurtbox_enabled(true)
	# TODO(M1): delegate to state machine; apply gravity/moves; move_and_slide()

## Shared perfect-timing check backing BOTH b-hop and perfect wall jump
## (DESIGN 4.2 / 4.4 — implement once, reuse; CLAUDE.md checklist).
func perfect_window_check(time_since_contact: float, window: float) -> bool:
	return time_since_contact <= window
