## Builds SpriteFrames resources from AutoSprite exports.
##
## The logic lives here, in a plain RefCounted, because EditorScript cannot be
## run headless -- `godot --script` rejects anything that is not a SceneTree or
## MainLoop -- and this has to work in CI. Two thin entry points wrap it:
##
##   tools/autosprite_import.gd         SceneTree, for the command line and CI
##   tools/autosprite_import_editor.gd  EditorScript, for the editor's File > Run
##
## EXPORT LAYOUT (verified against real exports, 2026-09)
##
##   assets/sprites/<character>/
##     <Animation Name>/
##       atlas.json        frame rects + meta
##       spritesheet.png   grid of frames
##
## One directory *per animation*, each with its own sheet -- not one sheet per
## character, which is what the pre-M0 draft of docs/SPRITES.md assumed.
## atlas.json looks like:
##
##   { "frames": { "0": {"x":0,"y":0,"w":256,"h":256,"duration":1}, ... },
##     "meta": { "size": {"w":1280,"h":1280},
##               "frame_size": {"w":256,"h":256},
##               "duration_s": 2.333 } }
##
## Frame keys are stringified integers and must be sorted numerically, not
## lexicographically, or frame 10 lands between 1 and 2.
class_name AutoSpriteImporter
extends RefCounted


const SRC_ROOT := "res://assets/sprites"
const OUT_ROOT := "res://resources/sprite_frames"

## AutoSprite animation directory -> the name the game asks for. Anything not
## listed here is snake_cased and kept, so a new animation shows up rather than
## being silently dropped.
const NAME_MAP := {
	"idle_right": "idle",
	"walk_right": "walk",
	"run_right": "run",
	"jump_right": "jump",
	"attack_right": "attack",
	"arm cannon attack": "idle_shoot",
	"wave gun": "attack_special",
	"hit react": "hurt",
	"hurt": "hurt",
	"death": "death",
	"victory": "victory",
}

## Animations that repeat. Everything else plays once.
const LOOPING := ["idle", "walk", "run", "climb", "hurt", "walk_shoot", "run_shoot"]

## Sprites are authored right-facing and mirrored with flip_h, so the direction
## suffix carries no information once imported.
const DIRECTION_SUFFIXES := ["_right", "_left", "_down", "_up"]


func run() -> bool:
	# Characters sit at varying depths (assets/sprites/player,
	# assets/sprites/bosses/wave_man), so find them by shape rather than by a
	# fixed depth: a character is any directory whose children hold an
	# atlas.json.
	var characters := _find_character_dirs(SRC_ROOT)
	if characters.is_empty():
		push_warning("No character directories under %s" % SRC_ROOT)
		return false

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_ROOT))
	var ok := true
	for char_dir in characters:
		ok = _import_character(char_dir) and ok
	return ok


func _find_character_dirs(root: String) -> PackedStringArray:
	var out: PackedStringArray = []
	for entry in _subdirs(root):
		var path := root.path_join(entry)
		if _is_character_dir(path):
			out.append(path)
		else:
			out.append_array(_find_character_dirs(path))
	return out


func _is_character_dir(path: String) -> bool:
	for entry in _subdirs(path):
		if FileAccess.file_exists(path.path_join(entry).path_join("atlas.json")):
			return true
	return false


func _import_character(char_dir: String) -> bool:
	var character := char_dir.get_file()
	var anim_dirs := _subdirs(char_dir)
	if anim_dirs.is_empty():
		return false

	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	var imported := 0

	for anim_dir in anim_dirs:
		var dir := char_dir.path_join(anim_dir)
		var json_path := dir.path_join("atlas.json")
		var sheet_path := dir.path_join("spritesheet.png")
		if not FileAccess.file_exists(json_path) or not ResourceLoader.exists(sheet_path):
			push_warning("%s: expected atlas.json and spritesheet.png" % dir)
			continue

		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(json_path))
		if not (parsed is Dictionary):
			push_warning("%s: unreadable atlas.json" % dir)
			continue

		var sheet: Texture2D = load(sheet_path)
		var anim_name := _animation_name(anim_dir)
		if _add_animation(frames, anim_name, sheet, parsed as Dictionary):
			imported += 1

	if imported == 0:
		push_warning("%s: nothing imported" % character)
		return false

	var out_path := OUT_ROOT.path_join("%s.tres" % _snake_case(character))
	var err := ResourceSaver.save(frames, out_path)
	if err != OK:
		push_error("%s: save failed (%d)" % [out_path, err])
		return false
	print("%s -> %s (%d animations)" % [character, out_path, imported])
	return true


func _add_animation(frames: SpriteFrames, anim_name: String, sheet: Texture2D,
		atlas: Dictionary) -> bool:
	var rects: Dictionary = atlas.get("frames", {})
	if rects.is_empty():
		return false

	# Stringified integer keys: sort numerically so frame 10 does not land
	# between 1 and 2.
	var keys: Array = rects.keys()
	keys.sort_custom(func(a: Variant, b: Variant) -> bool:
		return int(str(a)) < int(str(b)))

	var name := StringName(anim_name)
	if frames.has_animation(name):
		frames.remove_animation(name)
	frames.add_animation(name)
	frames.set_animation_loop(name, anim_name in LOOPING)
	frames.set_animation_speed(name, _fps(atlas, keys.size()))

	for key: Variant in keys:
		var r: Dictionary = rects[key]
		var tex := AtlasTexture.new()
		tex.atlas = sheet
		tex.region = Rect2(
			float(r.get("x", 0)), float(r.get("y", 0)),
			float(r.get("w", 0)), float(r.get("h", 0)))
		# Without filter_clip, neighbouring frames bleed in at the region edge.
		tex.filter_clip = true
		frames.add_frame(name, tex)
	return true


## AutoSprite reports total duration rather than a frame rate.
func _fps(atlas: Dictionary, frame_count: int) -> float:
	var meta: Dictionary = atlas.get("meta", {})
	var duration := float(meta.get("duration_s", 0.0))
	if duration > 0.0 and frame_count > 0:
		return float(frame_count) / duration
	return 12.0


func _animation_name(dir_name: String) -> String:
	var key := dir_name.to_lower()
	if NAME_MAP.has(key):
		return NAME_MAP[key]
	var name := _snake_case(dir_name)
	for suffix in DIRECTION_SUFFIXES:
		if name.ends_with(suffix):
			name = name.substr(0, name.length() - suffix.length())
			break
	return name


## "Hit React" and "arm cannon attack" both become valid identifiers.
func _snake_case(text: String) -> String:
	var out := ""
	for i in text.length():
		var c := text[i]
		if c == " " or c == "-":
			out += "_"
		elif c.to_lower() != c.to_upper():  # a letter
			out += c.to_lower()
		elif c.is_valid_int() or c == "_":
			out += c
	while out.contains("__"):
		out = out.replace("__", "_")
	return out.strip_edges().trim_prefix("_").trim_suffix("_")


func _subdirs(path: String) -> PackedStringArray:
	var out: PackedStringArray = []
	var dir := DirAccess.open(path)
	if dir == null:
		return out
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if dir.current_is_dir() and not entry.begins_with("."):
			out.append(entry)
		entry = dir.get_next()
	dir.list_dir_end()
	out.sort()
	return out
