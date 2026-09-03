## Dawn Boardwalk's gimmick: the water comes up.
##
## A surface that climbs on a timer. Touch it and you die -- this is a
## `Health.kill()`, not damage, for the same reason `KillPlane` is: water you
## can survive by flickering is water that does not mean anything, and a player
## who swam through the wave would be below the level with no way back up.
##
## **The design constraint that shapes everything here is that it must never be
## unwinnable.** A wall of instant death moving up a level is the easiest way in
## games to build something that cannot be escaped, and the player cannot see
## the geometry above them to plan. So:
##
##   * it rises in **steps with a pause at each one**, not smoothly, so there is
##     always a moment to climb rather than a continuous race;
##   * it **stops at `ceiling_row`**, which the stage sets to the highest safe
##     standing row in the section — the water never covers the escape;
##   * and it **recedes** when the player leaves the section, so a death does
##     not put them back at a checkpoint with the water already at the top.
##
## `tests/test_rising_tide.gd` asserts the second and third of those, because
## they are the two that turn a gimmick into a soft lock.
class_name RisingTide
extends Area2D

signal level_changed(row: float)
signal reached_ceiling()

## Tile columns the water spans, and the row its surface starts at.
@export var width_tiles: float = 28.0
@export var start_row: float = 22.0
## The highest row the surface may reach. The stage sets this to the top of the
## safe ground in the section: water above it would drown a player standing in
## the only place there is to stand.
@export var ceiling_row: float = 8.0

## Rows the surface climbs per step, and frames it holds between steps.
@export var step_rows: float = 1.0
@export var step_pause_frames: int = 46
## Frames the water takes to slide up one step. Visible movement, so the step is
## read as "it is rising" rather than "it teleported".
@export var step_frames: int = 14

## Rows per frame while receding. Much faster than the climb: going back down is
## not a challenge, it is a reset, and the player should not wait through it.
@export var recede_rows_per_frame: float = 0.12

## Set false to hold the water where it is -- for the run-up to a section, and
## for tests.
@export var running: bool = false

const BODY := Color(0.16, 0.38, 0.62, 0.62)
const SURF := Color(0.72, 0.92, 1.0, 0.85)
## How far below the surface the kill zone reaches, in tiles. Deep enough that
## nothing falls through it between frames at terminal velocity.
const DEPTH_TILES := 28.0

var surface_row: float
var _frames := 0
var _target_row: float
var _receding := false
var _shape: CollisionShape2D


func _ready() -> void:
	collision_layer = Layers.bit(Layers.HAZARD)
	# Bodies, not hurtboxes: this is about where something is.
	collision_mask = Layers.mask([Layers.PLAYER_BODY, Layers.ENEMY_BODY])
	monitoring = true
	surface_row = start_row
	_target_row = start_row
	_rebuild()
	body_entered.connect(_on_body_entered)


func tile_size() -> float:
	var autoload := get_node_or_null(^"/root/Tuning")
	return autoload.player.tile_size() if autoload != null else 72.0


## Starts the water climbing.
func begin() -> void:
	running = true
	_receding = false
	_frames = 0


## Sends it back down and stops it. Called when the player leaves the section or
## dies in it -- see the note on soft locks above.
func recede() -> void:
	running = false
	_receding = true


func reset() -> void:
	running = false
	_receding = false
	surface_row = start_row
	_target_row = start_row
	_frames = 0
	_apply()


func is_at_ceiling() -> bool:
	return surface_row <= ceiling_row + 0.001


## World y of the water's surface.
func surface_y() -> float:
	return surface_row * tile_size()


func _physics_process(_delta: float) -> void:
	if _receding:
		_recede_step()
		return
	if not running:
		return

	_frames += 1
	if surface_row > _target_row:
		# Sliding up to the step we already committed to.
		var per_frame := step_rows / float(maxi(step_frames, 1))
		surface_row = maxf(surface_row - per_frame, _target_row)
		_apply()
		return

	if is_at_ceiling():
		return
	if _frames < step_pause_frames:
		return
	_frames = 0
	# Rows count downward, so rising means a smaller row.
	_target_row = maxf(surface_row - step_rows, ceiling_row)
	if is_equal_approx(_target_row, ceiling_row):
		reached_ceiling.emit()


func _recede_step() -> void:
	if surface_row >= start_row:
		_receding = false
		surface_row = start_row
		_target_row = start_row
		_apply()
		return
	surface_row = minf(surface_row + recede_rows_per_frame, start_row)
	_target_row = surface_row
	_apply()


func _apply() -> void:
	_rebuild()
	level_changed.emit(surface_row)


func _rebuild() -> void:
	var tile := tile_size()
	if _shape == null:
		_shape = CollisionShape2D.new()
		_shape.name = "Water"
		add_child(_shape)
	var rect := RectangleShape2D.new()
	rect.size = Vector2(width_tiles * tile, DEPTH_TILES * tile)
	_shape.shape = rect
	# The node sits at the section's left edge; the box hangs below the surface.
	_shape.position = Vector2(rect.size.x * 0.5,
		surface_y() - position.y + rect.size.y * 0.5)
	queue_redraw()


## Drowning is a kill, not damage -- i-frames must not carry anyone through it.
func _on_body_entered(body: Node2D) -> void:
	# `get()` returns Variant, so the type has to be declared rather than
	# inferred -- this project treats inference from Variant as an error.
	var health: Variant = body.get("health")
	if health is Health and not (health as Health).is_dead():
		# Named for the same reason KillPlane's is: an unnamed kill reports as a
		# buster kill, and a drowning that reads as self-inflicted is worse than
		# no record at all.
		(health as Health).kill(DamageInfo.new(9999, body.global_position, &"tide"))


func _draw() -> void:
	var tile := tile_size()
	var top := surface_y() - position.y
	var size := Vector2(width_tiles * tile, DEPTH_TILES * tile)
	draw_rect(Rect2(Vector2(0.0, top), size), BODY)
	# A bright surface line: the boundary is the only part of this the player
	# needs to judge, so it is the only part drawn sharply.
	draw_rect(Rect2(Vector2(0.0, top), Vector2(size.x, maxf(tile * 0.12, 3.0))), SURF)
