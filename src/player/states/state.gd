class_name PlayerState extends Node
## Base class for movement states. One state per file under src/player/states/.
## New movement behavior = new state or transition, never if-ladders in player.gd.

var player: Player
var machine: Node  # StateMachine

func enter(_params: Dictionary = {}) -> void: pass
func exit() -> void: pass
func physics_update(_delta: float) -> void: pass
func handle_input(_event: InputEvent) -> void: pass
