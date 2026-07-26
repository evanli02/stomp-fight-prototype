class_name MovementConfig extends Resource
## All movement feel tunables (DESIGN 4). Edit values in movement_config.tres,
## never hardcode in scripts. Values here are the M1 starting points.

@export_group("Ground")
@export var run_speed_base: float = 260.0
@export var run_speed_cap: float = 420.0
@export var accel_time_to_cap: float = 1.5    ## seconds of running to full momentum
@export var ground_redirect_time: float = 0.1 ## flip time at base speed
@export var skid_time_at_cap: float = 0.22
## Ground accel is derived as 2*run_speed_base/ground_redirect_time (a full flip in
## that time), so acceleration and redirect stay coupled to one knob.
@export var ground_friction: float = 2600.0   ## no-input ground decel (DESIGN 4.1 leaves this open)
@export var momentum_keep_on_landing: float = 0.5 ## normal (non-b-hop) landing, DESIGN 4.2
@export var momentum_keep_on_skid: float = 0.25   ## after a skid redirect, DESIGN 4.1

@export_group("Air")
@export var gravity: float = 1400.0
@export var fall_speed_max: float = 900.0
@export var air_control_ratio: float = 0.15   ## fraction of ground accel

@export_group("Jump")
@export var jump_impulse_min: float = -237.0  ## min hop (1.25 tiles = sqrt(2*gravity*20))
## Applied while held, up to jump_hold_time_max. At exactly -gravity the hold
## cancels the fall instead of fighting it, so the rise is a flat climb and the
## full-hold apex still lands on DESIGN 4.2's 4.5 tiles from the lower minimum.
@export var jump_hold_force: float = -1400.0
@export var jump_hold_time_max: float = 0.22  ## ...this long (4.5 tiles total)
@export var coyote_time: float = 0.1
@export var jump_buffer_time: float = 0.12
@export var bhop_window: float = 0.08         ## perfect-landing window preserving momentum

@export_group("Dash")
@export var dash_charges: int = 2
@export var dash_recharge: float = 2.5        ## seconds per charge
@export var dash_duration: float = 0.12
@export var dash_distance: float = 48.0       ## ~3 tiles, airborne and along walls
@export var dash_distance_ground: float = 96.0 ## ~6 tiles: the ground dash is the reposition tool
## Airborne dashes keep their full horizontal reach but only this share of their
## upward one — at parity an up-dash beats a jump and nothing else matters.
@export var air_dash_up_mult: float = 0.33
@export var dash_boost_time: float = 0.4      ## raised speed cap after dash
@export var dash_boost_cap_mult: float = 1.15

@export_group("Wall")
@export var wall_slide_speed_hold: float = 120.0
@export var wall_slide_speed_neutral: float = 260.0
@export var walljump_impulse: Vector2 = Vector2(360.0, -420.0)
@export var walljump_later_up_mult: float = 0.15 ## consecutive jumps: mostly horizontal
@export var walljump_steer_cone_deg: float = 35.0 ## movement-input tilt range away from wall
@export var walljump_perfect_window: float = 0.08
@export var momentum_keep_on_wall_jump: float = 0.75 ## non-perfect wall jump (wall analog of landing)
## Surfaces flatter than this are ceilings/slopes and are never wall-jumpable
## (DESIGN 4.4). Compared against |wall_normal.x|.
@export var wall_normal_min_x: float = 0.8
@export var duel_juice_mult: float = 1.2         ## simultaneous player wall-jump bonus
@export var duel_window_frames: int = 4

@export_group("Crouch & slide")
## Crouching out of a run below this speed is just a crouch; at or above it the
## run converts into a slide (DESIGN 4.6).
@export var slide_min_speed: float = 200.0
@export var slide_friction: float = 420.0        ## px/s^2 bled while sliding
@export var slide_momentum_decay: float = 0.8    ## momentum_charge lost per second sliding
@export var slide_exit_speed: float = 90.0       ## slower than this and the slide is over
## The slide jump trades height for distance: a fraction of the minimum hop
## upward, and a hard horizontal launch off whatever speed the slide still has.
@export var slide_jump_up_mult: float = 0.8
@export var slide_jump_speed_mult: float = 1.5
