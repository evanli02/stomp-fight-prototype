class_name Player extends CharacterBody2D
## One instance per PLAYER (not per hero). Hero swaps re-skin and re-equip this
## body in place — position, velocity, and stun persist across swaps (DESIGN 2.4).
## Movement logic lives in the StateMachine child; abilities and terrain interact
## with this class ONLY through the public API section below (IMPLEMENTATION.md 3).

signal stomped(attacker: Player)
## Attacker side of the same event — feeds the bounce VFX/SFX and the duel stage
## readout. The life is removed on the victim (IMPLEMENTATION.md 5).
signal stomp_landed(victim: Player)
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
## Downward speed carried into the current contact, kept alive for
## stomp_fall_memory_time. move_and_slide() zeroes velocity.y the frame a body
## lands, which is a frame before the areas report their overlap, so the fall
## that earned the stomp has to outlive the collision that stopped it.
var fall_speed_memory: float = 0.0
## True while the head hurtbox is off for spawn protection rather than for
## post-stomp grace: this variant ends early on the player's first action
## (DESIGN 3.3).
var spawn_protected: bool = false

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
## The other player currently being used as a wall, if any (DESIGN 3.4).
var wall_player: Player = null
var dash_recharge_remaining: float = 0.0
var dash_boost_remaining: float = 0.0
## False during the b-hop window after a landing: momentum is still intact and a
## jump in this window keeps 100% of it (DESIGN 4.2).
var landing_settled: bool = true
var _was_on_wall: bool = false
## Open wall-jump duel claim: who was kicked off, on which physics frame, and
## with what impulse (needed to pay the juice as a delta later).
var _duel_target: Player = null
var _duel_frame: int = -1
var _duel_impulse: Vector2 = Vector2.ZERO
#endregion

## Cosmetic only (DESIGN 3.2 "blinking silhouette") — not feel numbers, so they
## stay out of the config resources.
const BLINK_PERIOD: float = 0.16
const BLINK_ALPHA: float = 0.35

@onready var sprite: Sprite2D = %Sprite
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

func start_spawn_protection() -> void:
	## Head hurtbox off for spawn_protection_time or until the player acts,
	## whichever comes first (DESIGN 3.3).
	grace_remaining = maxf(grace_remaining, combat.spawn_protection_time)
	spawn_protected = true
	set_head_hurtbox_enabled(false)

func respawn_at(spawn_position: Vector2) -> void:
	## Put the body back at a spawn point with movement bookkeeping cleared. Does
	## NOT touch lives or rosters — MatchState owns those.
	global_position = spawn_position
	velocity = Vector2.ZERO
	momentum_charge = 0.0
	dash_charges_left = movement.dash_charges
	air_dash_locked = false
	wall_jump_chain = 0
	fall_speed_memory = 0.0
	stun_remaining = 0.0
	_clear_duel_claim()
	state_machine.change_state(&"Air")
	start_spawn_protection()
#endregion

#region Stomp resolution — victim-authoritative (IMPLEMENTATION.md 5)
## Feet-on-head scan, run once per tick after the body has moved. The attacker
## detects; the victim decides (receive_stomp is the authority), so a graced or
## already-dead victim can refuse without the attacker knowing the rules.
func _scan_stomps() -> void:
	if fall_speed_memory < combat.stomp_min_relative_fall_speed:
		return
	var victims: Array[Player] = []
	for area in stomp_box.get_overlapping_areas():
		var victim := area.owner as Player
		if victim != null and _is_stomp_on(victim):
			victims.append(victim)
	# Resolved in player_id order, never in physics contact order, so a doubled
	# stomp lands the same way every run (IMPLEMENTATION.md 9).
	victims.sort_custom(func(a: Player, b: Player) -> bool: return a.player_id < b.player_id)
	for victim in victims:
		victim.receive_stomp(self)

func _is_stomp_on(victim: Player) -> bool:
	if victim == self or victim.team_id == team_id:
		return false  # allies are terrain, never targets (DESIGN 3.4)
	if victim.grace_remaining > 0.0:
		return false
	if global_position.y >= victim.global_position.y:
		return false  # must be the one on top
	# "Falling onto them" is relative: two players dropping together at the same
	# speed graze, they don't stomp (DESIGN 3.1).
	return fall_speed_memory - victim.velocity.y >= combat.stomp_min_relative_fall_speed

func receive_stomp(attacker: Player) -> void:
	if grace_remaining > 0.0:
		return
	if MatchState.has_player(player_id):
		MatchState.lose_life(player_id, active_hero)
	apply_stun(combat.stomp_stun_time)
	grace_remaining = combat.stomp_grace_time
	spawn_protected = false
	set_head_hurtbox_enabled(false)
	# Directional bounce from contact point; momentum is KEPT (DESIGN 3.2).
	var dir := (global_position - attacker.global_position).normalized()
	apply_impulse(dir * combat.stomp_victim_bounce)
	stomped.emit(attacker)
	attacker.on_stomp_landed(self)

