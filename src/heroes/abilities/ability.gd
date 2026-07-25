class_name Ability extends Node
## Base ability component. Instanced into the Player's AbilitySlot on swap.
## Abilities interact with the game ONLY via player public API and by spawning
## self-contained effect scenes. Abilities can NEVER remove a life (CLAUDE.md 1).
##
## Cooldowns are PER HERO and keep ticking while the hero is benched
## (DESIGN 2.4) — cooldown state therefore lives in a per-player registry keyed
## by hero id, not on this (freed on swap) node. TODO(M3): CooldownLedger.

signal fired
signal cooldown_started(duration: float)

@export var is_ultimate: bool = false
var player: Player
var hero_id: StringName
var cooldown: float = 8.0

func try_fire(aim: Vector2) -> bool:
	if is_ultimate:
		# One ult per player per round, spent via MatchState (IMPLEMENTATION.md 5).
		if not MatchState.try_spend_ultimate(player.player_id):
			return false
	elif _on_cooldown():
		return false
	_execute(aim)
	fired.emit()
	if not is_ultimate:
		_start_cooldown()
	return true

## Override in subclasses. `aim` is the live aim vector (DESIGN 7).
func _execute(_aim: Vector2) -> void:
	pass

func _on_cooldown() -> bool:
	return false # TODO(M3): read CooldownLedger

func _start_cooldown() -> void:
	cooldown_started.emit(cooldown) # TODO(M3): write CooldownLedger
