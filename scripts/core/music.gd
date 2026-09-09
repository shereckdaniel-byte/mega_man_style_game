## The music, by the name of the place it belongs to.
##
## Same shape as `Sfx` and for the same reasons. The one addition is that a
## **jingle** is a different thing from a theme: it plays on its own bus, it does
## not loop, and the music ducks under it -- which is the bus layout's whole
## reason for existing (`default_bus_layout.tres`, a compressor on Music
## sidechained to Jingle).
##
## A stage asks for its own name and the fortress asks for `fortress`, so which
## music plays where is a fact about the stage rather than a table here that a
## new stage has to be added to.
class_name Music
extends RefCounted

const DIR := "res://assets/audio/music"

static var _cache: Dictionary = {}


static func stream(track: StringName) -> AudioStream:
	if _cache.has(track):
		return _cache[track]
	var path := "%s/%s.wav" % [DIR, track]
	var found: AudioStream = load(path) if ResourceLoader.exists(path) else null
	_cache[track] = found
	return found


## Starts a looping theme. Playing the one already playing does nothing, so a
## room change inside a stage does not restart the music.
static func play(track: StringName) -> void:
	var audio := _audio()
	if audio != null:
		audio.play_bgm(stream(track))


## Fires a jingle over whatever is playing. The music ducks itself.
static func jingle(track: StringName) -> void:
	var audio := _audio()
	if audio != null:
		audio.play_jingle(stream(track))


static func stop() -> void:
	var audio := _audio()
	if audio != null:
		audio.stop_bgm()


static func names() -> Array[StringName]:
	var out: Array[StringName] = []
	var dir := DirAccess.open(DIR)
	if dir == null:
		return out
	var files := dir.get_files()
	files.sort()
	for file in files:
		var name := file.trim_suffix(".remap")
		if name.ends_with(".wav"):
			out.append(StringName(name.get_basename()))
	return out


static func _audio() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.root.get_node_or_null(^"AudioManager")
