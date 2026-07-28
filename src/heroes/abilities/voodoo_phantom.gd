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

## Noticeably longer than a cast of the ability.
@export var duration: float = 12.0
## More run and more dash than Soul Ignition — but the JUMP is deliberately
## untouched (no impulse buff here): a ghost that also out-jumped everyone
## would leave no answer to him at all. The dash buff is dash-only.
@export var speed_mult: float = 1.6
@export var dash_mult: float = 1.45
## The pass-through stun. Refreshes, never stacks.
@export var pass_stun_time: float = 2.0

## The negative skin, loaded once. Generated beside the ordinary frames by
## assets/tools/generate_characters.py (see `VARIANTS` there).
const PHANTOM_FRAMES: String = "res://src/heroes/resources/frames/voodoo_phantom_frames.tres"

func _execute(_aim: Vector2) -> void:
	# Phantom supersedes Soul Ignition rather than stacking with it: an active
	# ignition is put out on the spot and sent back to a full cooldown, so the
	# two windows can never overlap and there is only ever one aura on him.
	var basic := player.equipped_ability()
	if basic is VoodooSoulIgnition:
		(basic as VoodooSoulIgnition).extinguish()

	player.grant_speed_buff(speed_mult, duration)
	player.grant_dash_buff(dash_mult, duration)
	player.begin_phasing(duration)
	player.begin_contact_stun(pass_stun_time, duration)
	player.apply_skin_override(load(PHANTOM_FRAMES) as SpriteFrames)
	var aura := HeroAura.new()
	player.spawn_effect(aura)
	# Intensity 2 is what makes the ultimate read angrier than the ability —
	# same aura, more of it, taller and denser.
	aura.attach(player, duration, &"surge", _phantom_accent(), 2.0)

func _accent() -> Color:
	return player.hero.accent_color if player.hero != null else Color(0.75, 0.37, 1.0)

## The ultimate's aura is the INVERSE of his accent — green, matching the
## negative skin he is wearing for the window. His ability keeps the ordinary
## purple, so at a glance the colour alone says which of the two is running.
func _phantom_accent() -> Color:
	var base := _accent()
	return Color(1.0 - base.r, 1.0 - base.g, 1.0 - base.b).lightened(0.3)
