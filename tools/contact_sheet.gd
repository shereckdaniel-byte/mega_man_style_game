## Writes a contact sheet of one character's animations, so a batch of generated
## art can be judged frame by frame before it is judged in the game.
##
##   godot --headless --script res://tools/contact_sheet.gd -- <out_dir>
##   godot --headless --script res://tools/contact_sheet.gd -- <out_dir> character=arc
##   godot --headless --script res://tools/contact_sheet.gd -- <out_dir> raw=true
##
## **PLAN's risk table and SPRITES section 4a both say to check a contact sheet
## before judging a new animation, and until M6l there was no way to make one.**
## Every mistake those two documents record was visible on a sheet and found
## somewhere more expensive: a ladder baked into `climb`, a spawner drawn
## mid-stride, an `attack` that was the cannon shot again, and a `TRIM` range
## pointed at the frames where the sword is being put away.
##
## Two modes, and the difference is the point:
##
##   default   the imported SpriteFrames -- trimmed, and shifted onto the
##             character's baseline row, which is drawn as a red rule. This is
##             what the game will show. Read it for "does this land on the floor"
##             and "does the move read at the length it actually plays".
##   raw=true  every source frame, untrimmed and unshifted. This is what you need
##             *before* setting TRIM, because the frames a trim has to choose
##             between are exactly the ones the default mode has thrown away.
##
## Development tool: not referenced by the game or by CI.
extends SceneTree

const SRC_ROOT := "res://assets/sprites"
const FRAMES_DIR := "res://resources/sprite_frames"

## Side of one frame in the output, in px. Small enough that 25 frames fit on a
## screen, large enough to see a hand.
const CELL := 128
const COLS := 13

const GROUND := Color(0.10, 0.11, 0.14, 1.0)
const RULE := Color(1.0, 0.35, 0.35, 1.0)
const GUTTER := Color(0.25, 0.27, 0.33, 1.0)


func _initialize() -> void:
	var out_dir := "user://"
	var character := "player"
	var raw := false
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("character="):
			character = argument.trim_prefix("character=")
		elif argument.begins_with("raw="):
			raw = argument.trim_prefix("raw=").to_lower() in ["1", "true", "yes"]
		else:
			out_dir = argument

	var path := "%s/%s_contact%s.png" % [out_dir.rstrip("/"), character,
		"_raw" if raw else ""]
	var image := _raw_sheet(character) if raw else _imported_sheet(character)
	if image == null:
		quit(1)
		return
	var err := image.save_png(path)
	print("%s  %s (%dx%d)" % ["ok " if err == OK else "ERR", path,
		image.get_width(), image.get_height()])
	quit(0 if err == OK else 1)


## The imported resource: what the game draws, baseline rule included.
func _imported_sheet(character: String) -> Image:
	var res_path := "%s/%s.tres" % [FRAMES_DIR, character]
	if not ResourceLoader.exists(res_path):
		push_error("no %s -- run tools/autosprite_import.gd first" % res_path)
		return null
	var frames: SpriteFrames = load(res_path)
	var names := frames.get_animation_names()
	names.sort()
	var baseline: int = frames.get_meta(&"baseline_row", -1)
	var clamped: PackedStringArray = frames.get_meta(&"baseline_clamped",
		PackedStringArray())

	var rows := 0
	for name in names:
		rows += _rows_for(frames.get_frame_count(name))
	var out := _blank(rows)
	var row := 0
	for name in names:
		var count := frames.get_frame_count(name)
		for i in count:
			var tex := frames.get_frame_texture(name, i) as AtlasTexture
			if tex == null:
				continue
			# margin.position.y is the shift the importer applied; drawing it in
			# means the sheet shows the art where the game puts it, not where
			# AutoSprite left it.
			var cell := _cut(_image_of(tex.atlas), tex.region,
				int(tex.margin.position.y))
			_paste(out, cell, i % COLS, row + i / COLS, baseline, tex.region.size.y)
		print("%-14s %2d frames%s" % [name, count,
			"   CLAMPED" if clamped.has(String(name)) else ""])
		row += _rows_for(count)
	return out


## Every source frame as exported: no trim, no baseline shift, no rule to line up
## against, because none of those exist yet at the point this mode is for.
func _raw_sheet(character: String) -> Image:
	var char_dir := _find_character(SRC_ROOT, character)
	if char_dir == "":
		push_error("no character directory named %s under %s" % [character, SRC_ROOT])
		return null

	var anims: Array[Dictionary] = []
	var rows := 0
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
		var keys: Array = rects.keys()
		keys.sort_custom(func(a: Variant, b: Variant) -> bool:
			return int(str(a)) < int(str(b)))
		anims.append({"name": anim_dir, "keys": keys, "rects": rects,
			"sheet": sheet_path})
		rows += _rows_for(keys.size())

	if anims.is_empty():
		push_error("%s has no animations" % char_dir)
		return null

	var out := _blank(rows)
	var row := 0
	for anim in anims:
		var image := _image_of(load(anim["sheet"]))
		var keys: Array = anim["keys"]
		for i in keys.size():
			var r: Dictionary = anim["rects"][keys[i]]
			var region := Rect2(float(r.get("x", 0)), float(r.get("y", 0)),
				float(r.get("w", 0)), float(r.get("h", 0)))
			_paste(out, _cut(image, region, 0), i % COLS, row + i / COLS, -1, 0.0)
		print("%-24s %2d frames" % [anim["name"], keys.size()])
		row += _rows_for(keys.size())
	return out


func _rows_for(frame_count: int) -> int:
	return maxi(1, int(ceil(float(frame_count) / float(COLS))))


func _blank(rows: int) -> Image:
	var out := Image.create(CELL * COLS, CELL * maxi(rows, 1), false,
		Image.FORMAT_RGBA8)
	out.fill(GROUND)
	return out


func _image_of(texture: Texture2D) -> Image:
	var image := texture.get_image()
	image.decompress()
	image.convert(Image.FORMAT_RGBA8)
	return image


## One frame, shifted by `offset_y` inside its own cell and scaled to CELL.
func _cut(sheet: Image, region: Rect2, offset_y: int) -> Image:
	var cell := Image.create(int(region.size.x), int(region.size.y), false,
		Image.FORMAT_RGBA8)
	cell.fill(Color(0.0, 0.0, 0.0, 0.0))
	cell.blit_rect(sheet, Rect2i(region), Vector2i(0, offset_y))
	cell.resize(CELL, CELL, Image.INTERPOLATE_LANCZOS)
	return cell


## `baseline` and `source_height` draw the ground rule; pass -1 for no rule.
func _paste(out: Image, cell: Image, col: int, row: int, baseline: int,
		source_height: float) -> void:
	var x := col * CELL
	var y := row * CELL
	out.blend_rect(cell, Rect2i(0, 0, CELL, CELL), Vector2i(x, y))
	for down in CELL:
		out.set_pixel(x, y + down, GUTTER)
	if baseline < 0 or source_height <= 0.0:
		return
	var rule := int(round(float(baseline) / source_height * float(CELL)))
	if rule < 0 or rule >= CELL:
		return
	for across in CELL:
		out.set_pixel(x + across, y + rule, RULE)


func _find_character(root: String, wanted: String) -> String:
	for entry in _subdirs(root):
		var path := root.path_join(entry)
		if entry.to_lower() == wanted.to_lower():
			return path
		var found := _find_character(path, wanted)
		if found != "":
			return found
	return ""


func _subdirs(path: String) -> PackedStringArray:
	var dir := DirAccess.open(path)
	if dir == null:
		return []
	var out: PackedStringArray = dir.get_directories()
	out.sort()
	return out
