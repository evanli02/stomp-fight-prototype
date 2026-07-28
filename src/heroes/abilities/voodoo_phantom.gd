class_name VoodooPhantom extends Ability
## Voodoo's ultimate — Phantom (docs/NEW_HEROES.md §Voodoo). SKELETON.
##
## Soul Ignition, turned all the way up, plus a ghost rule: for the window
## Voodoo passes THROUGH every other body, ally and enemy — no side-on
## collision, no being terrain to anyone, no wall-jumping off him. Passing
## through an enemy stuns them for PASS_STUN_TIME (refresh on re-pass, never
## stack). The one thing phasing must NOT change is the stomp: his stompbox and
## their head hurtbox stay live, and falling through an enemy's head from above
## is still resolved by the ordinary stomp system — receive_stomp, grace,
## anti-chain, victim authority, untouched.
##
## Visuals: the &"surge" aura at full menace, and the sprite runs the INVERTED
## palette for the window (SpriteFrames swap, not a modulate — a tint would
## fight the grace blink). The inverted frames ship as voodoo_phantom_frames
## once the generator gains the variant.

## Noticeably longer than the ability's window.
@export var duration: float = 9.0
## The same empowerment as Soul Ignition, noticeably more of it.
@export var speed_mult: float = 1.4
@export var impulse_mult: float = 1.3
## The pass-through stun. Refreshes, never stacks.
@export var pass_stun_time: float = 3.0

func _execute(_aim: Vector2) -> void:
	# TODO(opus): implement per docs/NEW_HEROES.md §Voodoo —
	#  1. Empowerment as Soul Ignition, with these bigger numbers.
	#  2. player.begin_phasing(duration) [new API: drops the body <-> body
	#     collision bit both ways; head hurtbox + stompbox stay live; per-tick
	#     enemy-overlap scan applies apply_stun(pass_stun_time) with a
	#     re-trigger gap so one pass = one stun and a re-pass RESETS it]
	#  3. HeroAura.attach(player, duration, &"surge", accent, 2.0) — the
	#     intensity is what makes the ult read angrier than the ability.
	#  4. Inverted-palette frames for the window; restore on expiry AND on
	#     elimination/round end (never leave the swap dangling).
	push_warning("Phantom is a skeleton — see docs/NEW_HEROES.md")
