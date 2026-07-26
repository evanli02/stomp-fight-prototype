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
## Cosmetic identity only — sprite frames and accent. Movement and hitboxes are
## identical for every hero and never come from here (CLAUDE.md rule 3).
@export var hero: HeroData

var momentum_charge: float = 0.0        ## 0..1, scales run cap (DESIGN 4.1)
var dash_charges_left: int = 2
var air_dash_locked: bool = false       ## set after airborne dash, cleared on surface touch
var stun_remaining: float = 0.0
var grace_remaining: float = 0.0
var active_hero: StringName = &""
var crouched: bool = false
## Animation that must finish before the state machine drives the sprite again.
var _oneshot: StringName = &""
var _equipped_ability: Ability = null
var _equipped_ultimate: Ability = null
var speed_buff_mult: float = 1.0
var speed_buff_remaining: float = 0.0
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
var wall_jump_chain: int = 0            ## consecutive wall jumps off the SAME wall face
## Which wall the current chain belongs to. A face is a collider plus a side, so
## the two walls of a shaft are distinct even when one TileMap owns both.
var chain_wall_collider: int = 0
var chain_wall_side: int = 0
## The wall currently under contact, in the same terms.
var wall_collider_id: int = 0
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
## How long the landing squash reads for. Presentation, not a feel number — the
## state machine is already back in Idle or Run by then.
const LAND_ANIM_TIME: float = 0.12

## Stick deflection that counts as "down" (DESIGN 4.6). A deadzone, not a feel
## number: below it a diagonal run would drop into a crouch.
const CROUCH_INPUT_THRESHOLD: float = 0.5

@onready var sprite: AnimatedSprite2D = %Sprite
@onready var state_machine: StateMachine = %StateMachine
@onready var head_hurtbox: Area2D = %HeadHurtbox
@onready var stomp_box: Area2D = %StompBox
@onready var ability_slot: Node = %AbilitySlot
@onready var body_shape: CollisionShape2D = %BodyShape
@onready var body_shape_crouch: CollisionShape2D = %BodyShapeCrouch
@onready var head_shape: CollisionShape2D = %HeadShape
@onready var head_shape_crouch: CollisionShape2D = %HeadShapeCrouch

func _ready() -> void:
	# Abilities find their targets through this group rather than by walking the
	# scene, so a stage can arrange its bodies however it likes.
	add_to_group(&"players")
	dash_charges_left = movement.dash_charges
	if hero != null:
		set_hero(hero)
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
	## Raises the run cap for a while (Mason's Keystone). Refresh takes the
	## stronger multiplier and the longer timer rather than stacking, so buff
	## juggling can never outrun the cap by a lot.
	speed_buff_mult = maxf(speed_buff_mult, mult)
	speed_buff_remaining = maxf(speed_buff_remaining, dur)

## Where abilities put the things they create. Effects are parented to the stage,
## never to the player — a bolt or a placed block must not ride the body that
## made it, and it has to outlive a hero swap (DESIGN 2.4).
func spawn_effect(node: Node) -> void:
	var host := get_parent()
	if host == null:
		node.queue_free()
		return
	host.add_child(node)

func equipped_ability() -> Ability:
	## The basic (non-ultimate) ability, for ultimates that modify it.
	return _equipped_ability

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

func set_hero(data: HeroData) -> void:
	## Re-skin in place: frames swap, the body does not. Hero swaps must never
	## respawn the player (DESIGN 2.4), and never touch movement (CLAUDE.md 3).
	hero = data
	if data != null and data.sprite_frames != null:
		sprite.sprite_frames = data.sprite_frames
		sprite.play(&"idle")

func equip_hero(hero_id: StringName) -> void:
	## Put a hero in the body: skin plus their ability component. Position,
	## velocity, momentum, and stun are all deliberately untouched — the incoming
	## hero inherits the outgoing hero's situation (DESIGN 2.4).
	active_hero = hero_id
	var data := GameManager.hero_data(hero_id)
	if data == null:
		return
	set_hero(data)
	for child in ability_slot.get_children():
		child.queue_free()
	_equipped_ability = _instance_ability(data.ability_scene, hero_id, data.ability_cooldown, false)
	_equipped_ultimate = _instance_ability(data.ultimate_scene, hero_id, 0.0, true)

