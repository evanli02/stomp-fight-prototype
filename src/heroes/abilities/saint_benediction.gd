class_name SaintBenediction extends Ability
## Saint's ultimate — Benediction (docs/NEW_HEROES.md §Saint).
##
## Cleanse, then a blessing window on Saint and every ally:
##  - the same movement empowerment shape as Voodoo's Soul Ignition,
##  - immunity to every debuff and stun for the window,
##  - and a guardian rule on the stomp: an enemy who stomps a blessed player
##    takes no life — the victim loses the blessing instead. One hit absorbed,
##    buff gone; the attacker still gets their bounce, so the read is not
##    punished, only charged in a different coin.
##
## Cleanse runs FIRST and the blessing second, on purpose: a stun landing on the
## same frame is cleaned off rather than immunised around.
##
## The absorb itself lives inside `Player.receive_stomp`, next to the grace
## early-out — the stomp system stays the only thing that decides whether a
## stomp lands (CLAUDE.md 1). Nothing here reaches a life.

@export var duration: float = 7.0
@export var speed_mult: float = 1.25
@export var impulse_mult: float = 1.18

func _execute(_aim: Vector2) -> void:
	var allies := all_players().filter(
		func(p: Player) -> bool: return p.team_id == player.team_id)
	for t in allies:
		var ally := t as Player
		# Order matters: clean first, then bless.
		ally.clear_all_debuffs()
		ally.grant_speed_buff(speed_mult, duration)
		ally.grant_impulse_buff(impulse_mult, duration)
		ally.grant_debuff_immunity(duration)
		ally.grant_stomp_ward(duration)
		var aura := HeroAura.new()
		player.spawn_effect(aura)
		aura.attach(ally, duration, &"ward", _accent())
		# The halo goes out with the blessing, not with the clock: a body still
		# glowing after its ward was spent is worse than no halo at all.
		aura.expire_when = func() -> bool: return ally.stomp_ward_remaining <= 0.0

func _accent() -> Color:
	return player.hero.accent_color if player.hero != null else Color(0.95, 0.95, 0.98)
