class_name FeiDoubleTrouble extends Ability
## Fei's ultimate (DESIGN 5.2 #2): for a window, her jump comes back almost
## immediately. Not free — a 1s cooldown still paces it — but close enough to
## chain jumps across the whole stage.

@export var duration: float = 8.0
@export var reduced_cooldown: float = 0.3

func _execute(_aim: Vector2) -> void:
	var basic := player.equipped_ability()
	if basic != null:
		basic.grant_cooldown_override(reduced_cooldown, duration)
		basic.reset_cooldown()   # the window starts now, not after the current wait
	# The aura is the on-body read for "the window is open" — for both players.
	# Purely visual; the window itself lives in the cooldown override above.
	var aura := HeroAura.new()
	var colour: Color = player.hero.accent_color if player.hero != null else Color.WHITE
	player.spawn_effect(aura)
	aura.attach(player, duration, &"wind", colour)
