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

## Frames to keep, as [first, last] inclusive indices into the atlas's own
## numeric frame order. Empty means keep everything.
##
## AutoSprite renders a clip as a little performance: a wind-up, the move, then
## a recovery. The controller owns state timing and never waits on the
## animation, so a short state only ever shows the opening frames -- a slide
## lasts 26 physics frames, which at these clips' ~12 fps is five animation
## frames. Untrimmed, `slide` spends those five frames standing up and the
## character never reaches the low pose, which is the exact bug the animation
## was generated to fix. Trimming picks the frames the move actually lives in.
##
## Playback speed is deliberately taken from the *source* frame count, so
## trimming changes which frames play, never how fast they play.
const TRIM := {
	"slide": [18, 24],         # the settled low skim; 0-8 stand up, 9-17 bob 30 px vertically
	"climb": [7, 19],          # the hand-over-hand reach; either end is a static stand
	"walk_shoot": [11, 20],    # the arm cannon is only extended across these
	"jump_shoot": [12, 14],    # tucked with the cannon lit; it stands before, drops the cannon after
	"teleport_in": [2, 24],    # 0-1 are a stray standing pose before the beam
}

## The cell row every animation's feet are normalised onto.
##
## AutoSprite frames each clip independently, so the row the character stands on
## drifts between animations -- measured across the player's fourteen, the
## lowest opaque row ranges from 204 (`climb`) to 238 (`walk`), a 34 px spread in
## art that is meant to share one ground line. `AnimatedSprite2D` has a single
## `offset` for the whole node and no per-animation equivalent, so a scene can
## only ever compensate for one of them; the others float or sink by the
## difference. Normalising here fixes it once for every actor.
##
## Must equal `Player.SOURCE_ART_BASELINE`, which is what the player scene
## compensates for. `tests/test_sprite_frames.gd` asserts they agree.
##
## **This row is the player's, not everyone's.** The 2026-09 roster arrived
## framed lower in its 256 px cell -- Arc's feet sit around row 247, with only a
## few pixels of padding underneath -- so asking for a 24 px lift produced a
## clamped shift and a warning on every single animation. Normalising a boss
## onto the *player's* row is not even the goal: each actor's scene applies its
## own sprite offset, so what matters is that one character's animations agree
## with each other, not that every character agrees with the player.
##
## So the target is per character (see `_character_baseline`), and this constant
## is the one pinned value: the player's, because a scene constant depends on it.
const BASELINE_ROW := 223

## The character whose baseline is pinned to BASELINE_ROW.
const PINNED_CHARACTER := "player"

## Animation names whose baseline shift ran out of cell during the character
## currently being imported. Reset per character by _import_character.
var _clamped: Array[String] = []

## Alpha above which a pixel counts as part of the character rather than as
## anti-aliased edge fringe.
const OPAQUE_THRESHOLD := 0.06

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

	# Decided once for the whole character, before anything is added: every
	# animation is then lifted onto the same row, and which row that is depends
	# on how this character's art happens to sit in its cell.
	var target := _character_baseline(char_dir, character)
	frames.set_meta(&"baseline_row", target)
	# animation name -> head-to-feet height in source px, so a scene can draw
	# every clip of a character at the same world size. See _body_height.
	var body_heights: Dictionary = {}
	# Animations the art physically could not be shifted onto that row, recorded
	# rather than merely warned about: a warning scrolls past, and the tests need
	# to tell "this one had no padding left" from "this one silently drifted".
	_clamped.clear()

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
		if _add_animation(frames, anim_name, sheet, parsed as Dictionary, target):
			imported += 1
			var height := _body_height(sheet, _atlas_regions(parsed as Dictionary))
			if height > 0:
				body_heights[anim_name] = height

	if imported == 0:
		push_warning("%s: nothing imported" % character)
		return false

	var out_path := OUT_ROOT.path_join("%s.tres" % _snake_case(character))
	var err := ResourceSaver.save(frames, out_path)
	if err != OK:
		push_error("%s: save failed (%d)" % [out_path, err])
		return false
	frames.set_meta(&"baseline_clamped", PackedStringArray(_clamped))
	frames.set_meta(&"body_heights", body_heights)
	ResourceSaver.save(frames, out_path)
	print("%s -> %s (%d animations%s)" % [character, out_path, imported,
		"" if _clamped.is_empty() else ", %d clamped" % _clamped.size()])
	return true


