class_name Ice extends TerrainElement
## Near-zero friction zone (DESIGN 6.2): slow redirect, no skid-stop, slightly
## raised cap, and a more forgiving b-hop window — ice is somewhere to BUILD
## speed, not only somewhere to lose control.
##
## All of that is one number on the player. The element just asserts it every
## tick a body is on the ice; the player decays it, so stepping off restores
## grip without the element having to notice.

@export var slip: float = 1.0
## Translucent on purpose: an ice sheet covers the band a body stands in, so an
## opaque fill hides both the ground texture under it and anyone standing on it.
@export var tint: Color = Color(0.18, 0.35, 0.40, 0.30)

func physics_effect(p: Player, _delta: float) -> void:
	if p.is_on_floor():
		p.apply_surface_slip(slip)

func _draw() -> void:
	var half := size * 0.5
	draw_rect(Rect2(-half, size), tint)
	# Sheen along the BOTTOM edge: the element sits a body-height above the
	# surface it makes slippery, so the bottom is where the ground actually is.
	draw_rect(Rect2(Vector2(-half.x, half.y - 3), Vector2(size.x, 3)),
		Color(0.49, 0.98, 1.0, 0.75))
	for i in int(size.x / 16.0):
		draw_rect(Rect2(Vector2(-half.x + 6 + i * 16, half.y - 9), Vector2(2, 2)),
			Color(0.64, 0.98, 0.78, 0.6))
