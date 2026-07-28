class_name VoodooSoulIgnition extends Ability
## Voodoo — Soul Ignition (docs/NEW_HEROES.md §Voodoo). SKELETON: numbers and
## contract are final; the marked TODOs are the implementation.
##
## Self-empowerment for a window: a speed buff plus a lift to every movement
## impulse — jump, dash, air dash, wall jump, slide jump. While it runs, any
## non-killing body contact with an enemy knocks them back and slows them,
## movement impulses included, for CONTACT_SLOW_TIME. A stomp during the window
## is still just a stomp: the ignition adds nothing to it and must not touch
## the stomp path at all (CLAUDE.md 1).
##
## No stacking anywhere: re-igniting refreshes the window, re-touching an enemy
## resets their 3 s slow. Both are max(remaining, new) — the same refresh rule
## as stuns.

## The window. Long enough to force a real answer, short enough to wait out.
@export var duration: float = 5.0
## Run-speed-cap multiplier while ignited (grant_speed_buff).
@export var speed_mult: float = 1.25
## Movement-impulse multiplier while ignited — the buff-side twin of
## impair_mult. Needs the new Player.grant_impulse_buff (NEW_HEROES.md §API).
@export var impulse_mult: float = 1.18
## The touch: knockback magnitude, away from Voodoo's centre.
@export var contact_knockback: float = 420.0
## The touch: slow multiplier and window on the enemy. Movement controls too —
## apply_slow AND apply_impairment with the same tag, so their dash and jump
## shrink with their run.
@export var contact_slow_mult: float = 0.55
@export var contact_impair_mult: float = 0.6
@export var contact_slow_time: float = 3.0

func _execute(_aim: Vector2) -> void:
	# TODO(opus): implement per docs/NEW_HEROES.md §Voodoo —
	#  1. player.grant_speed_buff(speed_mult, duration)
	#  2. player.grant_impulse_buff(impulse_mult, duration)      [new API]
	#  3. player.begin_contact_debuff(contact_knockback, contact_slow_mult,
	#         contact_impair_mult, contact_slow_time, duration, &"ignite")
	#     [new API: per-tick enemy-overlap scan on the player, re-trigger gap,
	#      tag &"ignite"; re-touch RESETS the 3 s, never stacks]
	#  4. Aura: HeroAura.attach(player, duration, &"surge", accent, 1.0)
	push_warning("Soul Ignition is a skeleton — see docs/NEW_HEROES.md")
