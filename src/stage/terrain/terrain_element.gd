class_name TerrainElement extends Node2D
## Contract for all stage terrain elements (IMPLEMENTATION.md 4, DESIGN 6.2).
## Elements are self-contained scenes that act on players ONLY through the
## Player public API. Terrain can stun/push/launch — it can NEVER remove a life
## (CLAUDE.md rule 1) and stages are sealed (rule 2).
##
## The base owns detection so elements only write behaviour. Overlaps are
## re-scanned every physics tick rather than driven by body_entered/exited: a
## player already inside an area cannot "enter" it again, and several elements
## (ice, wind, poles) care about bodies sitting still inside them. The base
## still synthesises clean enter/exit calls out of the scan.

## Footprint of the trigger area, in pixels.
@export var size: Vector2 = Vector2(32, 32)
## Set false for elements that provide their own detection.
@export var auto_area: bool = true

var _area: Area2D
var _inside: Dictionary = {}       # instance id -> Player

func _ready() -> void:
	if not auto_area:
		return
	_area = Area2D.new()
	_area.collision_layer = 0
	_area.collision_mask = 2       # player bodies
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	_area.add_child(shape)
	add_child(_area)

func _physics_process(delta: float) -> void:
	if _area != null:
		_scan(delta)
	tick(delta)

func _scan(delta: float) -> void:
	var seen := {}
	var bodies := _area.get_overlapping_bodies()
	# Sorted so multi-player overlaps resolve identically every run (§9).
	bodies.sort_custom(func(a: Node2D, b: Node2D) -> bool:
		return a.get_instance_id() < b.get_instance_id())
	for body in bodies:
		var p := body as Player
		if p == null:
			continue
		var id := p.get_instance_id()
		seen[id] = true
		if not _inside.has(id):
			_inside[id] = p
			on_body_entered(p)
		physics_effect(p, delta)
	for id in _inside.keys():
		if not seen.has(id):
			var gone: Player = _inside[id]
			_inside.erase(id)
			if is_instance_valid(gone):
				on_body_exited(gone)

## Players currently overlapping, in a stable order.
func bodies_inside() -> Array:
	var out: Array = _inside.values()
	out.sort_custom(func(a: Player, b: Player) -> bool: return a.player_id < b.player_id)
	return out

#region Override these
func on_body_entered(_player: Player) -> void: pass
func on_body_exited(_player: Player) -> void: pass
## Continuous effects while overlapping (wind, ice, conveyor).
func physics_effect(_player: Player, _delta: float) -> void: pass
## Free-running logic that needs no body (explosion timers).
func tick(_delta: float) -> void: pass
#endregion