## The cell row this character's animations are all normalised onto.
##
## The player is pinned to BASELINE_ROW because `Player.SOURCE_ART_BASELINE`
## depends on it. Everyone else gets the median of their own animations' feet,
## which is by construction a row they can actually reach: normalising to the
## median means half the animations shift up, half shift down, and none of them
## needs more padding than the art already has.
##
## The alternative -- one row for every character in the game -- is what the
## first version did, and it fails the moment a batch is framed differently in
## its cell. Aligning bosses to the *player's* row was never the requirement
## anyway; each actor's scene applies its own sprite offset.
func _character_baseline(char_dir: String, character: String) -> int:
	if _snake_case(character) == PINNED_CHARACTER:
		return BASELINE_ROW

	var baselines: Array[int] = []
	for anim_dir in _subdirs(char_dir):
		var dir := char_dir.path_join(anim_dir)
		var json_path := dir.path_join("atlas.json")
		var sheet_path := dir.path_join("spritesheet.png")
		if not FileAccess.file_exists(json_path) or not ResourceLoader.exists(sheet_path):
			continue
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(json_path))
		if not (parsed is Dictionary):
			continue
		var rects: Dictionary = (parsed as Dictionary).get("frames", {})
		if rects.is_empty():
			continue
		var image := _sheet_image(load(sheet_path))
		if image == null:
			continue
		var baseline := _animation_baseline(image, _atlas_regions(parsed as Dictionary))
		if baseline >= 0:
			baselines.append(baseline)

	if baselines.is_empty():
		return BASELINE_ROW
	baselines.sort()
	return baselines[baselines.size() / 2]


func _add_animation(frames: SpriteFrames, anim_name: String, sheet: Texture2D,
		atlas: Dictionary, target_baseline: int) -> bool:
	var rects: Dictionary = atlas.get("frames", {})
	if rects.is_empty():
		return false

	# Stringified integer keys: sort numerically so frame 10 does not land
	# between 1 and 2.
	var keys: Array = rects.keys()
	keys.sort_custom(func(a: Variant, b: Variant) -> bool:
		return int(str(a)) < int(str(b)))

	# fps comes from the full clip; trimming must not speed the motion up.
	var source_frames := keys.size()
	keys = _trim(anim_name, keys)
	if keys.is_empty():
		return false

	var name := StringName(anim_name)
	if frames.has_animation(name):
		frames.remove_animation(name)
	frames.add_animation(name)
	frames.set_animation_loop(name, anim_name in LOOPING)
	frames.set_animation_speed(name, _fps(atlas, source_frames))

	var regions: Array[Rect2] = []
	for key: Variant in keys:
		var r: Dictionary = rects[key]
		regions.append(Rect2(
			float(r.get("x", 0)), float(r.get("y", 0)),
			float(r.get("w", 0)), float(r.get("h", 0))))

	var shift := _baseline_shift(sheet, regions, anim_name, target_baseline)
	for region in regions:
		var tex := AtlasTexture.new()
		tex.atlas = sheet
		tex.region = region
		# margin.position offsets where the region is drawn while leaving the
		# texture's size alone, so centring is unaffected and the region still
		# samples only its own cell. Verified against 4.7: a size of zero keeps
		# get_size() at the region size and moves the drawn pixels by position.
		if shift != 0.0:
			tex.margin = Rect2(0.0, shift, 0.0, 0.0)
		# Without filter_clip, neighbouring frames bleed in at the region edge.
		tex.filter_clip = true
		frames.add_frame(name, tex)
	return true


## How far to move an animation's art so its feet land on BASELINE_ROW.
##
## Positive moves the art down. The shift is clamped to the transparent padding
## the frames actually have, because a drawn region is clipped to its own box:
## shifting further than the padding would slice pixels off the character. A
## clamp means an animation stays slightly off rather than losing its feet.
func _baseline_shift(sheet: Texture2D, regions: Array[Rect2], anim_name: String,
		target_baseline: int) -> float:
	var image := _sheet_image(sheet)
	if image == null:
		return 0.0
	var baseline := _animation_baseline(image, regions)
	if baseline < 0:
		return 0.0

	var shift: int = target_baseline - baseline
	if shift == 0:
		return 0.0

	# How far the art can move before it runs out of cell to move into.
	var lowest := -1
	var highest := 1 << 30
	for region in regions:
		var used := image.get_region(Rect2i(region)).get_used_rect()
		if used.size.y <= 0:
			continue
		lowest = maxi(lowest, used.position.y + used.size.y - 1)
		highest = mini(highest, used.position.y)

	var cell_height: int = int(regions[0].size.y)
	var room: int = (cell_height - 1 - lowest) if shift > 0 else highest
	if absi(shift) > room:
		var clamped: int = room * signi(shift)
		push_warning("%s: baseline %d wants a %d px shift but only %d px of padding; using %d"
			% [anim_name, baseline, shift, room, clamped])
		if not _clamped.has(anim_name):
			_clamped.append(anim_name)
		shift = clamped
	return float(shift)


