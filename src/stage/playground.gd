extends Node2D
## Movement test playground (M1 exit-criteria scene). Debug overlay shows state
## name, velocity, momentum_charge, dash charges, and perfect-window hit flashes
## (IMPLEMENTATION.md 10). Geometry is built in code so the shapes stay quick to
## tweak while tuning feel.

const TILE: int = 16
const ARENA: Vector2i = Vector2i(40, 22)  ## tiles — "Small" per DESIGN 6.1
const FLASH_TIME: float = 0.35

const TERRAIN_COLOR: Color = Color(0.16, 0.18, 0.28)
const FLASH_COLOR: Color = Color(1.0, 0.85, 0.2)

@onready var player: Player = %Player
@onready var readout: Label = %Readout

var _blocks: Array[Rect2] = []
var _flash_remaining: float = 0.0
var _flash_kind: StringName = &""

func _ready() -> void:
	_blocks = _arena_blocks()
	_build_arena()
	player.perfect_window_hit.connect(_on_perfect_window_hit)
	queue_redraw()

## Sealed box (DESIGN 6.1) plus the shapes M1 needs to exercise: a long flat run
## for b-hop chains, two facing pillars for wall-jump chains, a raised platform,
## and an overhang to dash into (ceilings reset the air dash, DESIGN 4.4).
func _arena_blocks() -> Array[Rect2]:
	var w := float(ARENA.x * TILE)
	var h := float(ARENA.y * TILE)
	var t := float(TILE)
	return [
		Rect2(0.0, h - t, w, t),
		Rect2(0.0, 0.0, w, t),
		Rect2(0.0, 0.0, t, h),
		Rect2(w - t, 0.0, t, h),
		Rect2(192.0, 112.0, t, h - t - 112.0),
		Rect2(320.0, 112.0, t, h - t - 112.0),
		Rect2(416.0, 240.0, 144.0, t),
		Rect2(432.0, 144.0, 96.0, t),
	]

func _build_arena() -> void:
	for r in _blocks:
		var rect := RectangleShape2D.new()
		rect.size = r.size
		var shape := CollisionShape2D.new()
		shape.shape = rect
		var body := StaticBody2D.new()
		body.position = r.position + r.size * 0.5
		body.add_child(shape)
		add_child(body)

func _draw() -> void:
	for r in _blocks:
		draw_rect(r, TERRAIN_COLOR)

func _process(delta: float) -> void:
	# Overlay only — no gameplay logic outside the physics tick (CLAUDE.md).
	_flash_remaining = maxf(_flash_remaining - delta, 0.0)
	readout.text = _debug_text()
	readout.modulate = FLASH_COLOR if _flash_remaining > 0.0 else Color.WHITE

func _debug_text() -> String:
	var lines: Array[String] = [
		"state      %s" % player.state_machine.state_name(),
		"velocity   %6.1f, %6.1f" % [player.velocity.x, player.velocity.y],
		"momentum   %.2f   cap %.0f" % [player.momentum_charge, player.speed_cap()],
		"dash       %d/%d%s" % [
			player.dash_charges_left,
			player.movement.dash_charges,
			"  AIR-LOCKED" if player.air_dash_locked else "",
		],
		"wall chain %d" % player.wall_jump_chain,
		"coyote %.2f  buffer %.2f" % [player.coyote_remaining, player.jump_buffer_remaining],
		"perfect    %s" % (String(_flash_kind) if _flash_remaining > 0.0 else "-"),
	]
	return "\n".join(lines)

func _on_perfect_window_hit(kind: StringName) -> void:
	_flash_kind = kind
	_flash_remaining = FLASH_TIME