func on_stomp_landed(victim: Player) -> void:
	## Attacker bounce — roughly a jump, hold-extendable, so chaining stomps
	## between different victims pays off (DESIGN 3.2).
	fall_speed_memory = 0.0
	# A head is a surface, and players are terrain (DESIGN 3.4), so the stomp
	# clears the airborne dash lock and the wall-jump chain exactly like a
	# landing would — dash into stomp into dash is intended.
	air_dash_locked = false
	wall_jump_chain = 0
	if stun_remaining > 0.0:
		# Bouncing off a head never returns control early (CLAUDE.md checklist).
		velocity.y = combat.stomp_attacker_bounce
	else:
		request_state(&"Air", {"jump": true, "impulse_y": combat.stomp_attacker_bounce})
	stomp_landed.emit(victim)
#endregion

func _process(_delta: float) -> void:
	# Presentation only. The timer it reads is ticked on the physics step, and
	# the sprite's RGB is left alone so a team tint survives the blink.
	var blink_off := grace_remaining > 0.0 \
		and fmod(grace_remaining, BLINK_PERIOD) < BLINK_PERIOD * 0.5
	sprite.modulate.a = BLINK_ALPHA if blink_off else 1.0

func _physics_process(delta: float) -> void:
	input = InputConfig.poll(player_id, self)
	_tick_timers(delta)
	state_machine.tick(delta)
	var was_on_floor := is_on_floor()
	# Sampled before the move because the collision that ends a fall also erases
	# the speed that made it a stomp. Only a body in the air is falling: standing
	# on someone's head still gets a frame of gravity applied every tick, and
	# without this guard that alone would eventually read as a stomp (DESIGN 3.1
	# — you have to fall onto the head, not rest on it).
	if velocity.y > 0.0 and not is_on_floor():
		fall_speed_memory = velocity.y
	move_and_slide()
	_post_move(was_on_floor)
	_scan_stomps()

func _tick_timers(delta: float) -> void:
	fall_speed_memory = move_toward(fall_speed_memory, 0.0,
		movement.fall_speed_max * delta / combat.stomp_fall_memory_time)
	_tick_duel_claim()
	if grace_remaining > 0.0:
		if spawn_protected and input.any_action():
			grace_remaining = 0.0  # spawn protection ends on your first action
		else:
			grace_remaining -= delta
		if grace_remaining <= 0.0:
			spawn_protected = false
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
	wall_player = _wall_collider_player() if on_jumpable_wall else null
	_was_on_wall = on_jumpable_wall

	# Ceilings are never wall-jumpable but do reset the air dash (DESIGN 4.4).
	if is_on_ceiling():
		air_dash_locked = false

## Which player, if any, is the wall we are currently on. Ignores floors and
## ceilings by reusing the same normal test the wall states use.
func _wall_collider_player() -> Player:
	for i in get_slide_collision_count():
		var collision := get_slide_collision(i)
		if not wall_is_jumpable(collision.get_normal()):
			continue
		var other := collision.get_collider() as Player
		if other != null:
			return other
	return null

func _on_landed() -> void:
	time_since_landing = 0.0
	landing_settled = false

func _settle_landing() -> void:
	momentum_charge *= movement.momentum_keep_on_landing
	velocity.x = clampf(velocity.x, -speed_cap(), speed_cap())
	landing_settled = true

#region Wall-jump duels (DESIGN 3.4)
## Register a wall jump taken off another player; returns the multiplier to
## apply to the impulse.
##
## The stun is deliberately deferred to the end of the window instead of landing
## with the jump: stunning immediately would make a simultaneous duel impossible
## to reach, because the "loser" would be stunned out of the input that ties it.
## Both halves are decided by physics frame number, never by contact order, so
## the outcome is reproducible (IMPLEMENTATION.md 9).
func claim_wall_duel(other: Player, impulse: Vector2) -> float:
	if other.has_open_duel_claim_against(self):
		other.grant_duel_juice()      # they jumped first; nobody gets stunned
		note_perfect(&"duel")
		return movement.duel_juice_mult
	_duel_target = other
	_duel_frame = Engine.get_physics_frames()
	_duel_impulse = impulse
	return 1.0

func has_open_duel_claim_against(other: Player) -> bool:
	return _duel_target == other \
		and Engine.get_physics_frames() - _duel_frame <= movement.duel_window_frames

func grant_duel_juice() -> void:
	## Paid as a delta rather than a rescale so the few frames of gravity since
	## the earlier jump are not multiplied along with the impulse.
	apply_impulse(_duel_impulse * (movement.duel_juice_mult - 1.0))
	note_perfect(&"duel")
	_clear_duel_claim()

func _tick_duel_claim() -> void:
	if _duel_target == null:
		return
	if not is_instance_valid(_duel_target):
		_clear_duel_claim()
		return
	if Engine.get_physics_frames() - _duel_frame <= movement.duel_window_frames:
		return
	# Unanswered inside the window: first input wins, loser eats a short stun and
	# no life (DESIGN 3.4 — nothing but a stomp ever costs a life).
	_duel_target.apply_stun(combat.stun_duel_loss)
	_clear_duel_claim()

func _clear_duel_claim() -> void:
	_duel_target = null
	_duel_frame = -1
	_duel_impulse = Vector2.ZERO
#endregion

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
