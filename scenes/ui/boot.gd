## Placeholder main scene for M0.
##
## Its job is to prove the project boots and that the pixel-perfect settings in
## docs/ARCHITECTURE.md section 2 actually took effect, including in a headless
## run where nothing is drawn. Replaced by the title screen in M8.
extends Node2D

@onready var _label: Label = $CanvasLayer/Label


## Where a windowed run lands. The M1 tuning room is still the place to read
## movement numbers off the debug overlay -- open
## res://scenes/stages/test_room/test_room.tscn directly for that, which is also
## what tools/screenshot.gd drives.
const FIRST_SCENE := "res://scenes/stages/dawn_boardwalk/art_preview.tscn"


func _ready() -> void:
	var report := _self_check()
	for line in report:
		print(line)
	if _label != null:
		_label.text = "\n".join(report)
	# Headless runs stay here so `--headless --quit` keeps reporting the
	# self-check; a real run drops straight into the stage 1 art preview.
	if DisplayServer.get_name() != "headless":
		get_tree().call_deferred("change_scene_to_file", FIRST_SCENE)


## Reads back the settings that are easy to break and hard to notice.
func _self_check() -> PackedStringArray:
	var vp := Vector2i(
		ProjectSettings.get_setting("display/window/size/viewport_width"),
		ProjectSettings.get_setting("display/window/size/viewport_height"))
	var filter := int(ProjectSettings.get_setting(
		"rendering/textures/canvas_textures/default_texture_filter"))
	var t: PlayerTuning = Tuning.player
	return PackedStringArray([
		"MEGA MAN STYLE GAME - M1",
		"godot      %s" % Engine.get_version_info().string,
		"viewport   %dx%d" % [vp.x, vp.y],
		"stretch    %s / %s" % [
			ProjectSettings.get_setting("display/window/stretch/mode"),
			ProjectSettings.get_setting("display/window/stretch/scale_mode")],
		"renderer   %s" % ProjectSettings.get_setting("rendering/renderer/rendering_method"),
		"filter     %s" % ("linear" if filter == 1 else "NOT LINEAR (%d)" % filter),
		"physics    %d Hz" % Engine.physics_ticks_per_second,
		"gravity    %.1f (per-actor)" % float(ProjectSettings.get_setting("physics/2d/default_gravity")),
		"scale      %.1fx  tile %.0f px  character %.0f px" % [
			t.world_scale, t.tile_size(), t.character_height()],
		"jump apex  %.1f px  (%.2f tiles)" % [t.jump_apex_px(), t.jump_apex_tiles()],
		"slide      %.1f px  (%.2f tiles)" % [t.slide_distance_px(), t.slide_distance_tiles()],
		"inputs     %d actions" % InputMap.get_actions().filter(
			func(a: StringName) -> bool: return not String(a).begins_with("ui_")).size(),
	])
