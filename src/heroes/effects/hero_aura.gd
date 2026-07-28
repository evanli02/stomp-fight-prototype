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
##   &"frost"   an active ice ultimate (Siku) — orbiting crystals and drift
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
		&"frost":
			_draw_frost(fade)

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

## Rising licks of energy off the body — taller, denser, and wider with
## intensity. Loud on purpose: an empowerment window is information both
## players need from across the stage, and the first cut of this read as a
## shimmer rather than a state.
func _draw_surge(fade: float) -> void:
	# A grounded glow ring so the state reads even when the licks are between
	# pulses — the licks say "burning", the ring says "still on".
	var breathe := 1.0 + sin(_age * 6.0) * 0.12
	draw_arc(Vector2(0.0, 4.0), 19.0 * breathe, 0.0, TAU, 28,
		Color(accent.r, accent.g, accent.b, fade * (0.4 + 0.2 * intensity)), 2.5)
	var licks := 6 + int(intensity * 3.0)
	for i in licks:
		# Deterministic per-lick wobble, no RNG: this is presentation.
		var seed_x := float((i * 37) % 13) - 6.0
		var t := fmod(_age * (1.6 + 0.13 * float(i % 3)) + float(i) * 0.29, 1.0)
		var x := seed_x * 2.4 + sin(_age * 5.0 + i) * 2.5
		var rise := (16.0 + 18.0 * intensity) * t
		var top := Vector2(x, 10.0 - rise)
		var alpha := fade * (1.0 - t) * (0.7 + 0.3 * intensity)
		# Two-tone flame: accent body with a white-hot core stroke.
		draw_line(Vector2(x, 14.0 - rise * 0.6), top,
			Color(accent.r, accent.g, accent.b, alpha), 3.0)
		draw_line(Vector2(x, 12.0 - rise * 0.55), top,
			Color(1, 1, 1, alpha * 0.45), 1.2)
		if i % 2 == 0:
			draw_circle(top, 1.6, Color(1, 1, 1, alpha * 0.8))

## Ice crystals orbiting the body plus a slow falling drift — cold where the
## surge is hot, and unmistakably "the storm is still firing".
func _draw_frost(fade: float) -> void:
	for i in 3:
		var ang := _age * 2.2 + float(i) * TAU / 3.0
		var at := Vector2(cos(ang) * 18.0, sin(ang) * 8.0 - 8.0)
		var s := 3.5 + sin(_age * 4.0 + i) * 0.8
		var pts: PackedVector2Array = [at + Vector2(0, -s), at + Vector2(s * 0.6, 0),
			at + Vector2(0, s), at + Vector2(-s * 0.6, 0)]
		draw_colored_polygon(pts, Color(accent.r, accent.g, accent.b, fade * 0.8))
		draw_circle(at, 1.0, Color(1, 1, 1, fade * 0.7))
	# Frost motes sinking off the body.
	for i in 4:
		var t := fmod(_age * 0.8 + float(i) * 0.25, 1.0)
		var x := float((i * 29) % 15) - 7.0
		draw_circle(Vector2(x, -14.0 + 30.0 * t), 1.2,
			Color(accent.r, accent.g, accent.b, fade * (1.0 - t) * 0.7))
	draw_arc(Vector2.ZERO, 21.0, 0.0, TAU, 28,
		Color(accent.r, accent.g, accent.b, fade * 0.35), 1.5)

## A steady halo — calm on purpose, the opposite read from a surge.
func _draw_ward(fade: float) -> void:
	var breathe := 1.0 + sin(_age * 3.0) * 0.06
	draw_arc(Vector2.ZERO, 20.0 * breathe, 0.0, TAU, 28,
		Color(accent.r, accent.g, accent.b, fade * 0.5), 1.5)
	draw_arc(Vector2(0.0, -24.0), 7.0, 0.0, TAU, 16,
		Color(1, 1, 1, fade * 0.55), 1.5)
