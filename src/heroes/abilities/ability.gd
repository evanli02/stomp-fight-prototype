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
## Opt out of the "no casting while stunned" rule (Saint, whose entire point is
## casting his way out of trouble). Disrupt (Kid's EMP) and sleep (Vesper) are
## NOT bypassable by anyone — see Player._can_cast. Default false, because for
## every other hero a stun is meant to be a real interruption.
@export var fires_while_stunned: bool = false
var player: Player
var hero_id: StringName
var cooldown: float = 8.0

## Temporary replacement cooldown granted by an ultimate (Skyla's). While the
## window runs, firing costs this instead of the hero's normal cooldown.
var cooldown_override: float = -1.0
var cooldown_override_remaining: float = 0.0

func _physics_process(delta: float) -> void:
	if cooldown_override_remaining > 0.0:
		cooldown_override_remaining = maxf(cooldown_override_remaining - delta, 0.0)
		if cooldown_override_remaining <= 0.0:
			cooldown_override = -1.0

## Ultimates call this on their sibling basic ability.
func grant_cooldown_override(value: float, duration: float) -> void:
	cooldown_override = value
	cooldown_override_remaining = maxf(cooldown_override_remaining, duration)

func effective_cooldown() -> float:
	return cooldown_override if cooldown_override_remaining > 0.0 else cooldown

## Clear the cooldown outright (Deadeye's ultimate).
func reset_cooldown() -> void:
	if MatchState.has_player(player.player_id):
		MatchState.start_cooldown(player.player_id, hero_id, 0.0)

func try_fire(aim: Vector2) -> bool:
	if not _can_fire():
		return false  # refused before anything is spent (e.g. Slam on the ground)
	if is_ultimate:
		# Spent via MatchState, which owns the per-round budget and the gap
		# between uses (IMPLEMENTATION.md 5).
		# A free recast (Slip placing her second teleporter) is part of the SAME
		# activation and spends nothing.
		if not _is_free_recast() and not MatchState.try_spend_ultimate(player.player_id):
			return false
	elif _on_cooldown():
		return false
	_execute(aim)
	Audio.play(&"ultimate" if is_ultimate else &"ability", 0.9)
	fired.emit()
	if not is_ultimate and _cooldown_after_fire():
		_start_cooldown()
	return true

## Overridable gates for multi-stage abilities.
func _can_fire() -> bool: return true
func _cooldown_after_fire() -> bool: return true
func _is_free_recast() -> bool: return false

## Override in subclasses. `aim` is the live aim vector (DESIGN 7).
func _execute(_aim: Vector2) -> void:
	pass

func _on_cooldown() -> bool:
	if not MatchState.has_player(player.player_id):
		return false  # debug scenes with unregistered bodies
	return not MatchState.is_ability_ready(player.player_id, hero_id)

func _start_cooldown() -> void:
	var value := effective_cooldown()
	if MatchState.has_player(player.player_id):
		MatchState.start_cooldown(player.player_id, hero_id, value)
	cooldown_started.emit(value)

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
