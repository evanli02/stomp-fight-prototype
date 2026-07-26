class_name StateMachine extends Node
## Movement FSM (DESIGN 4.5). Children are PlayerState nodes named for their state.
## Transition via change_state(&"Air", params). Runs on the physics tick only.
##
## The Player owns the tick: it samples input, calls tick(), then move_and_slide().
## The machine must NOT run its own _physics_process — states set velocity, and
## the body has to move exactly once afterwards (IMPLEMENTATION.md 3).

@export var initial_state: NodePath

var current: PlayerState

## Wire every child state to its player and start the initial state. Called from
## Player._ready() so the player's own @onready refs are live before enter().
func setup(p: Player) -> void:
	for child in get_children():
		if child is PlayerState:
			var s := child as PlayerState
			s.player = p
			s.machine = self
	current = get_node(initial_state) as PlayerState
	current.enter()

func change_state(state_name: StringName, params: Dictionary = {}) -> void:
	if current:
		current.exit()
	current = get_node(NodePath(state_name)) as PlayerState
	current.enter(params)

func tick(delta: float) -> void:
	if current:
		current.physics_update(delta)

## Name of the running state, for the playground debug overlay.
func state_name() -> StringName:
	return current.name if current else &"<none>"

## Animation the running state wants shown (see PlayerState.animation).
func current_animation() -> StringName:
	return current.animation() if current else &"idle"