## Median lowest opaque row across an animation's frames, or -1 when every frame
## is transparent.
##
## Median rather than mean: a clip that leaves the ground for part of its length
## -- a jump, a death that falls over -- should be aligned by the frames that are
## standing on it, not dragged upward by the ones that are not.
func _animation_baseline(image: Image, regions: Array[Rect2]) -> int:
	var bottoms: Array[int] = []
	for region in regions:
		var used := image.get_region(Rect2i(region)).get_used_rect()
		if used.size.y <= 0:
			continue  # a fully transparent frame carries no baseline
		bottoms.append(used.position.y + used.size.y - 1)
	if bottoms.is_empty():
		return -1
	bottoms.sort()
	return bottoms[bottoms.size() / 2]


## Head-to-feet height of the character in an animation, in source pixels.
##
## **Not the bounding box.** AutoSprite frames every clip independently, so the
## same character is drawn at different sizes from clip to clip -- measured on
## the player, the upright poses alone ranged from 152 to 208 px, so the
## character grew 13% when it started walking and shrank 14% when it stood still
## and fired. A scene that applies one scale factor to all of them reproduces
## that spread exactly.
##
## The bounding box is the wrong ruler for fixing it, because a pose with a
## raised arm or a lifted weapon has a taller box and the same character: scaling
## by the box would *shrink* the character for raising its arm. So the head is
## found instead, as the topmost row carrying at least HEAD_WIDTH_FRACTION of
## the frame's width in opaque pixels -- a thin raised sword or fist does not
## reach that, a head does.
##
## Sampled rather than exhaustive: scanning every row of every frame is millions
## of get_pixel calls per character. Rows are scanned from the top and stop at
## the head, and only SAMPLE_FRAMES frames spread across the clip are measured,
## which is plenty for a median.
const HEAD_WIDTH_FRACTION := 0.15
const SAMPLE_FRAMES := 5

func _body_height(sheet: Texture2D, regions: Array[Rect2]) -> int:
	var image := _sheet_image(sheet)
	if image == null or regions.is_empty():
		return 0

	var heights: Array[int] = []
	var step: int = maxi(1, regions.size() / SAMPLE_FRAMES)
	var index := 0
	while index < regions.size():
		var frame := image.get_region(Rect2i(regions[index]))
		index += step
		var used := frame.get_used_rect()
		if used.size.y <= 0 or used.size.x <= 0:
			continue
		var needed: int = maxi(1, int(ceil(float(used.size.x) * HEAD_WIDTH_FRACTION)))
		var head := -1
		for y in range(used.position.y, used.position.y + used.size.y):
			var run := 0
			for x in range(used.position.x, used.position.x + used.size.x):
				if frame.get_pixel(x, y).a > 0.5:
					run += 1
					if run >= needed:
						break
			if run >= needed:
				head = y
				break
		if head < 0:
			continue
		heights.append(used.position.y + used.size.y - head)

	if heights.is_empty():
		return 0
	heights.sort()
	return heights[heights.size() / 2]


## A sheet's pixels, decompressed if the import settings compressed them.
func _sheet_image(sheet: Texture2D) -> Image:
	if sheet == null:
		return null
	var image := sheet.get_image()
	if image == null:
		return null
	if image.is_compressed() and image.decompress() != OK:
		return null
	return image


## Every frame's region in an atlas, in numeric frame order.
func _atlas_regions(atlas: Dictionary) -> Array[Rect2]:
	var rects: Dictionary = atlas.get("frames", {})
	var keys: Array = rects.keys()
	keys.sort_custom(func(a: Variant, b: Variant) -> bool:
		return int(str(a)) < int(str(b)))
	var out: Array[Rect2] = []
	for key: Variant in keys:
		var r: Dictionary = rects[key]
		out.append(Rect2(float(r.get("x", 0)), float(r.get("y", 0)),
			float(r.get("w", 0)), float(r.get("h", 0))))
	return out


## Keeps only TRIM's slice of an animation's frames, in order.
func _trim(anim_name: String, keys: Array) -> Array:
	if not TRIM.has(anim_name) or keys.is_empty():
		return keys
	var bounds: Array = TRIM[anim_name]
	var first := clampi(int(bounds[0]), 0, keys.size() - 1)
	var last := clampi(int(bounds[1]), first, keys.size() - 1)
	return keys.slice(first, last + 1)


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
