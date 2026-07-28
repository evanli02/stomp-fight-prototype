class_name SaintBenediction extends Ability
## Saint's ultimate — Benediction (docs/NEW_HEROES.md §Saint). SKELETON.
##
## Cleanse, then a blessing window on Saint and every living ally:
##  - the same movement/speed empowerment shape as Voodoo's Soul Ignition,
##  - immunity to every debuff and stun for the window,
##  - and a guardian rule on the stomp: an enemy who stomps a blessed player
##    takes no life — the victim LOSES THE BLESSING instead. One hit, absorbed,
##    buff gone; the attacker still gets their bounce, so the play is not
##    punished, just paid in a different coin.
##
## The absorb is the one place outside receive_stomp allowed to decide a stomp
## outcome, and it must live INSIDE receive_stomp as an early-out (like grace
## does) — never as a second resolution path (CLAUDE.md 1: the stomp system
## stays the only authority on lives).
##
## Every blessed body wears the &"ward" aura for the window, so both teams can
## read who is holy.

@export var duration: float = 7.0
@export var speed_mult: float = 1.25
@export var impulse_mult: float = 1.18

func _can_fire() -> bool:
	# TODO(opus): same fires_while_stunned gate as Cleanse; EMP still blocks.
	return true

func _execute(_aim: Vector2) -> void:
	# TODO(opus): implement per docs/NEW_HEROES.md §Saint —
	#  1. The full Cleanse on Saint + allies.
	#  2. Per blessed body: grant_speed_buff, grant_impulse_buff,
	#     grant_debuff_immunity(duration) [new API], and
	#     grant_stomp_ward(duration) [new API: consumed by the first stomp
	#     received — no life lost, ward + blessing cleared, attacker bounce
	#     kept, stomp_warded signal for HUD/SFX].
	#  3. HeroAura.attach(each, duration, &"ward", accent) — dropped early on
	#     the body whose ward was consumed.
	push_warning("Benediction is a skeleton — see docs/NEW_HEROES.md")
