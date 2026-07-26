class_name Ability extends Node
## Base ability component. Instanced into the Player's AbilitySlot on swap.
## Abilities interact with the game ONLY via player public API and by spawning
## self-contained effect scenes. Abilities can NEVER remove a life (CLAUDE.md 1)
## — they stun, push, launch, and build, and that is the whole vocabulary.
##
## Cooldowns are PER HERO and keep ticking while the hero is benched
## (DESIGN 2.4) — cooldown state therefore lives in MatchState, keyed by player
## and hero, not on this node, which is freed the moment its hero is swapped out.

signal fired
signal cooldown_started(duration: float)

@export var is_ultimate: bool = false
var player: Player
var hero_id: StringName
var cooldown: float = 8.0

## Cooldown waiver granted by an ultimate that modifies the basic ability
## (Deadeye's Rapid Fire, Skyla's Double Trouble). Both are "the cooldown does
## not apply for a while", differing only in how many uses they cover, so one
## mechanism serves both rather than two special cases.
var waive_remaining: float = 0.0
var waive_uses: int = 0

func _physics_process(delta: float) -> void:
	if waive_remaining > 0.0:
		waive_remaining = maxf(waive_remaining - delta, 0.0)
		if waive_remaining <= 0.0:
			waive_uses = 0

## Ultimates call this on their sibling basic ability.
func grant_waiver(duration: float, uses: int) -> void:
	waive_remaining = maxf(waive_remaining, duration)
	waive_uses = maxi(waive_uses, uses)

func waived() -> bool:
	return waive_remaining > 0.0 and waive_uses > 0

func try_fire(aim: Vector2) -> bool:
	if is_ultimate:
		# One ult per player per round, spent via MatchState (IMPLEMENTATION.md 5).
		if not MatchState.try_spend_ultimate(player.player_id):
			return false
	elif _on_cooldown() and not waived():
		return false
	_execute(aim)
	fired.emit()
	if not is_ultimate:
		if waived():
			waive_uses -= 1
		else:
			_start_cooldown()
	return true

## Override in subclasses. `aim` is the live aim vector (DESIGN 7).
func _execute(_aim: Vector2) -> void:
	pass

func _on_cooldown() -> bool:
	if not MatchState.has_player(player.player_id):
		return false  # debug scenes with unregistered bodies
	return not MatchState.is_ability_ready(player.player_id, hero_id)

func _start_cooldown() -> void:
	if MatchState.has_player(player.player_id):
		MatchState.start_cooldown(player.player_id, hero_id, cooldown)
	cooldown_started.emit(cooldown)

#region Shared helpers
## Every player in the round, in player_id order. Sorted rather than taken in
## scene order so an ability that hits several targets resolves the same way
## every run (IMPLEMENTATION.md 9).
func all_players() -> Array:
	var out := get_tree().get_nodes_in_group(&"players")
	out.sort_custom(func(a: Player, b: Player) -> bool: return a.player_id < b.player_id)
	return out

func enemies_of(who: Player) -> Array:
	return all_players().filter(func(p: Player) -> bool: return p.team_id != who.team_id)

## Aim, falling back to facing so a neutral stick still fires somewhere sane.
func aim_or_facing(aim: Vector2) -> Vector2:
	return aim.normalized() if aim.length() > 0.1 else Vector2(float(player.facing), 0.0)
#endregion
