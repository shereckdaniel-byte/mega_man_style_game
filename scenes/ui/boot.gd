## Placeholder main scene for M0.
##
## Its job is to prove the project boots and that the pixel-perfect settings in
## docs/ARCHITECTURE.md section 2 actually took effect, including in a headless
## run where nothing is drawn. Replaced by the title screen in M8.
extends Node2D

@onready var _label: Label = $CanvasLayer/Label


func _ready() -> void:
	var report := _self_check()
	for line in report:
		print(line)
	if _label != null:
		_label.text = "\n".join(report)


## Reads back the settings that are easy to break and hard to notice.
func _self_check() -> PackedStringArray:
	var vp := Vector2i(
		ProjectSettings.get_setting("display/window/size/viewport_width"),
		ProjectSettings.get_setting("display/window/size/viewport_height"))
	var filter := int(ProjectSettings.get_setting(
		"rendering/textures/canvas_textures/default_texture_filter"))
	return PackedStringArray([
		"MEGA MAN STYLE GAME - M0",
		"godot      %s" % Engine.get_version_info().string,
		"viewport   %dx%d" % [vp.x, vp.y],
		"stretch    %s / %s" % [
			ProjectSettings.get_setting("display/window/stretch/mode"),
			ProjectSettings.get_setting("display/window/stretch/scale_mode")],
		"renderer   %s" % ProjectSettings.get_setting("rendering/renderer/rendering_method"),
		"filter     %s" % ("nearest" if filter == 0 else "NOT NEAREST (%d)" % filter),
		"physics    %d Hz" % Engine.physics_ticks_per_second,
		"gravity    %.1f (per-actor)" % float(ProjectSettings.get_setting("physics/2d/default_gravity")),
		"jump apex  %.1f px" % Tuning.player.jump_apex_px(),
		"slide      %.1f px" % Tuning.player.slide_distance_px(),
		"inputs     %d actions" % InputMap.get_actions().filter(
			func(a: StringName) -> bool: return not String(a).begins_with("ui_")).size(),
	])
