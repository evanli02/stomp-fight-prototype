class_name TeleporterPad extends TerrainElement
## One end of Slip's ultimate (DESIGN 5.2). When both ends stand, touching one
## sends you to the other instantly; both then go dark for a moment and bodies
## pass through freely. The pair takes sides: enemies of the owner arrive
## slowed, allies arrive sped up — a door that is always friendlier to the
## people who own it.

const PAD_SIZE: Vector2 = Vector2(34, 42)
const DOWNTIME: float = 1.5
const SLOW_MULT: float = 0.48
const SLOW_TIME: float = 4.0
const HASTE_MULT: float = 1.3
const HASTE_TIME: float = 4.0

var pair: TeleporterPad = null
var owner_team: int = -1
var lifetime: float = 25.0
var accent: Color = Color(0.11, 0.43, 0.82)

var _downtime: float = 0.0

func _ready() -> void:
	size = PAD_SIZE
	super()

func active() -> bool:
	return _downtime <= 0.0 and pair != null and is_instance_valid(pair)

func go_dark() -> void:
	_downtime = DOWNTIME

func tick(delta: float) -> void:
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()
		return
	if _downtime > 0.0:
		_downtime -= delta
	queue_redraw()

func on_body_entered(p: Player) -> void:
	if not active():
		return
	# Both ends go dark: the arriving body is standing in the exit, and without
	# this the pair would ping-pong it forever.
	go_dark()
	pair.go_dark()
	p.global_position = pair.global_position
	if p.team_id == owner_team:
		p.grant_speed_buff(HASTE_MULT, HASTE_TIME)
	else:
		p.apply_slow(SLOW_MULT, SLOW_TIME, &"teleport")

func _draw() -> void:
	var half := PAD_SIZE * 0.5
	var lit := active()
	var t := float(Time.get_ticks_msec()) * 0.005
	var glow: float = (0.6 + 0.4 * sin(t)) if lit else 0.18
	draw_rect(Rect2(-half, PAD_SIZE), Color(accent.r, accent.g, accent.b, 0.10 * (glow + 0.4)))
	draw_rect(Rect2(-half, PAD_SIZE), Color(accent.r, accent.g, accent.b, glow), false, 2.0)
	for i in 3:
		var y := -half.y + 8 + i * 13 + fmod(t * 10.0, 13.0)
		if y < half.y - 2:
			draw_rect(Rect2(Vector2(-half.x + 4, y), Vector2(PAD_SIZE.x - 8, 2)),
				Color(1, 1, 1, (0.5 if lit else 0.1)))
