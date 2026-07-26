extends Node
## InputConfig — registers all input actions in code (kept out of project.godot so
## bindings are documented, rebindable, and diff-friendly). Also owns per-player
## device assignment, the R2+L2 ultimate chord resolver, and the shared aim-vector
## provider (DESIGN 7).
##
## Actions are namespaced per player slot ("p0_jump", "p1_jump", …) so two local
## players can hold different devices. Use action() rather than writing the
## namespaced names by hand.

enum Device { KBM, PAD }

## Local seats. 2v2/3v3 are online-or-more-pads formats; local play is two seats
## until the lobby exists (M6).
const MAX_LOCAL_PLAYERS: int = 2
const CHORD_WINDOW: float = 0.1  ## seconds for R2+L2 ultimate simultaneity

## Base action names; every slot gets its own namespaced copy of each.
const ACTIONS: Array[StringName] = [
	&"move_left", &"move_right", &"move_up", &"move_down",
	&"jump", &"dash", &"ability", &"swap", &"ultimate",
	&"aim_up", &"aim_down", &"aim_left", &"aim_right",
]

var _device_of: Dictionary = {}      # player_id -> Device
## player_id -> { dash: int, swap: int } physics frame each press is parked on
## while we wait to see whether it is half of a chord. -1 means nothing pending.
var _chord_pending: Dictionary = {}
## player_id -> { frame: int, frame_data: InputFrame }; one poll per player per
## tick, so a second caller in the same frame gets the same answer.
var _poll_cache: Dictionary = {}

func _ready() -> void:
	for slot in MAX_LOCAL_PLAYERS:
		# Seat 0 is mouse and keyboard, seat 1 is the first controller. Rebinding
		# UI (and user://input.cfg persistence, DESIGN 7) lands with the lobby in M6.
		assign_device(slot, Device.KBM if slot == 0 else Device.PAD)

#region Device assignment
## Point a player slot at a device and rebuild its bindings.
func assign_device(player_id: int, device: Device) -> void:
	_device_of[player_id] = device
	_chord_pending[player_id] = { &"dash": -1, &"swap": -1 }
	_poll_cache.erase(player_id)
	_register_actions(player_id, device)

func device_of(player_id: int) -> Device:
	return _device_of.get(player_id, Device.KBM)

## The namespaced action name for a slot, e.g. action(1, &"jump") -> "p1_jump".
func action(player_id: int, base: StringName) -> StringName:
	return StringName("p%d_%s" % [player_id, base])

func _register_actions(player_id: int, device: Device) -> void:
	for base in ACTIONS:
		var name := action(player_id, base)
		if InputMap.has_action(name):
			InputMap.erase_action(name)
		InputMap.add_action(name)
		for event in (_kbm_events(base) if device == Device.KBM else _pad_events(base)):
			InputMap.action_add_event(name, event)

## KBM bindings (DESIGN 7). Aim is the mouse cursor, so the aim_* actions are
## intentionally unbound here — aim_vector() reads the pointer instead.
func _kbm_events(base: StringName) -> Array:
	match base:
		&"move_left": return [_key(KEY_A)]
		&"move_right": return [_key(KEY_D)]
		&"move_up": return [_key(KEY_W)]
		&"move_down": return [_key(KEY_S)]
		&"jump": return [_key(KEY_SPACE)]
		&"dash": return [_key(KEY_SHIFT)]
		&"ability": return [_mouse(MOUSE_BUTTON_LEFT)]
		&"swap": return [_mouse(MOUSE_BUTTON_RIGHT)]
		&"ultimate": return [_key(KEY_E)]
	return []

## Controller bindings (DESIGN 7). There is no ultimate button: it is the R2+L2
## chord, resolved in poll().
## TODO(M6): filter by joypad device index so a third and fourth pad can be told
## apart; today every pad drives the pad seat.
func _pad_events(base: StringName) -> Array:
	match base:
		&"move_left": return [_axis(JOY_AXIS_LEFT_X, -1.0)]
		&"move_right": return [_axis(JOY_AXIS_LEFT_X, 1.0)]
		&"move_up": return [_axis(JOY_AXIS_LEFT_Y, -1.0)]
		&"move_down": return [_axis(JOY_AXIS_LEFT_Y, 1.0)]
		&"jump": return [_joy(JOY_BUTTON_RIGHT_SHOULDER)]      # R1
		&"dash": return [_axis(JOY_AXIS_TRIGGER_RIGHT, 1.0)]   # R2
		&"ability": return [_joy(JOY_BUTTON_LEFT_SHOULDER)]    # L1
		&"swap": return [_axis(JOY_AXIS_TRIGGER_LEFT, 1.0)]    # L2
		&"aim_up": return [_axis(JOY_AXIS_RIGHT_Y, -1.0)]
		&"aim_down": return [_axis(JOY_AXIS_RIGHT_Y, 1.0)]
		&"aim_left": return [_axis(JOY_AXIS_RIGHT_X, -1.0)]
		&"aim_right": return [_axis(JOY_AXIS_RIGHT_X, 1.0)]
	return []
