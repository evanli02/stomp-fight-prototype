extends Node
## InputConfig — registers all input actions in code (kept out of project.godot so
## bindings are documented, rebindable, and diff-friendly). Also owns the R2+L2
## ultimate chord resolver and the shared aim-vector provider (DESIGN 7).
## Rebind overrides persist to user://input.cfg (TODO M2).

const CHORD_WINDOW: float = 0.1  # seconds for R2+L2 ultimate simultaneity

func _ready() -> void:
	_register_actions()

func _register_actions() -> void:
	# action -> [events]; KBM per DESIGN 7 + controller per DESIGN 7.
	_add(&"move_left",  [_key(KEY_A), _axis(JOY_AXIS_LEFT_X, -1.0)])
	_add(&"move_right", [_key(KEY_D), _axis(JOY_AXIS_LEFT_X, 1.0)])
	_add(&"move_up",    [_key(KEY_W), _axis(JOY_AXIS_LEFT_Y, -1.0)])
	_add(&"move_down",  [_key(KEY_S), _axis(JOY_AXIS_LEFT_Y, 1.0)])
	_add(&"jump",       [_key(KEY_SPACE), _joy(JOY_BUTTON_RIGHT_SHOULDER)])   # R1
	_add(&"dash",       [_key(KEY_SHIFT), _axis(JOY_AXIS_TRIGGER_RIGHT, 1.0)]) # R2
	_add(&"ability",    [_mouse(MOUSE_BUTTON_LEFT), _joy(JOY_BUTTON_LEFT_SHOULDER)]) # L1
	_add(&"swap",       [_mouse(MOUSE_BUTTON_RIGHT), _axis(JOY_AXIS_TRIGGER_LEFT, 1.0)]) # L2
	_add(&"ultimate",   [_key(KEY_E)])  # controller: resolved as R2+L2 chord below
	_add(&"aim_up",     [_axis(JOY_AXIS_RIGHT_Y, -1.0)])
	_add(&"aim_down",   [_axis(JOY_AXIS_RIGHT_Y, 1.0)])
	_add(&"aim_left",   [_axis(JOY_AXIS_RIGHT_X, -1.0)])
	_add(&"aim_right",  [_axis(JOY_AXIS_RIGHT_X, 1.0)])

## Live aim vector: mouse (relative to player) on KBM, right stick on pad.
## Feeds abilities AND aimed wall jumps / air dashes (DESIGN 4.4, 7).
func aim_vector(player_global_pos: Vector2, viewport: Viewport) -> Vector2:
	var stick := Input.get_vector(&"aim_left", &"aim_right", &"aim_up", &"aim_down")
	if stick.length() > 0.2:
		return stick.normalized()
	var mouse := viewport.get_camera_2d().get_global_mouse_position() if viewport.get_camera_2d() else viewport.get_mouse_position()
	return (mouse - player_global_pos).normalized()

## Sample one player's intent for this physics tick. All gameplay reads inputs
## through here, never through Input directly (IMPLEMENTATION.md 9).
## TODO(M2): route per-player — device index / action suffixes for local 2P.
func poll(_player_id: int, body: Node2D) -> InputFrame:
	var frame := InputFrame.new()
	frame.move = Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")
	frame.aim = aim_vector(body.global_position, body.get_viewport())
	frame.jump_pressed = Input.is_action_just_pressed(&"jump")
	frame.jump_held = Input.is_action_pressed(&"jump")
	frame.dash_pressed = Input.is_action_just_pressed(&"dash")
	frame.ability_pressed = Input.is_action_just_pressed(&"ability")
	frame.swap_pressed = Input.is_action_just_pressed(&"swap")
	frame.ultimate_pressed = Input.is_action_just_pressed(&"ultimate")
	return frame

# TODO(M2): chord resolver — on R2 or L2 press, buffer CHORD_WINDOW; if the other
# arrives in time, emit ultimate and SUPPRESS the buffered dash/swap (CLAUDE.md checklist).

func _add(action: StringName, events: Array) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	for e in events:
		InputMap.action_add_event(action, e)

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
