class_name InputFrame extends RefCounted
## One player's intent for a single physics tick. States read this instead of
## polling Input directly, so a future rollback layer can swap "read device" for
## "read recorded/received frame" without touching movement code
## (IMPLEMENTATION.md 9).

var move: Vector2 = Vector2.ZERO   ## left stick / WASD, components in -1..1
var aim: Vector2 = Vector2.ZERO    ## always-live aim direction, normalized (DESIGN 7)
var jump_pressed: bool = false     ## edge
var jump_held: bool = false        ## level — drives variable jump height
var dash_pressed: bool = false
var ability_pressed: bool = false
var swap_pressed: bool = false
var ultimate_pressed: bool = false

## Did the player do anything this tick? Ends spawn protection early
## (DESIGN 3.3). Aim is excluded: a mouse sitting still still reports a
## direction, and nudging a stick is not "acting."
func any_action() -> bool:
	return not is_zero_approx(move.x) or not is_zero_approx(move.y) \
		or jump_pressed or jump_held or dash_pressed \
		or ability_pressed or swap_pressed or ultimate_pressed
