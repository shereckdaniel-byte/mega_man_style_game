## Scene changes and the transitions between them.
##
## Stub for M0: fades and the teleport-in/out sequence land in M3-M5. Going
## through here rather than get_tree().change_scene_to_file() everywhere means
## those can be added in one place.
extends Node

signal scene_changed(path: String)

const TITLE := "res://scenes/ui/title.tscn"
const STAGE_SELECT := "res://scenes/ui/stage_select.tscn"

var current_path: String = ""


func goto(path: String) -> void:
	if not ResourceLoader.exists(path):
		push_error("SceneRouter: no scene at %s" % path)
		return
	current_path = path
	# call_deferred: it is not safe to swap the scene while a node in the
	# outgoing tree is mid-signal.
	get_tree().call_deferred("change_scene_to_file", path)
	scene_changed.emit(path)


func reload_current() -> void:
	if current_path.is_empty():
		return
	goto(current_path)


func goto_title() -> void:
	goto(TITLE)


func goto_stage_select() -> void:
	goto(STAGE_SELECT)
