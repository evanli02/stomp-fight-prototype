class_name SikuFrostbite extends Ability
## Siku's ultimate — Frostbite (docs/NEW_HEROES.md §Siku).
##
## Five expanding pulses out of Siku, one every few seconds, each a ring like
## Cerebelle's Supernova but much faster. An enemy a ring catches is stunned and
## dropped — velocity zeroed, momentum stripped. Each ring catches each enemy
## once, but the next ring is a fresh threat: standing near Siku for the whole
## window means eating pulse after pulse. She wears a frost aura for the whole
## storm, so "near Siku is currently a bad place" is readable at a glance.
##
## The schedule lives on a FrostbitePulses effect node, not on this one — an
## ability is freed the moment its hero is swapped out, and a storm that stopped
## because Siku rotated would be an ultimate spent on nothing.

@export var pulse_count: int = 5
## 3-4s band between pulses.
@export var pulse_gap: float = 3.5
## Significantly faster than Supernova's 250: dodging Frostbite is jumping the
## wave, not walking away from it.
@export var pulse_speed: float = 520.0
@export var pulse_reach: float = 1800.0
@export var stun_time: float = 1.5

func _execute(_aim: Vector2) -> void:
	var storm := FrostbitePulses.new()
	player.spawn_effect(storm)
	storm.begin(player, pulse_count, pulse_gap, pulse_speed, pulse_reach, stun_time)
	# The on-body read for "the storm is live": the whole window, first pulse to
	# last. Purely visual — the rings do all the work.
	var aura := HeroAura.new()
	player.spawn_effect(aura)
	var colour: Color = player.hero.accent_color if player.hero != null else Color(0.62, 0.87, 1.0)
	aura.attach(player, pulse_gap * float(pulse_count), &"frost", colour)
