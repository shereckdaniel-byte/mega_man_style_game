## Movement constants for the player, authored in NES units: pixels per *frame*
## at a fixed 60 Hz physics tick (see docs/ARCHITECTURE.md section 3).
##
## Authoring in per-frame units and converting once is what keeps the feel
## matched to the reference hardware. Never edit the px/s values directly.
class_name PlayerTuning
extends Resource

const FPS := 60.0

@export_group("Ground")
## 1.375 px/frame -> 82.5 px/s. No acceleration, no friction: velocity.x is
## either exactly this or exactly zero.
@export var walk_speed_pf := 1.375

@export_group("Air")
## Upward launch speed. 4.9375 px/frame -> 296.25 px/s.
@export var jump_velocity_pf := 4.9375
## 0.25 px/frame^2 -> 900 px/s^2.
@export var gravity_pf := 0.25
## 7 px/frame -> 420 px/s.
@export var terminal_velocity_pf := 7.0
## Frames of jump input buffered before landing. The original had none; 4 frames
## is invisible to the player and forgiving. See PLAN.md section 6.
@export var jump_buffer_frames := 4
## Frames of grace after leaving a ledge. Deliberately 0: coyote time changes
## ledge geometry, which changes level design.
@export var coyote_frames := 0

@export_group("Slide")
## 2.5 px/frame -> 150 px/s.
@export var slide_speed_pf := 2.5
## 26 frames at 2.5 px/frame -> 65 px of travel.
@export var slide_frames := 26
## Upward clearance needed to stand up out of a slide.
@export var slide_headroom_px := 10.0

@export_group("Ladder")
## 1 px/frame -> 60 px/s.
@export var climb_speed_pf := 1.0

@export_group("Damage")
## 0.5 px/frame away from the damage source.
@export var knockback_speed_pf := 0.5
## Control is locked for this long after taking a hit.
@export var knockback_frames := 16
## ~1.5 s of invulnerability, sprite flickering every 2 frames.
@export var iframes := 90
@export var flicker_period_frames := 2

@export_group("Weapons")
## 5 px/frame -> 300 px/s.
@export var shot_speed_pf := 5.0
## How long the firing pose holds after a shot.
@export var shoot_pose_frames := 16
## Mega Man 3 has no charge shot; the cap on live pellets is the limiter.
@export var max_buster_shots := 3


## Converts a per-frame velocity to pixels per second.
func px_s(per_frame: float) -> float:
	return per_frame * FPS


## Converts a per-frame acceleration to pixels per second squared.
func px_s2(per_frame: float) -> float:
	return per_frame * FPS * FPS


# --- Derived values. Asserted by tests/test_tuning.gd; if a level needs a jump
# --- taller than this, the level is wrong, not the constant.

## Peak height of a full jump from standing, in pixels.
##
## This is the *discrete* apex: it integrates one frame at a time, the way the
## engine (and the NES) actually does, rather than using the continuous v^2/2g.
## The two differ by v/2 -- about 2.5 px here -- which is a quarter of a tile and
## therefore the difference between a ledge being clearable or not. Always
## design against this number.
func jump_apex_px() -> float:
	var v := -jump_velocity_pf
	var y := 0.0
	var apex := 0.0
	while v < 0.0:
		v += gravity_pf
		y += v
		apex = minf(apex, y)
	return absf(apex)


## The textbook v^2/2g figure. Kept only to make the gap against the discrete
## apex visible; do not design levels against it.
func jump_apex_continuous_px() -> float:
	return (jump_velocity_pf * jump_velocity_pf) / (2.0 * gravity_pf)


## Horizontal distance covered by an uninterrupted slide, in pixels.
func slide_distance_px() -> float:
	return slide_speed_pf * float(slide_frames)


## Frames to reach terminal velocity from rest.
func frames_to_terminal() -> float:
	return terminal_velocity_pf / gravity_pf
