class_name StateMachine extends Node
## Movement FSM (DESIGN 4.5). Children are PlayerState nodes named for their state.
## Transition via change_state(&"Air", params). Runs on the physics tick only.

@export var initial_state: NodePath

var current: PlayerState

func _ready() -> void:
	for child in get_children():
		if child is PlayerState:
			child.player = owner as Player
			child.machine = self
	if initial_state:
		current = get_node(initial_state)
		current.enter()

func change_state(state_name: StringName, params: Dictionary = {}) -> void:
	if current:
		current.exit()
	current = get_node(NodePath(state_name)) as PlayerState
	current.enter(params)

func _physics_process(delta: float) -> void:
	if current:
		current.physics_update(delta)
