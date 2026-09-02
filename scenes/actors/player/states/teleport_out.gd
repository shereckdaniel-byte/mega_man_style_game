## The beam-up that ends a stage.
##
## The mirror of the beam-down in `teleport.gd`, and the reason both exist as
## states rather than as a cutscene: the player is still a physics body doing
## this, so the camera keeps following, the room keeps scrolling, and the exit
## reads as part of the level rather than as a screen wipe over it.
##
## Rises at a fixed speed with gravity switched off. Gravity is the whole
## difficulty here -- `apply_gravity` would fight the climb and the character
## would rise, slow, and sag back down like a failed jump.
extends State

## Upward speed in NES px/frame. Faster than a jump by a wide margin: this is a
## beam, not a leap, and it should not look like the player is escaping by
## jumping very hard.
const RISE_SPEED_PF := 9.0
## Frames the clip plays before the rise starts, so the pose is seen.
const WIND_UP_FRAMES := 24
## How far above the top of the view the player goes before the stage is done,
## in tiles. Generous, so the character is unambiguously gone.
const CLEAR_TILES := 4.0
## Backstop if the view cannot be measured -- a bare test tree has no camera.
const MAX_FRAMES := 240

var _done := false


func enter(_msg: Dictionary = {}) -> void:
	var player: Player = host
	player.velocity = Vector2.ZERO
	player.cancel_charge()
	_done = false


func physics_update(_delta: float) -> StringName:
	var player: Player = host
	if _done:
		return &""

	var frames: int = player.state_machine.frames_in_state
	if frames < WIND_UP_FRAMES:
		player.velocity = Vector2.ZERO
		return &""

	# No gravity: this is a beam. See the note above.
	player.velocity = Vector2(0.0, -player.tuning.px_s(RISE_SPEED_PF))
	player.move_and_slide()

	if frames >= MAX_FRAMES or _above_the_view(player):
		_done = true
		player.finish_stage_exit()
	return &""


## Has the character cleared the top of what the camera can see?
func _above_the_view(player: Player) -> bool:
	var viewport := player.get_viewport()
	if viewport == null:
		return false
	var camera := viewport.get_camera_2d()
	if camera == null:
		return false
	var view := viewport.get_visible_rect().size / camera.zoom
	var top: float = camera.get_screen_center_position().y - view.y * 0.5
	return player.global_position.y < top - CLEAR_TILES * player.tuning.tile_size()