func _instance_ability(scene: PackedScene, hero_id: StringName,
		cooldown: float, is_ult: bool) -> Ability:
	if scene == null:
		return null
	var node := scene.instantiate()
	var ability := node as Ability
	if ability == null:
		node.queue_free()
		return null
	ability.player = self
	ability.hero_id = hero_id
	ability.cooldown = cooldown
	ability.is_ultimate = is_ult
	ability_slot.add_child(ability)
	return ability

## Cycle to the next living hero. No cooldown and no cost, but blocked while
## stunned — swapping must never be a way out of a stun (CLAUDE.md checklist).
func try_swap() -> bool:
	if stun_remaining > 0.0 or not MatchState.has_player(player_id):
		return false
	var target := MatchState.next_living_hero(player_id)
	if not MatchState.swap_to(player_id, target):
		return false
	equip_hero(target)
	return true

func try_ability() -> bool:
	if stun_remaining > 0.0 or _equipped_ability == null:
		return false
	return _equipped_ability.try_fire(input.aim)

func try_ultimate() -> bool:
	## Also blocked while stunned (CLAUDE.md checklist). The spend happens inside
	## Ability.try_fire via MatchState, so a blocked ult is never consumed.
	if stun_remaining > 0.0 or _equipped_ultimate == null:
		return false
	return _equipped_ultimate.try_fire(input.aim)

func play_elimination() -> void:
	## The confetti pop for a hero's last life (DESIGN 3.3). One-shot: it holds
	## the sprite until it finishes, then the state machine takes over again.
	if sprite.sprite_frames != null and sprite.sprite_frames.has_animation(&"pop"):
		_oneshot = &"pop"
		sprite.play(&"pop")

func set_crouched(on: bool) -> void:
	## Half-height body and a head hurtbox that moves down with it (DESIGN 4.6).
	## Owned here rather than in Crouch/Slide because both states share it and
	## every exit route — including being stunned out of a slide — has to restore
	## the standing shape.
	if crouched == on:
		return
	crouched = on
	# Deferred: swapping collision shapes from inside the physics callback is not
	# allowed while the space is flushing queries. Both swaps land in the same
	# flush, so there is never a frame with no body shape at all.
	body_shape.set_deferred(&"disabled", on)
	body_shape_crouch.set_deferred(&"disabled", not on)
	head_shape.set_deferred(&"disabled", on)
	head_shape_crouch.set_deferred(&"disabled", not on)
	# The sprite is not squashed here: the crouch and slide frames are drawn into
	# the bottom 24px of the same 32x48 canvas, so the art already matches the
	# short collision box.

func respawn_at(spawn_position: Vector2) -> void:
	## Put the body back at a spawn point with movement bookkeeping cleared. Does
	## NOT touch lives or rosters — MatchState owns those.
	global_position = spawn_position
	velocity = Vector2.ZERO
	momentum_charge = 0.0
	dash_charges_left = movement.dash_charges
	air_dash_locked = false
	_reset_wall_chain()
	fall_speed_memory = 0.0
	stun_remaining = 0.0
	set_crouched(false)
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
	# Presentation only. The values it reads are all set on the physics step, and
	# the sprite's RGB is left alone so a tint survives the blink.
	var blink_off := grace_remaining > 0.0 \
		and fmod(grace_remaining, BLINK_PERIOD) < BLINK_PERIOD * 0.5
	sprite.modulate.a = BLINK_ALPHA if blink_off else 1.0
	sprite.flip_h = facing < 0
	_update_animation()

## The running state decides the pose — it is the thing that knows what the body
## is doing. Only two exceptions are resolved here, both because they outlive the
## state that caused them: the landing squash, and a one-shot like the pop.
func _update_animation() -> void:
	if sprite.sprite_frames == null:
		return
	if _oneshot != &"":
		if sprite.is_playing():
			return
		_oneshot = &""
	var anim := state_machine.current_animation()
	if anim in [&"idle", &"run"] and not landing_settled and time_since_landing < LAND_ANIM_TIME:
		anim = &"land"
	if sprite.sprite_frames.has_animation(anim) and sprite.animation != anim:
		sprite.play(anim)

