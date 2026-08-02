extends CanvasLayer
## Every hero's tunables on one scrollable page, for balance work.
##
## The numbers are read off the real ability scenes at runtime — each hero's
## ability and ultimate are instantiated, their `@export`s enumerated, and shown
## with whatever value the scene actually carries. Nothing here is transcribed,
## so this page cannot drift out of date the way a hand-written table would; add
## an export to an ability and it appears here on the next open.
##
## What it deliberately does NOT show: constants baked into effect scripts
## (FractureWave.HALF_WIDTH and friends). Those are not `@export`s, and quietly
## listing them would suggest they can be tuned from here. The footer says where
## they live instead.

signal closed()

const NAV_REPEAT: float = 0.09
const NAV_DEADZONE: float = 0.5
const SCROLL_STEP: float = 26.0

const COL_BG: Color = Color(0.05, 0.03, 0.09, 0.96)
const COL_PANEL: Color = Color(0.09, 0.06, 0.15)
const COL_FRAME: Color = Color(0.30, 0.30, 0.42)
const COL_TEXT: Color = Color(0.96, 0.96, 0.98)
const COL_DIM: Color = Color(0.52, 0.52, 0.62)
const COL_VALUE: Color = Color(0.98, 0.86, 0.45)

const MARGIN: float = 40.0
const ROW: float = 15.0
const CARD_GAP: float = 10.0

var _canvas: Control
## One entry per hero: name, accent, cooldown, and the two kits' exports.
var _rows: Array = []
var _scroll: float = 0.0
var _max_scroll: float = 0.0
var _nav_cooldown: float = 0.0

func _ready() -> void:
	_build()
	_canvas = Control.new()
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_canvas)
	_canvas.draw.connect(_draw_screen)

## Instantiate each kit once, read its exports, throw it away. The nodes are
## never added to the tree — an Ability with no player would crash if it ticked,
## and all this needs is the property list.
func _build() -> void:
	for id in GameManager.roster_ids():
		var data := GameManager.hero_data(id)
		if data == null:
			continue
		_rows.append({
			"id": id,
			"name": data.hero_name,
			"accent": data.accent_color,
			"cooldown": data.ability_cooldown,
			"ability": _params_of(data.ability_scene),
			"ultimate": _params_of(data.ultimate_scene),
			"ability_text": data.ability_text,
			"ultimate_text": data.ultimate_text,
		})

## `[[name, value], ...]` for one kit's exported tunables, in declaration order.
## `is_ultimate` and `fires_while_stunned` are wiring rather than balance, so
## they are dropped — a page full of "is_ultimate: true" teaches nothing.
func _params_of(scene: PackedScene) -> Array:
	var out: Array = []
	if scene == null:
		return out
	var node := scene.instantiate()
	out.append(["script", node.get_script().resource_path.get_file().get_basename()])
	for prop in node.get_property_list():
		if not (prop.usage & PROPERTY_USAGE_SCRIPT_VARIABLE):
			continue
		if not (prop.usage & PROPERTY_USAGE_EDITOR):
			continue
		var name: String = prop.name
		if name in ["is_ultimate", "fires_while_stunned"]:
			continue
		out.append([name, node.get(name)])
	node.free()
	return out

func _physics_process(delta: float) -> void:
	var frame := InputConfig.poll(0)
	_nav_cooldown = maxf(_nav_cooldown - delta, 0.0)
	if absf(frame.move.y) < NAV_DEADZONE:
		_nav_cooldown = 0.0
	elif _nav_cooldown <= 0.0:
		_scroll = clampf(_scroll + signf(frame.move.y) * SCROLL_STEP, 0.0, _max_scroll)
		_nav_cooldown = NAV_REPEAT
	if frame.swap_pressed or Input.is_key_pressed(KEY_ESCAPE):
		closed.emit()
	_canvas.queue_redraw()

