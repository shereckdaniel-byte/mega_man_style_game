## On-screen readout for tuning work: state, velocity in both world and NES
## units, and the measured height of the last jump.
##
## Reading velocity back in px/frame is the point -- the constants are authored
## in those units, so a bug shows up as "1.4 instead of 1.375" rather than as an
## unfamiliar px/s figure. Toggle with F3.
##
## When a `PlaytestLog` is wired in it also shows the run so far: health lost per
## room, and what took it. That is for playing rather than for tuning -- the
## question of whether stage 1 is too hard needs somebody to notice *while* they
## play that the last four HP all went to one gap, not to reconstruct it from
## memory afterwards.
extends CanvasLayer

@export var player_path: NodePath
## Optional. Leave unset for the tuning room, which has no rooms to break a run
## down by.
@export var playtest_log_path: NodePath

var _player: Player
var _log: PlaytestLog
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
	_log = get_node_or_null(playtest_log_path) as PlaytestLog


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"debug_overlay"):
		visible = not visible


func _physics_process(_delta: float) -> void:
	if _player == null or not visible:
		return
	_track_jump()
	var t := _player.tuning
	var v := _player.velocity
	var lines := PackedStringArray([
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
	lines.append_array(_ledger_lines())
	_label.text = "\n".join(lines)


## The run so far, when there is a ledger to read it from.
##
## Rooms already left are the interesting ones -- what a room cost is only known
## once it is behind you -- so they are listed in the order they were entered and
## the current one is marked rather than moved.
func _ledger_lines() -> PackedStringArray:
	if _log == null:
		return PackedStringArray()
	var lines := PackedStringArray(["", "run      %d HP lost, %d death%s in %.0f s" % [
		_log.hp_lost(), _log.deaths, "" if _log.deaths == 1 else "s",
		_log.frames / 60.0]])
	for stay in _log.stays():
		lines.append("  %-16s %2d HP  %d death  x%d" % [
			stay.name, _log.hp_lost_in(stay.name), _log.deaths_in(stay.name),
			stay.entries])
	return lines


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
