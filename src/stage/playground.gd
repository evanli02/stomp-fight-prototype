extends Node2D
## Movement test playground (M1 exit-criteria scene). Debug overlay shows state
## name, velocity, momentum_charge, dash charges, and perfect-window hit flashes
## (IMPLEMENTATION.md 10). Geometry is built in code so the shapes stay quick to
## tweak while tuning feel.

const TILE: int = Arena.TILE
## Wider than a real "Small" stage (DESIGN 6.1) on purpose: a b-hop chain needs a
## runway long enough to build and carry a capped run, which a 40-tile stage
## cannot give while also holding the wall-jump alcove.
const ARENA: Vector2i = Vector2i(60, 22)
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

## Sealed box (DESIGN 6.1) laid out so every M1 technique has somewhere to happen,
## and nothing sits in the arc of a running jump (apex puts the player's head at
## y=212, so the runway is kept clear above that):
##   - spawn ledge at the left, to run off for coyote time
##   - 592px of clear floor for b-hop chains
##   - facing pillars at the right for wall-jump chains
##   - an overhang a full-hold jump passes under but only a dash can touch
##     (ceilings reset the air dash, DESIGN 4.4). Retuned for the 34px chibi
##     body: its underside sits just above
##     the apex of a full jump and inside the reach of an up-dash taken at that
##     apex — the gap is small because the airborne up-dash is deliberately a
##     third of its old strength (DESIGN 4.3).
func _arena_blocks() -> Array[Rect2]:
	var t := float(TILE)
	var blocks := Arena.sealed_box(ARENA)
	blocks.append_array([
		Rect2(16.0, 256.0, 160.0, t),
		Rect2(768.0, 112.0, t, 224.0),
		Rect2(880.0, 112.0, t, 224.0),
		Rect2(400.0, 192.0, 96.0, t),
	])
	return blocks

func _build_arena() -> void:
	Arena.build(self, _blocks)

func _draw() -> void:
	Arena.draw(self, _blocks, TERRAIN_COLOR)

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
