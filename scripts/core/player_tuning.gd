## Movement constants for the player.
##
## Authored in NES units -- pixels per *frame* at a fixed 60 Hz tick -- and
## multiplied by `world_scale` on the way out. Authoring this way means the
## numbers stay comparable to the reference hardware and the tile-relative
## geometry is preserved exactly: a jump clears 2.9 tiles whatever the scale.
##
## Never hand-write a px/s value. Change `world_scale` and everything follows.
class_name PlayerTuning
extends Resource

const FPS := 60.0

## Mega Man 3 tile and sprite metrics, in original pixels.
const NES_TILE := 16.0
const NES_CHARACTER_HEIGHT := 24.0
const NES_HITBOX := Vector2(16.0, 24.0)
const NES_SLIDE_HITBOX := Vector2(16.0, 14.0)

@export_group("Scale")
## World pixels per NES pixel.
##
## 4.5 gives 72 px tiles and a 108 px character, and a 1920x1080 viewport is then
## 26.7 x 15 tiles -- vertically close to the original's 14, horizontally wider,
## which is the cost of 16:9.
##
## Scale and viewport must move together: they cancel out in tile counts, so
## 1280x720 at 3.0 frames exactly the same amount of level. What changes is how
## much of the source art survives -- the AutoSprite exports are 177 px tall, so
## 4.5 draws them at 0.61x where 3.0 threw away most of the detail at 0.41x.
## Raising scale alone would just zoom in and show less level.
@export var world_scale := 4.5

@export_group("Ground")
## 1.375 px/frame. No acceleration, no friction: velocity.x is either exactly
## this or exactly zero.
@export var walk_speed_pf := 1.375

@export_group("Air")
@export var jump_velocity_pf := 4.9375
@export var gravity_pf := 0.25
@export var terminal_velocity_pf := 7.0
## Frames of jump input buffered before landing. The original had none; 4 is
## invisible to the player and forgiving. See PLAN.md section 6.
@export var jump_buffer_frames := 4
## Grace frames after leaving a ledge. Deliberately 0: coyote time changes ledge
## geometry, which changes level design.
@export var coyote_frames := 0

@export_group("Slide")
@export var slide_speed_pf := 2.5
## 26 frames at 2.5 px/frame -> 65 NES px, a little over 4 tiles.
@export var slide_frames := 26
## Clearance needed above the slide hitbox to stand up, in NES px.
@export var slide_headroom_pf := 10.0

@export_group("Ladder")
@export var climb_speed_pf := 1.0

@export_group("Damage")
@export var knockback_speed_pf := 0.5
@export var knockback_frames := 16
## ~1.5 s of invulnerability.
@export var iframes := 90
@export var flicker_period_frames := 2

@export_group("Weapons")
@export var shot_speed_pf := 5.0
@export var shoot_pose_frames := 16
## Mega Man 3 has no charge shot; the cap on live pellets is what limits DPS.
@export var max_buster_shots := 3


# --- Unit conversion ----------------------------------------------------------

## NES px/frame -> world px/s.
func px_s(per_frame: float) -> float:
	return per_frame * FPS * world_scale


## NES px/frame^2 -> world px/s^2.
func px_s2(per_frame: float) -> float:
	return per_frame * FPS * FPS * world_scale


## NES px -> world px.
func px(nes_px: float) -> float:
	return nes_px * world_scale


func tile_size() -> float:
	return NES_TILE * world_scale


func character_height() -> float:
	return NES_CHARACTER_HEIGHT * world_scale


func hitbox_size() -> Vector2:
	return NES_HITBOX * world_scale


func slide_hitbox_size() -> Vector2:
	return NES_SLIDE_HITBOX * world_scale


## Factor to draw a sprite whose source art is `source_height` px tall at the
## character's world height. The AutoSprite exports are ~177 px, so this is
## about 0.41 -- a minification, which is why the project filters linearly
## rather than nearest.
func sprite_scale(source_height: float) -> float:
	if source_height <= 0.0:
		return 1.0
	return character_height() / source_height


# --- Derived values -----------------------------------------------------------
# Asserted by tests/test_tuning.gd. If a level needs a taller jump than this,
# the level is wrong, not the constant.

## Peak height of a full jump from standing, in NES px.
##
## The *discrete* apex: it integrates one frame at a time the way the engine
## (and the NES) actually does, rather than using the continuous v^2/2g. The two
## differ by about v/2 -- a sixth of a tile, which is the difference between a
## ledge being clearable or not.
func jump_apex_nes_px() -> float:
	var v := -jump_velocity_pf
	var y := 0.0
	var apex := 0.0
	while v < 0.0:
		v += gravity_pf
		y += v
		apex = minf(apex, y)
	return absf(apex)


## Jump apex in world px. Design ledges against this.
func jump_apex_px() -> float:
	return px(jump_apex_nes_px())


## The textbook v^2/2g figure, in NES px. Kept only so the gap against the
## discrete apex stays visible; do not design levels against it.
func jump_apex_continuous_nes_px() -> float:
	return (jump_velocity_pf * jump_velocity_pf) / (2.0 * gravity_pf)


## Jump height expressed in tiles. Scale-invariant, so this is the number to
## reason about when laying out a room.
func jump_apex_tiles() -> float:
	return jump_apex_nes_px() / NES_TILE


func slide_distance_nes_px() -> float:
	return slide_speed_pf * float(slide_frames)


func slide_distance_px() -> float:
	return px(slide_distance_nes_px())


func slide_distance_tiles() -> float:
	return slide_distance_nes_px() / NES_TILE


## Frames to reach terminal velocity from rest.
func frames_to_terminal() -> float:
	return terminal_velocity_pf / gravity_pf
