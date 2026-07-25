class_name Player extends CharacterBody2D
## One instance per PLAYER (not per hero). Hero swaps re-skin and re-equip this
## body in place — position, velocity, and stun persist across swaps (DESIGN 2.4).
## Movement logic lives in the StateMachine child; abilities and terrain interact
## with this class ONLY through the public API section below (IMPLEMENTATION.md 3).

signal stomped(attacker: Player)
signal stun_applied(duration: float)
## Emitted when a perfect-timing window is converted (&"bhop" / &"walljump").
## Feeds the playground debug overlay now, VFX later.
signal perfect_window_hit(kind: StringName)

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

#region Movement bookkeeping — owned here, read by states
## Timers and contact facts live on the player rather than in any one state so
## that b-hop and perfect wall jump can share them across transitions.
var input: InputFrame = InputFrame.new()
var facing: int = 1
var time_since_landing: float = INF
var time_since_wall_contact: float = INF
var wall_normal: Vector2 = Vector2.ZERO
var wall_jump_chain: int = 0            ## consecutive wall jumps without touching ground
var coyote_remaining: float = 0.0
var jump_buffer_remaining: float = 0.0
var dash_recharge_remaining: float = 0.0
var dash_boost_remaining: float = 0.0
## False during the b-hop window after a landing: momentum is still intact and a
## jump in this window keeps 100% of it (DESIGN 4.2).
var landing_settled: bool = true
var _was_on_wall: bool = false
#endregion

@onready var state_machine: StateMachine = %StateMachine
@onready var head_hurtbox: Area2D = %HeadHurtbox
@onready var stomp_box: Area2D = %StompBox
@onready var ability_slot: Node = %AbilitySlot

func _ready() -> void:
	dash_charges_left = movement.dash_charges
	state_machine.setup(self)

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
	if state_machine != null and state_machine.state_name() != &"Stunned":
		state_machine.change_state(&"Stunned")

func request_state(state_name: StringName, params: Dictionary = {}) -> void:
	## Abilities ask for a state (e.g. Skyla's double jump requests Air); they
	## never reach into state internals.
	state_machine.change_state(state_name, params)

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
	input = InputConfig.poll(player_id, self)
	_tick_timers(delta)
	state_machine.tick(delta)
	var was_on_floor := is_on_floor()
	move_and_slide()
	_post_move(was_on_floor)

func _tick_timers(delta: float) -> void:
	if grace_remaining > 0.0:
		grace_remaining -= delta
		if grace_remaining <= 0.0:
			set_head_hurtbox_enabled(true)
	if stun_remaining > 0.0:
		stun_remaining -= delta
	if not is_zero_approx(input.move.x) and stun_remaining <= 0.0:
		facing = signi(input.move.x)

	time_since_landing += delta
	time_since_wall_contact += delta
	coyote_remaining = maxf(coyote_remaining - delta, 0.0)
	dash_boost_remaining = maxf(dash_boost_remaining - delta, 0.0)

	if input.jump_pressed:
		jump_buffer_remaining = movement.jump_buffer_time
	else:
		jump_buffer_remaining = maxf(jump_buffer_remaining - delta, 0.0)

	# One charge recharges at a time (DESIGN 4.3).
	if dash_charges_left < movement.dash_charges:
		dash_recharge_remaining -= delta
		if dash_recharge_remaining <= 0.0:
			dash_charges_left += 1
			dash_recharge_remaining = movement.dash_recharge if dash_charges_left < movement.dash_charges else 0.0

	# The b-hop window has passed without a jump: a normal landing costs momentum.
	if not landing_settled and is_on_floor() and time_since_landing > movement.bhop_window:
		_settle_landing()

func _post_move(was_on_floor: bool) -> void:
	if is_on_floor():
		if not was_on_floor:
			_on_landed()
		coyote_remaining = movement.coyote_time
		air_dash_locked = false
		wall_jump_chain = 0

	var on_jumpable_wall := is_on_wall() and wall_is_jumpable(get_wall_normal())
	if on_jumpable_wall:
		wall_normal = get_wall_normal()
		if not _was_on_wall:
			time_since_wall_contact = 0.0  # opens the perfect wall-jump window
		air_dash_locked = false
	_was_on_wall = on_jumpable_wall

	# Ceilings are never wall-jumpable but do reset the air dash (DESIGN 4.4).
	if is_on_ceiling():
		air_dash_locked = false

func _on_landed() -> void:
	time_since_landing = 0.0
	landing_settled = false

func _settle_landing() -> void:
	momentum_charge *= movement.momentum_keep_on_landing
	velocity.x = clampf(velocity.x, -speed_cap(), speed_cap())
	landing_settled = true

#region Movement helpers shared by states
## Shared perfect-timing check backing BOTH b-hop and perfect wall jump
## (DESIGN 4.2 / 4.4 — implement once, reuse; CLAUDE.md checklist).
func perfect_window_check(time_since_contact: float, window: float) -> bool:
	return time_since_contact <= window

## Current horizontal speed ceiling: base..cap by momentum, raised briefly by a dash.
func speed_cap() -> float:
	var cap := lerpf(movement.run_speed_base, movement.run_speed_cap, momentum_charge)
	if dash_boost_remaining > 0.0:
		cap *= movement.dash_boost_cap_mult
	return cap

## Derived so acceleration and redirect stay one knob: a full flip (-base -> +base)
## takes ground_redirect_time (DESIGN 4.1).
func ground_accel() -> float:
	return 2.0 * movement.run_speed_base / movement.ground_redirect_time

func air_accel() -> float:
	return ground_accel() * movement.air_control_ratio

func can_dash() -> bool:
	return dash_charges_left > 0 and not air_dash_locked

func consume_dash_charge() -> void:
	dash_charges_left -= 1
	if dash_recharge_remaining <= 0.0:
		dash_recharge_remaining = movement.dash_recharge

## Surfaces flatter than wall_normal_min_x are ceilings/slopes, never wall-jumpable.
func wall_is_jumpable(n: Vector2) -> bool:
	return absf(n.x) >= movement.wall_normal_min_x

func has_buffered_jump() -> bool:
	return jump_buffer_remaining > 0.0

func consume_jump_buffer() -> void:
	jump_buffer_remaining = 0.0
	coyote_remaining = 0.0

## Momentum builds with sustained running and is spent by non-perfect contact.
func build_momentum(delta: float) -> void:
	momentum_charge = minf(momentum_charge + delta / movement.accel_time_to_cap, 1.0)

func note_perfect(kind: StringName) -> void:
	perfect_window_hit.emit(kind)
#endregion
