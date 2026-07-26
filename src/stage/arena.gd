class_name Arena extends RefCounted
## Sealed-box geometry for the debug stages (playground, duel). Real stages are
## TileMap + placed terrain scenes (IMPLEMENTATION.md 1); these two build their
## collision in code so the layout stays a list of rectangles you can retune
## between runs without opening the editor.
##
## Stages built with this are sealed by construction — there is no pit and no
## out-of-bounds, which is a hard rule, not a convenience (DESIGN 6.1).

const TILE: int = 16

## Floor, ceiling, and both side walls for an arena of the given tile size.
static func sealed_box(size_tiles: Vector2i) -> Array[Rect2]:
	var w := float(size_tiles.x * TILE)
	var h := float(size_tiles.y * TILE)
	var t := float(TILE)
	return [
		Rect2(0.0, h - t, w, t),
		Rect2(0.0, 0.0, w, t),
		Rect2(0.0, 0.0, t, h),
		Rect2(w - t, 0.0, t, h),
	]

## One StaticBody2D per rectangle, parented to the host.
static func build(host: Node2D, blocks: Array[Rect2]) -> void:
	for r in blocks:
		var rect := RectangleShape2D.new()
		rect.size = r.size
		var shape := CollisionShape2D.new()
		shape.shape = rect
		var body := StaticBody2D.new()
		body.position = r.position + r.size * 0.5
		body.add_child(shape)
		host.add_child(body)

## Call from the host's _draw(): terrain has no art in the debug stages.
static func draw(host: CanvasItem, blocks: Array[Rect2], color: Color) -> void:
	for r in blocks:
		host.draw_rect(r, color)

## Tile a 16px texture across each block, with a lit cap row along the top edge
## so a surface reads as standable at a glance. Cheaper than a TileMap and keeps
## the geometry a plain list of rectangles, which is what the harnesses assert
## against — real stages move to TileMaps in M5.
static func draw_tiled(host: CanvasItem, blocks: Array[Rect2], tex: Texture2D,
		cap: Color = Color(0.63, 0.24, 0.47)) -> void:
	var t := float(TILE)
	for r in blocks:
		var cols := int(ceil(r.size.x / t))
		var rows := int(ceil(r.size.y / t))
		for row in rows:
			for col in cols:
				var at := Vector2(r.position.x + col * t, r.position.y + row * t)
				# Clip the last row/column so an odd-sized block does not bleed.
				var w := minf(t, r.position.x + r.size.x - at.x)
				var h := minf(t, r.position.y + r.size.y - at.y)
				host.draw_texture_rect_region(tex, Rect2(at, Vector2(w, h)),
					Rect2(Vector2.ZERO, Vector2(w, h)))
		host.draw_rect(Rect2(r.position, Vector2(r.size.x, 2)), cap)

## Four-band dusk sky behind everything (STYLE_GUIDE: dusk key, night palette).
static func draw_sky(host: CanvasItem, size: Vector2, bands: Array[Color]) -> void:
	var band_h := size.y / bands.size()
	for i in bands.size():
		host.draw_rect(Rect2(0.0, i * band_h, size.x, band_h + 1.0), bands[i])
