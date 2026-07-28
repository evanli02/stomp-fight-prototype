class_name HeroAura extends Node2D
## A visual aura that rides a player for a duration — the on-body read for
## "something is active on this hero". Purely cosmetic: it never touches
## gameplay, it just follows the body and draws.
##
## Styles are named so every buff window in the game can share one effect
## instead of each kit growing its own follower node:
##   &"wind"    Fei's Tailwind — jade gusts circling the body
##   &"surge"   an empowerment (Voodoo's kits, Saint's ultimate) — rising
##              flame-like licks; menace scales with `intensity`
##   &"ward"    a protective blessing (Saint) — a soft steady halo ring
##
## Parented to the stage like every effect (spawn_effect), so it FOLLOWS the
## player rather than riding as a child — same pattern as the grapple rope. It
## frees itself when the duration runs out or the body disappears.

var target: Player = null
var duration: float = 1.0
var accent: Color = Color.WHITE
var style: StringName = &"wind"
## 1.0 = ability-grade. An ultimate aura passes more and reads bigger/angrier.
var intensity: float = 1.0
## Optional early-out. Some windows can end before their clock does — Saint's
## blessing is spent the moment a stomp is absorbed — and an aura still glowing
## over an unprotected body is worse than no aura at all.
var expire_when: Callable = Callable()

var _age: float = 0.0

func attach(to: Player, for_seconds: float, aura_style: StringName,
		colour: Color, strength: float = 1.0) -> void:
	target = to
	duration = for_seconds
	style = aura_style
	accent = colour
	intensity = strength
	z_index = 6  # over the body, under the overlays

func _process(delta: float) -> void:
	_age += delta
	if _age >= duration or target == null or not is_instance_valid(target):
		queue_free()
		return
	if expire_when.is_valid() and expire_when.call():
		queue_free()
		return
	global_position = target.global_position
	queue_redraw()

func _draw() -> void:
	# Ease out over the last half second so the window visibly closes.
	var fade: float = clampf((duration - _age) / 0.5, 0.0, 1.0)
	match style:
		&"wind":
			_draw_wind(fade)
		&"surge":
			_draw_surge(fade)
		&"ward":
			_draw_ward(fade)

## Gusts circling the body — three short arcs orbiting at different heights.
func _draw_wind(fade: float) -> void:
	for i in 3:
		var phase := _age * (3.0 + i * 0.7) + i * TAU / 3.0
		var y := -14.0 + i * 12.0 + sin(_age * 2.0 + i) * 3.0
		var sweep := 1.6
		draw_arc(Vector2(0.0, y), 16.0 + i * 2.0, phase, phase + sweep, 10,
			Color(accent.r, accent.g, accent.b, fade * 0.55), 1.5)
		draw_arc(Vector2(0.0, y), 16.0 + i * 2.0, phase + sweep * 0.6,
			phase + sweep * 0.9, 6, Color(1, 1, 1, fade * 0.35), 1.0)

## Rising licks of energy off the body — taller and denser with intensity.
func _draw_surge(fade: float) -> void:
	var licks := 4 + int(intensity * 2.0)
	for i in licks:
		# Deterministic per-lick wobble, no RNG: this is presentation.
		var seed_x := float((i * 37) % 11) - 5.0
		var t := fmod(_age * (1.4 + 0.13 * float(i % 3)) + float(i) * 0.31, 1.0)
		var x := seed_x * 2.2 + sin(_age * 5.0 + i) * 2.0
		var rise := (10.0 + 14.0 * intensity) * t
		var top := Vector2(x, 8.0 - rise)
		var alpha := fade * (1.0 - t) * (0.5 + 0.25 * intensity)
		draw_line(Vector2(x, 12.0 - rise * 0.6), top,
			Color(accent.r, accent.g, accent.b, alpha), 2.0)
		if i % 2 == 0:
			draw_circle(top, 1.2, Color(1, 1, 1, alpha * 0.7))

## A steady halo — calm on purpose, the opposite read from a surge.
func _draw_ward(fade: float) -> void:
	var breathe := 1.0 + sin(_age * 3.0) * 0.06
	draw_arc(Vector2.ZERO, 20.0 * breathe, 0.0, TAU, 28,
		Color(accent.r, accent.g, accent.b, fade * 0.5), 1.5)
	draw_arc(Vector2(0.0, -24.0), 7.0, 0.0, TAU, 16,
		Color(1, 1, 1, fade * 0.55), 1.5)