#region Drawing
func _draw_screen() -> void:
	var font := ThemeDB.fallback_font
	var size := _canvas.size
	_canvas.draw_rect(Rect2(Vector2.ZERO, size), COL_BG)

	# Two columns, so twelve heroes fit in about two screens instead of six.
	var col_w := (size.x - MARGIN * 2.0 - CARD_GAP) * 0.5
	var y: Array = [92.0 - _scroll, 92.0 - _scroll]
	for row: Dictionary in _rows:
		# Always fill the shorter column, so the two stay level regardless of how
		# many exports a kit happens to have.
		var col := 0 if y[0] <= y[1] else 1
		var at := Vector2(MARGIN + col * (col_w + CARD_GAP), y[col])
		y[col] += _draw_hero(font, row, at, col_w) + CARD_GAP
	_max_scroll = maxf(maxf(y[0], y[1]) + _scroll - size.y + 60.0, 0.0)

	# Header and footer are drawn last so scrolled content passes behind them.
	_canvas.draw_rect(Rect2(Vector2.ZERO, Vector2(size.x, 84)), COL_BG)
	_shadowed(font, Vector2(MARGIN, 46), "BALANCE SHEET", 26, COL_TEXT)
	_shadowed(font, Vector2(MARGIN, 68),
		"live values, read off the ability scenes — edit them in src/heroes/abilities/*.gd "
		+ "and src/heroes/resources/*.tres", 12, COL_DIM)
	_canvas.draw_rect(Rect2(Vector2(0, size.y - 34), Vector2(size.x, 34)), COL_BG)
	_shadowed(font, Vector2(MARGIN, size.y - 14),
		"up/down scrolls   ·   swap/RMB or ESC goes back   ·   "
		+ "effect constants (blast radii, wave widths) live in src/heroes/effects/*.gd",
		12, COL_DIM)
	if _max_scroll > 0.0:
		var frac := _scroll / _max_scroll
		_canvas.draw_rect(Rect2(size.x - 8.0, 84.0 + frac * (size.y - 160.0),
			4.0, 60.0), COL_FRAME)

## Returns the height it used, so the caller can stack the next card.
func _draw_hero(font: Font, row: Dictionary, at: Vector2, w: float) -> float:
	var accent: Color = row["accent"]
	var lines: int = row["ability"].size() + row["ultimate"].size()
	var h := 62.0 + lines * ROW + ROW   # header + params + the two section labels
	_canvas.draw_rect(Rect2(at, Vector2(w, h)), COL_PANEL)
	_canvas.draw_rect(Rect2(at, Vector2(w, 4)), accent)
	_canvas.draw_rect(Rect2(at, Vector2(w, h)), COL_FRAME, false, 1.0)

	_shadowed(font, at + Vector2(10, 26), row["name"], 18, COL_TEXT)
	_shadowed(font, at + Vector2(w - 96, 26),
		"CD %.1fs" % row["cooldown"], 13, accent)

	var y := 46.0
	_shadowed(font, at + Vector2(10, y), "ABILITY", 11, COL_DIM)
	y += ROW
	y = _draw_params(font, row["ability"], at, w, y)
	_shadowed(font, at + Vector2(10, y + 2), "ULTIMATE", 11, COL_DIM)
	y += ROW
	y = _draw_params(font, row["ultimate"], at, w, y)
	return h

func _draw_params(font: Font, params: Array, at: Vector2, w: float, y: float) -> float:
	for entry: Array in params:
		var name: String = entry[0]
		var value: Variant = entry[1]
		_shadowed(font, at + Vector2(20, y), name, 12, COL_DIM)
		var text := _format(value)
		var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
		_shadowed(font, at + Vector2(w - 12 - tw, y), text, 12,
			COL_TEXT if name == "script" else COL_VALUE)
		y += ROW
	return y

func _format(value: Variant) -> String:
	if value is float:
		return "%.3f" % value if absf(value) < 1.0 else "%.2f" % value
	if value is Vector2:
		return "%.0f x %.0f" % [value.x, value.y]
	return str(value)

func _shadowed(font: Font, at: Vector2, msg: String, size: int, col: Color) -> void:
	_canvas.draw_string(font, at + Vector2(1, 1), msg, HORIZONTAL_ALIGNMENT_LEFT, -1, size,
		Color(0, 0, 0, 0.85))
	_canvas.draw_string(font, at, msg, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)
#endregion
