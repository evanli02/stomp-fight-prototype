class_name MovementConfig extends Resource
## All movement feel tunables (DESIGN 4). Edit values in movement_config.tres,
## never hardcode in scripts. Values here are the M1 starting points.

@export_group("Ground")
@export var run_speed_base: float = 260.0
@export var run_speed_cap: float = 420.0
@export var accel_time_to_cap: float = 1.5    ## seconds of running to full momentum
@export var ground_redirect_time: float = 0.1 ## flip time at base speed
@export var skid_time_at_cap: float = 0.22

@export_group("Air")
@export var gravity: float = 1400.0
@export var fall_speed_max: float = 900.0
@export var air_control_ratio: float = 0.15   ## fraction of ground accel

@export_group("Jump")
@export var jump_impulse_min: float = -420.0  ## min hop (~2.5 tiles)
@export var jump_hold_force: float = -900.0   ## applied while held, up to...
@export var jump_hold_time_max: float = 0.22  ## ...this long (~4.5 tiles total)
@export var coyote_time: float = 0.1
@export var jump_buffer_time: float = 0.12
@export var bhop_window: float = 0.08         ## perfect-landing window preserving momentum

@export_group("Dash")
@export var dash_charges: int = 2
@export var dash_recharge: float = 2.5        ## seconds per charge
@export var dash_duration: float = 0.12
@export var dash_distance: float = 48.0       ## ~3 tiles
@export var dash_boost_time: float = 0.4      ## raised speed cap after dash
@export var dash_boost_cap_mult: float = 1.15

@export_group("Wall")
@export var wall_slide_speed_hold: float = 120.0
@export var wall_slide_speed_neutral: float = 260.0
@export var walljump_impulse: Vector2 = Vector2(360.0, -420.0)
@export var walljump_later_up_mult: float = 0.15 ## consecutive jumps: mostly horizontal
@export var walljump_aim_cone_deg: float = 35.0  ## aim-tilt range away from wall
@export var walljump_perfect_window: float = 0.08
@export var duel_juice_mult: float = 1.2         ## simultaneous player wall-jump bonus
@export var duel_window_frames: int = 4