#endregion

#region Polling
## Sample one player's intent for this physics tick. All gameplay reads inputs
## through here, never through Input directly (IMPLEMENTATION.md 9).
func poll(player_id: int, body: Node2D) -> InputFrame:
	var now := Engine.get_physics_frames()
	var cached: Dictionary = _poll_cache.get(player_id, {})
	if cached.get("frame", -1) == now:
		return cached["input"]  # the chord resolver may only advance once a tick

	var frame := InputFrame.new()
	frame.move = Input.get_vector(
		action(player_id, &"move_left"), action(player_id, &"move_right"),
		action(player_id, &"move_up"), action(player_id, &"move_down"))
	frame.aim = aim_vector(player_id, body.global_position, body.get_viewport())
	frame.jump_pressed = Input.is_action_just_pressed(action(player_id, &"jump"))
	frame.jump_held = Input.is_action_pressed(action(player_id, &"jump"))
	frame.ability_pressed = Input.is_action_just_pressed(action(player_id, &"ability"))

	var dash := Input.is_action_just_pressed(action(player_id, &"dash"))
	var swap := Input.is_action_just_pressed(action(player_id, &"swap"))
	var ult := Input.is_action_just_pressed(action(player_id, &"ultimate"))
	if device_of(player_id) == Device.PAD:
		var resolved := _resolve_chord(player_id, dash, swap, now)
		dash = resolved[&"dash"]
		swap = resolved[&"swap"]
		ult = resolved[&"ultimate"]
	frame.dash_pressed = dash
	frame.swap_pressed = swap
	frame.ultimate_pressed = ult

	_poll_cache[player_id] = { "frame": now, "input": frame }
	return frame

## Live aim vector: right stick on pad, mouse (relative to player) on KBM.
## Feeds abilities only — movement (dash direction, wall-jump tilt) is steered by
## the movement input, never by aim (DESIGN 4.3, 4.4).
##
## The aim_* actions are checked first for BOTH devices. On a pad they are the
## right stick; on KBM they ship unbound, which leaves a directional-aim channel
## for a rebind (accessibility) and lets the headless harnesses pin an exact aim
## instead of measuring wherever the absent mouse pointer happens to be.
func aim_vector(player_id: int, player_global_pos: Vector2, viewport: Viewport) -> Vector2:
	var explicit := Input.get_vector(
		action(player_id, &"aim_left"), action(player_id, &"aim_right"),
		action(player_id, &"aim_up"), action(player_id, &"aim_down"))
	if explicit.length() > 0.2:
		return explicit.normalized()
	if device_of(player_id) == Device.PAD:
		return Vector2.ZERO
	var camera := viewport.get_camera_2d()
	var mouse := camera.get_global_mouse_position() if camera else viewport.get_mouse_position()
	return (mouse - player_global_pos).normalized()

## R2+L2 = ultimate on a controller (DESIGN 7). Both halves are parked for
## CHORD_WINDOW before firing as dash/swap, because the chord has to be able to
## SUPPRESS them (CLAUDE.md checklist) and a press cannot be taken back once it
## has been reported. That parking is a real ~6-frame delay on controller dash
## and swap; the keyboard has its own ultimate key and is never delayed.
func _resolve_chord(player_id: int, dash: bool, swap: bool, now: int) -> Dictionary:
	var window_frames := int(roundf(CHORD_WINDOW * Engine.physics_ticks_per_second))
	var pending: Dictionary = _chord_pending[player_id]
	if dash and pending[&"dash"] < 0:
		pending[&"dash"] = now
	if swap and pending[&"swap"] < 0:
		pending[&"swap"] = now

	var out := { &"dash": false, &"swap": false, &"ultimate": false }
	if pending[&"dash"] >= 0 and pending[&"swap"] >= 0 \
			and absi(pending[&"dash"] - pending[&"swap"]) <= window_frames:
		out[&"ultimate"] = true
		pending[&"dash"] = -1
		pending[&"swap"] = -1
		return out
	for half in [&"dash", &"swap"]:
		if pending[half] >= 0 and now - pending[half] >= window_frames:
			out[half] = true
			pending[half] = -1
	return out
#endregion

#region Event builders
func _key(keycode: Key) -> InputEventKey:
	var e := InputEventKey.new()
	e.physical_keycode = keycode
	return e

func _mouse(button: MouseButton) -> InputEventMouseButton:
	var e := InputEventMouseButton.new()
	e.button_index = button
	return e

func _joy(button: JoyButton) -> InputEventJoypadButton:
	var e := InputEventJoypadButton.new()
	e.button_index = button
	return e

func _axis(axis: JoyAxis, value: float) -> InputEventJoypadMotion:
	var e := InputEventJoypadMotion.new()
	e.axis = axis
	e.axis_value = value
	return e
#endregion
