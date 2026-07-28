class_name VoodooSoulIgnition extends Ability
## Voodoo — Soul Ignition (docs/NEW_HEROES.md §Voodoo).
##
## Self-empowerment for a window: a speed buff plus a lift to every movement
## impulse — jump, dash, air dash, wall jump, slide jump. While it runs, any
## non-killing body contact with an enemy knocks them back and slows them,
## movement controls included, for `contact_slow_time`. A stomp during the
## window is still just a stomp: the ignition adds nothing to it and never
## touches the stomp path at all (CLAUDE.md 1).
##
## No stacking anywhere: re-igniting refreshes the window, re-touching an enemy
## resets their 3 s slow. Both fall out of max-refresh, which is the same rule
## stuns use.

## The window. Long enough to force a real answer, short enough to wait out.
@export var duration: float = 5.0
## Run-speed-cap multiplier while ignited.
@export var speed_mult: float = 1.25
## Movement-impulse multiplier while ignited.
@export var impulse_mult: float = 1.18
## The touch: knockback magnitude, away from Voodoo's centre.
@export var contact_knockback: float = 420.0
## The touch: slow and impair on the enemy. Both, with one tag — the spec asks
## for their *other movement controls* to slow too, so the jump and dash shrink
## alongside the run.
@export var contact_slow_mult: float = 0.55
@export var contact_impair_mult: float = 0.6
@export var contact_slow_time: float = 3.0

func _execute(_aim: Vector2) -> void:
	player.grant_speed_buff(speed_mult, duration)
	player.grant_impulse_buff(impulse_mult, duration)
	player.begin_contact_debuff(contact_knockback, contact_slow_mult,
		contact_impair_mult, contact_slow_time, duration, &"ignite")
	var aura := HeroAura.new()
	player.spawn_effect(aura)
	aura.attach(player, duration, &"surge", _accent(), 1.0)

func _accent() -> Color:
	return player.hero.accent_color if player.hero != null else Color(0.75, 0.37, 1.0)
