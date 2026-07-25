class_name TerrainElement extends Node2D
## Contract for all stage terrain elements (IMPLEMENTATION.md 4, DESIGN 6.2).
## Elements are self-contained scenes that act on players ONLY through the
## Player public API. Terrain can stun/push/launch — it can NEVER remove a life
## (CLAUDE.md rule 1) and stages are sealed (rule 2).

func on_body_entered(_player: Player) -> void: pass
func on_body_exited(_player: Player) -> void: pass
## Continuous effects while overlapping (wind, ice, conveyor).
func physics_effect(_player: Player, _delta: float) -> void: pass
