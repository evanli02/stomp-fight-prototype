class_name VoodooPhantom extends Ability
## Voodoo's ultimate — Phantom (docs/NEW_HEROES.md §Voodoo).
##
## Soul Ignition, turned all the way up, plus a ghost rule: for the window
## Voodoo passes THROUGH every other body, ally and enemy — no side-on
## collision, no being terrain to anyone, no wall-jumping off him. Passing
## through an enemy stuns them for `pass_stun_time` (refreshed on a re-pass,
## never stacked).
##
## The one thing phasing does NOT change is the stomp. Head hurtboxes and
## stompboxes are Area2Ds on their own layers; phasing only lifts body-vs-body
## collision, so falling through an enemy's head still resolves through the
## ordinary stomp system — victim authority, grace, anti-chain — exactly like
## Terra's slam. The combat harness asserts both halves.

## Noticeably longer than the ability's window.
@export var duration: float = 9.0
## The same empowerment as Soul Ignition, noticeably more of it.
@export var speed_mult: float = 1.4
@export var impulse_mult: float = 1.3
## The pass-through stun. Refreshes, never stacks.
@export var pass_stun_time: float = 3.0

## The negative skin, loaded once. Generated beside the ordinary frames by
## assets/tools/generate_characters.py (see `VARIANTS` there).
const PHANTOM_FRAMES: String = "res://src/heroes/resources/frames/voodoo_phantom_frames.tres"

func _execute(_aim: Vector2) -> void:
	player.grant_speed_buff(speed_mult, duration)
	player.grant_impulse_buff(impulse_mult, duration)
	player.begin_phasing(duration)
	player.begin_contact_stun(pass_stun_time, duration)
	player.apply_skin_override(load(PHANTOM_FRAMES) as SpriteFrames)
	var aura := HeroAura.new()
	player.spawn_effect(aura)
	# Intensity 2 is what makes the ultimate read angrier than the ability —
	# same aura, more of it, taller and denser.
	aura.attach(player, duration, &"surge", _accent(), 2.0)

func _accent() -> Color:
	return player.hero.accent_color if player.hero != null else Color(0.75, 0.37, 1.0)
