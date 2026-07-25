class_name PlayerState extends Node
## Base class for movement states. One state per file under src/player/states/.
## New movement behavior = new state or transition, never if-ladders in player.gd.

var player: Player
var machine: Node  # StateMachine

func enter(_params: Dictionary = {}) -> void: pass
func exit() -> void: pass
func physics_update(_delta: float) -> void: pass
func handle_input(_event: InputEvent) -> void: pass

#region Shared transition guards
## Dash is available from every non-stunned state; returns true if it fired so
## callers can bail out of the rest of their update.
func try_dash() -> bool:
	if player.input.dash_pressed and player.can_dash():
		machine.change_state(&"Dash")
		return true
	return false

## Buffered jump off ground or coyote time. A jump inside the b-hop window keeps
## 100% of horizontal momentum (DESIGN 4.2) — the perfect flag carries that.
func try_ground_jump() -> bool:
	if not player.has_buffered_jump():
		return false
	if not player.is_on_floor() and player.coyote_remaining <= 0.0:
		return false
	if player.velocity.y < 0.0:
		return false  # already rising: never a second jump out of the same one
	var perfect := player.perfect_window_check(player.time_since_landing, player.movement.bhop_window)
	player.consume_jump_buffer()
	machine.change_state(&"Air", {"jump": true, "perfect": perfect})
	return true
#endregion