func _physics_process(delta: float) -> void:
	input = InputConfig.poll(player_id, self)
	_tick_timers(delta)
	_handle_hero_input()
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

## Swap, ability, and ultimate all read from the same InputFrame the movement
## states do. The ultimate is checked first: on a controller it arrives as the
## R2+L2 chord, and InputConfig has already suppressed the dash and swap that
## made it (DESIGN 7).
func _handle_hero_input() -> void:
	if input.ultimate_pressed:
		try_ultimate()
	if input.ability_pressed:
		try_ability()
	if input.swap_pressed:
		try_swap()

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

	if speed_buff_remaining > 0.0:
		speed_buff_remaining -= delta
		if speed_buff_remaining <= 0.0:
			speed_buff_mult = 1.0

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
		_reset_wall_chain()

	var on_jumpable_wall := is_on_wall() and wall_is_jumpable(get_wall_normal())
	if on_jumpable_wall:
		wall_normal = get_wall_normal()
		if not _was_on_wall:
			time_since_wall_contact = 0.0  # opens the perfect wall-jump window
		air_dash_locked = false
	if on_jumpable_wall:
		_scan_wall_contact()
	else:
		wall_collider_id = 0
		wall_player = null
	_was_on_wall = on_jumpable_wall

	# Ceilings are never wall-jumpable but do reset the air dash (DESIGN 4.4).
	if is_on_ceiling():
		air_dash_locked = false

## What we are currently using as a wall: the collider's id, and the player if it
## happens to be one. Floors and ceilings are ignored by reusing the same normal
## test the wall states use.
func _scan_wall_contact() -> void:
	wall_collider_id = 0
	wall_player = null
	for i in get_slide_collision_count():
		var collision := get_slide_collision(i)
		if not wall_is_jumpable(collision.get_normal()):
			continue
		var collider := collision.get_collider()
		if collider == null:
			continue
		wall_collider_id = (collider as Object).get_instance_id()
		wall_player = collider as Player
		return

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
	return cap * speed_buff_mult

## Getting moving: a standstill reaches run_speed_base in ground_accel_time.
func ground_accel() -> float:
	return movement.run_speed_base / movement.ground_accel_time

## Changing your mind: a full flip (-base -> +base) still takes
## ground_redirect_time, which is deliberately quicker than startup — heavy to
## get going, light to turn around (DESIGN 4.1).
func ground_redirect_accel() -> float:
	return 2.0 * movement.run_speed_base / movement.ground_redirect_time

## Off the redirect rate rather than startup: air control is about nudging an
## arc you already committed to, and it should not have gotten weaker when
## starting a run got heavier.
func air_accel() -> float:
	return ground_redirect_accel() * movement.air_control_ratio

## Down held past the deadzone — the entry condition for crouch and slide.
func wants_crouch() -> bool:
	return input.move.y > CROUCH_INPUT_THRESHOLD

func can_dash() -> bool:
	return dash_charges_left > 0 and not air_dash_locked

func consume_dash_charge() -> void:
	dash_charges_left -= 1
	if dash_recharge_remaining <= 0.0:
		dash_recharge_remaining = movement.dash_recharge

## Claim the wall jump about to happen and return how many have already come off
## this same face. The chain — and its collapsing upward impulse — belongs to one
## wall: crossing a shaft to the opposite face starts over at full strength,
## while hopping up a single wall decays (DESIGN 4.4).
func begin_wall_jump() -> int:
	var side := signi(int(signf(wall_normal.x)))
	if wall_collider_id != chain_wall_collider or side != chain_wall_side:
		wall_jump_chain = 0
		chain_wall_collider = wall_collider_id
		chain_wall_side = side
	var index := wall_jump_chain
	wall_jump_chain += 1
	return index

func _reset_wall_chain() -> void:
	wall_jump_chain = 0
	chain_wall_collider = 0
	chain_wall_side = 0

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
