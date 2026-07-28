class_name SleepingState extends PlayerState
## Vesper's sleep (docs/NEW_HEROES.md §1.6). Not a stun: the player keeps one
## thing — walking left and right, at a crawl — and loses everything else. No
## jump, no dash, no wall interaction, no slide, no crouch, no swap, no casting.
##
## The sliver of agency is the design. A stun is something that happens to you
## and ends; sleep is several seconds of watching an enemy line up a stomp while
## you shuffle uselessly, which is why the third dart is frightening in a way a
## stun never is.
##
## Momentum is pinned at zero: walking while asleep must never build toward the
## run cap, or a long sleep would end with the victim at full speed.
##
## The head hurtbox is deliberately untouched. A sleeping player is the most
## stompable player in the game — that is what the whole kit is buying.

func enter(_params: Dictionary = {}) -> void:
	# Standing shape: a body slept out of a slide would otherwise stay crouched
	# with no state left that knows to restore it.
	player.set_crouched(false)
	player.momentum_charge = 0.0

func physics_update(delta: float) -> void:
	# A launch survives the sleep. Springs, Mason's block and Siku's pillar all
	# set an upward velocity and then ask for Air — and while asleep that
	# request is redirected back here (Player.request_state), so this state
	# inherits the grounded-launch trap from CLAUDE.md's checklist: pinning
	# velocity.y on the floor the way Idle and Run do would erase the launch
	# before it ever moved anyone, and a sleeper in Sunken Court's spring pit
	# would just stand on the springs. Only a body that is resting or already
	# falling gets pinned; a launched one keeps its rise and arcs under gravity.
	if player.is_on_floor() and player.velocity.y >= 0.0:
		player.velocity.y = 0.0
	else:
		player.velocity.y = minf(
			player.velocity.y + player.movement.gravity * delta,
			player.movement.fall_speed_max)

	# The crawl. A hard cap rather than the usual momentum-scaled one, because
	# momentum is exactly what sleep takes away.
	var crawl := player.movement.run_speed_base * player.movement.sleep_walk_mult
	var dir := player.input.move.x
	if is_zero_approx(dir):
		player.velocity.x = move_toward(player.velocity.x, 0.0,
			player.ground_friction() * delta)
	else:
		player.velocity.x = move_toward(player.velocity.x, signf(dir) * crawl,
			player.ground_accel() * delta)
	player.momentum_charge = 0.0

	if player.sleep_remaining <= 0.0:
		machine.change_state(&"Idle" if player.is_on_floor() else &"Air")

func animation() -> StringName: return &"stun"
