class_name SlipTeleport extends Ability
## Slip's ultimate (DESIGN 5.2): a pair of teleporter pads. The first cast
## places one end; the recast — free, part of the same activation — places the
## other. The pads (TeleporterPad) do the rest: instant travel, a dark window
## after each use, slow for enemies, haste for allies.

@export var recast_window: float = 5.0
## How long both ends go dark after a trip, so the pair cannot ping-pong.
@export var pad_downtime: float = 1.5
## Enemies arrive slowed; allies arrive hastened. Same door, different terms.
@export var enemy_slow_mult: float = 0.48
@export var enemy_slow_time: float = 4.0
@export var ally_haste_mult: float = 1.3
@export var ally_haste_time: float = 4.0
## How long the pair stands before it expires.
@export var pad_lifetime: float = 25.0

var _first: TeleporterPad = null
var _recast_remaining: float = 0.0

func _physics_process(delta: float) -> void:
	super(delta)
	if _recast_remaining > 0.0:
		_recast_remaining -= delta
		if _recast_remaining <= 0.0 and _first != null and is_instance_valid(_first):
			# Never placed the exit: the pair auto-completes at Slip's feet, so
			# a spent ultimate is never a dead one.
			_place_second(player.global_position)

func _is_free_recast() -> bool:
	return _recast_remaining > 0.0

func _execute(_aim: Vector2) -> void:
	if _recast_remaining > 0.0:
		_place_second(player.global_position)
		return
	_first = _make_pad(player.global_position)
	_recast_remaining = recast_window

func _place_second(at: Vector2) -> void:
	_recast_remaining = 0.0
	if _first == null or not is_instance_valid(_first):
		return
	# Nudge apart if both ends landed on the same spot, or the pair teleports
	# its own placement touch.
	if at.distance_to(_first.global_position) < 30.0:
		at += Vector2(40, 0)
	var second := _make_pad(at)
	_first.pair = second
	second.pair = _first
	_first = null

func _make_pad(at: Vector2) -> TeleporterPad:
	var pad := TeleporterPad.new()
	pad.global_position = at
	pad.owner_team = player.team_id
	pad.downtime = pad_downtime
	pad.slow_mult = enemy_slow_mult
	pad.slow_time = enemy_slow_time
	pad.haste_mult = ally_haste_mult
	pad.haste_time = ally_haste_time
	pad.lifetime = pad_lifetime
	if player.hero != null:
		pad.accent = player.hero.accent_color
	player.spawn_effect(pad)
	return pad
