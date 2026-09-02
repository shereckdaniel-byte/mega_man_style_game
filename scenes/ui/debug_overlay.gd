## On-screen readout for tuning work: state, velocity in both world and NES
## units, and the measured height of the last jump.
##
## Reading velocity back in px/frame is the point -- the constants are authored
## in those units, so a bug shows up as "1.4 instead of 1.375" rather than as an
## unfamiliar px/s figure. Toggle with F3.
extends CanvasLayer

@export var player_path: NodePath

var _player: Player
var _label: Label
var _apex := 0.0
var _ground_y := 0.0
var _airborne := false


func _ready() -> void:
	_label = Label.new()
	_label.position = Vector2(12, 8)
	_label.add_theme_color_override(&"font_color", Color(0.85, 0.93, 1.0))
	_label.add_theme_color_override(&"font_outline_color", Color(0, 0, 0))
	_label.add_theme_constant_override(&"outline_size", 4)
	add_child(_label)
	_player = get_node_or_null(player_path) as Player


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"debug_overlay"):
		visible = not visible


func _physics_process(_delta: float) -> void:
	if _player == null or not visible:
		return
	_track_jump()
	var t := _player.tuning
	var v := _player.velocity
	_label.text = "\n".join([
		"state    %s" % _player.state_machine.current_name(),
		"frames   %d" % _player.state_machine.frames_in_state,
		"vel      %6.1f, %6.1f px/s" % [v.x, v.y],
		"         %6.3f, %6.3f px/frame (NES)" % [
			v.x / (PlayerTuning.FPS * t.world_scale),
			v.y / (PlayerTuning.FPS * t.world_scale)],
		"floor    %s   ladder %s   shooting %s" % [
			_player.is_on_floor(), _player.on_ladder(), _player.is_shooting()],
		"facing   %d" % _player.facing,
		"apex     %5.1f px  (%.2f tiles)" % [_apex, _apex / t.tile_size()],
		"expected %5.1f px  (%.2f tiles)" % [t.jump_apex_px(), t.jump_apex_tiles()],
		"anim     %s" % _player.sprite.animation,
	])


## Measures peak height above the ground the jump started from, so the number on
## screen is directly comparable to PlayerTuning.jump_apex_px().
func _track_jump() -> void:
	if _player.is_on_floor():
		if _airborne:
			_airborne = false
		_ground_y = _player.global_position.y
		return
	if not _airborne:
		_airborne = true
		_apex = 0.0
	_apex = maxf(_apex, _ground_y - _player.global_position.y)
