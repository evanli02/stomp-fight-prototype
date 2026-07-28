class_name SaintCleanse extends Ability
## Saint — Cleanse (docs/NEW_HEROES.md §Saint). SKELETON.
##
## Removes every debuff and stun from Saint and every living ally: stun, slow,
## impair, disrupt, freeze, sleep and sleep stacks (Vesper), the lot — plus the
## debuff badges that go with them. Range: the whole stage; Cleanse is a
## decision about timing, not positioning.
##
## The cast gate is the novel part: Cleanse can be fired WHILE stunned or
## debuffed — the whole point is casting it out of trouble — EXCEPT under
## Kid's EMP, which locks abilities and is explicitly the counter that still
## works on Saint. Player.try_ability refuses while stunned or disrupted for
## everyone, so Saint needs the bypass flag on the ability
## (fires_while_stunned, honoured by try_ability; disrupt is still honoured).

func _can_fire() -> bool:
	# TODO(opus): return true even while player.stun_remaining > 0 — the
	# stunned gate lives in Player.try_ability, which needs the
	# fires_while_stunned escape hatch (NEW_HEROES.md §API). Disrupt (EMP)
	# already blocks in try_ability and MUST keep blocking.
	return true

func _execute(_aim: Vector2) -> void:
	# TODO(opus): implement per docs/NEW_HEROES.md §Saint —
	#  for Saint and each living ally: clear_all_debuffs() [new API: stun,
	#  slow, impair, disrupt, freeze, sleep, stacks, tags — NOT grace, NOT
	#  spawn protection, and it never touches lives or position], plus a brief
	#  white flash effect on each cleansed body.
	push_warning("Cleanse is a skeleton — see docs/NEW_HEROES.md")
