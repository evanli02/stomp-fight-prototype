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
