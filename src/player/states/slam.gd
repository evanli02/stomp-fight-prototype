class_name SlamState extends PlayerState
## Terra's slam (DESIGN 5.2): hang for a beat, then drive straight down.
##
## The kill case needs no special rule. A slam is a very fast fall, and falling
## onto a head IS the stomp system — the plummet feeds fall_speed_memory like
## any other descent, so landing on someone resolves through receive_stomp with
## every stomp rule intact (grace, anti-chain, victim authority). The shockwave
## on landing is the consolation prize, and like all ability effects it stuns
## and shoves but can never take a life (CLAUDE.md 1).

const HOVER_TIME: float = 0.25
const SLAM_SPEED: float = 1500.0
const SHOCK_RADIUS: float = 90.0
const SHOCK_FORCE: float = 520.0
const SHOCK_STUN: float = 0.35

var _hovering: float = 0.0

func enter(_params: Dictionary = {}) -> void:
	_hovering = HOVER_TIME
	player.velocity = Vector2.ZERO

func physics_update(delta: float) -> void:
	if _hovering > 0.0:
		_hovering -= delta
		player.velocity = Vector2.ZERO   # the wind-up: pinned in the air
		return
	# Straight down, no drift — the horizontal component is surrendered.
	player.velocity = Vector2(0.0, SLAM_SPEED)
	if player.is_on_floor():
		_land()

func _land() -> void:
	var burst := RadialBurst.new()
	player.spawn_effect(burst)
	var targets: Array = []
	for body in player.get_tree().get_nodes_in_group(&"players"):
		var p := body as Player
		if p != null and p.team_id != player.team_id:
			targets.append(p)
	targets.sort_custom(func(a: Player, b: Player) -> bool: return a.player_id < b.player_id)
	var colour: Color = player.hero.accent_color if player.hero != null else Color.WHITE
	burst.detonate(player.global_position, targets, SHOCK_RADIUS, SHOCK_FORCE,
		SHOCK_STUN, colour)
	machine.change_state(&"Idle")

func animation() -> StringName:
	return &"cast" if _hovering > 0.0 else &"fall"
