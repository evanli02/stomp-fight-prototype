class_name SaintCleanse extends Ability
## Saint — Cleanse (docs/NEW_HEROES.md §Saint).
##
## Removes every debuff and stun from Saint and every ally: stun, slow, impair,
## disrupt, freeze, sleep and sleep stacks, badges and all. Stage-wide and
## instant — no aim, no range. The skill is timing; the counterplay is baiting
## the cast, or locking it out.
##
## The novel part is the gate. Cleanse fires WHILE stunned — casting his way out
## of trouble is the whole hero — which is what `fires_while_stunned` on the
## scene buys. Kid's EMP still blocks it, and so does being asleep: those two
## are the sanctioned answers to a hero who undoes everything else, and
## Player._can_cast refuses them for everybody, Saint included.

func allies_including_self() -> Array:
	return all_players().filter(func(p: Player) -> bool: return p.team_id == player.team_id)

func _execute(_aim: Vector2) -> void:
	for t in allies_including_self():
		var ally := t as Player
		ally.clear_all_debuffs()
		var flash := CleanseFlash.new()
		flash.global_position = ally.global_position
		if player.hero != null:
			flash.accent = player.hero.accent_color
		player.spawn_effect(flash)
