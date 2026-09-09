## Scene changes and the transitions between them.
##
## Stub for M0: fades and the teleport-in/out sequence land in M3-M5. Going
## through here rather than get_tree().change_scene_to_file() everywhere means
## those can be added in one place.
extends Node

signal scene_changed(path: String)

const TITLE := "res://scenes/ui/title.tscn"
const INTRO := "res://scenes/ui/intro.tscn"
const STAGE_SELECT := "res://scenes/ui/stage_select.tscn"
## Where a finished run goes. M8's bullet; nothing is here yet.
const ENDING := "res://scenes/ui/ending.tscn"

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


func goto_intro() -> void:
	goto(INTRO if ResourceLoader.exists(INTRO) else TITLE)


func goto_stage_select() -> void:
	goto(STAGE_SELECT)


## The end of a finished run.
##
## **Falls back to the stage select rather than failing**, which is the whole
## reason this is a method and not a `goto(ENDING)` at the call site. The ending
## screen is M8's and does not exist; `goto` would `push_error` and leave the
## player in a stage that has already said goodbye. Falling back means the game
## is completable today, and gets its ending the moment somebody writes one,
## with no other file changing.
##
## Reported once rather than silently, because a missing ending is a real gap
## and a quiet fallback is how a gap becomes permanent.
func goto_ending() -> void:
	if ResourceLoader.exists(ENDING):
		goto(ENDING)
		return
	print("SceneRouter: no ending scene yet (M8); returning to the stage select")
	goto(STAGE_SELECT)
