## Renders every weapon's suit colour onto one sheet, so a colour choice can be
## looked at rather than argued about.
##
##   godot --headless --script res://tools/suit_sheet.gd [-- out.png [floors]]
##
## `floors` is a comma-separated list of `grey_floor` values -- one row each,
## same weapons across -- for judging that dial against the thing it trades:
##
##   godot --headless --script res://tools/suit_sheet.gd -- cmp.png 0.12,0.4,0.7,1
##
## The dial decides how much of the rotation the *near-grey* pixels take, so it
## is the trade between a suit landing on the colour it was declared as and the
## outline staying where the artist put it. A row at 1.0 is a plain hue rotation
## with no protection at all, which is the thing SPRITES.md section 3 rejected --
## it is in the range so that the rejection can be seen rather than taken on
## trust.
##
## **The shader is applied on the CPU here**, not by the renderer, and that needs
## saying because a copy of a shader is a thing that drifts. It is done this way
## because the alternative is a real viewport, and a headless run has no display
## while an `xvfb` run has to build the whole game to draw one sprite. The maths
## below is `weapon_palette.gdshader`'s `fragment()` line for line -- convert to
## HSV, weight the rotation by saturation, leave luminance alone -- and it is
## twelve lines rather than a file, so the copy is small enough to check by eye
## against the original.
##
## Development tool: not referenced by the game or by CI.
extends SceneTree

const SHEET := "res://assets/sprites/player/idle_right/spritesheet.png"
## The frame taken from that sheet. 256 is the cell size of every generated
## player sheet in the project (SPRITES.md section 7).
const FRAME := 256
const PAD := 10
const COLS := 6
const DEFAULT_OUT := "user://suit_sheet.png"

## The weapons a comparison row shows, in wheel order from the buster.
##
## Six rather than twelve, and these six: the warm end is where the saturation
## weighting bites hardest, so Arc, Quarry and Rust are the three that show what
## the dial does. The buster is the control -- it is a no-op at every floor, so a
## row where it has changed means the sheet is wrong rather than the dial.
const COMPARISON := [&"buster", &"tide_crawler", &"arc_lance", &"quarry_bore",
	&"rust_bloom", &"prism_ray"]


func _initialize() -> void:
	var weapons := root.get_node_or_null(^"WeaponManager")
	if weapons == null:
		printerr("no WeaponManager; run this from the project root")
		quit(1)
		return

	# **The autoload's `_ready` has not run yet.** A `SceneTree` script's
	# `_initialize` happens before the first frame, so `WeaponManager` exists as a
	# node and its catalogue is empty -- which reads as "no buster" and is not.
	# `load_catalogue()` is documented as safe to call twice, so asking for it is
	# cheaper than waiting a frame and clearer than wondering why.
	weapons.load_catalogue()

	var base: WeaponData = weapons.data_for(&"buster")
	if base == null:
		printerr("no buster to measure from")
		quit(1)
		return

	var src := Image.load_from_file(SHEET)
	src.convert(Image.FORMAT_RGBA8)
	var floors := _floors()
	var out: Image
	if floors.is_empty():
		out = _catalogue_sheet(src, weapons, base)
	else:
		out = _comparison_sheet(src, weapons, base, floors)

	var path := _out_path()
	out.resize(out.get_width() / 2, out.get_height() / 2, Image.INTERPOLATE_LANCZOS)
	if out.save_png(path) != OK:
		printerr("could not write %s" % path)
		quit(1)
		return
	print("-> %s" % ProjectSettings.globalize_path(path))
	quit(0)


## Every weapon once, at the grey floor the game actually uses.
func _catalogue_sheet(src: Image, weapons: Node, base: WeaponData) -> Image:
	var ids := _catalogue()
	var rows := int(ceil(float(ids.size()) / float(COLS)))
	var out := _blank(COLS, rows)
	var drawn := 0
	for id in ids:
		var data: WeaponData = weapons.data_for(id)
		if data == null:
			continue
		var shift := wrapf(data.suit_colour().h - base.suit_colour().h, -0.5, 0.5)
		_stamp(src, out, drawn % COLS, drawn / COLS, shift,
			Player.PALETTE_GREY_FLOOR)
		print("%-14s %+0.3f turns (%+4.0f deg)" % [id, shift, shift * 360.0])
		drawn += 1
	return out


## One row per grey floor, the same six weapons across each.
func _comparison_sheet(src: Image, weapons: Node, base: WeaponData,
		floors: PackedFloat32Array) -> Image:
	var out := _blank(COMPARISON.size(), floors.size())
	for row in floors.size():
		var names: Array[String] = []
		for col in COMPARISON.size():
			var data: WeaponData = weapons.data_for(COMPARISON[col])
			if data == null:
				continue
			var shift := wrapf(data.suit_colour().h - base.suit_colour().h, -0.5, 0.5)
			_stamp(src, out, col, row, shift, floors[row])
			names.append(String(COMPARISON[col]))
		print("row %d: grey_floor %.2f  [%s]" % [row, floors[row], ", ".join(names)])
	return out


func _blank(cols: int, rows: int) -> Image:
	var img := Image.create(PAD + cols * (FRAME + PAD),
		PAD + rows * (FRAME + PAD), false, Image.FORMAT_RGBA8)
	img.fill(Color(0.09, 0.10, 0.13, 1.0))
	return img


## The `grey_floor` values asked for, or empty for the ordinary sheet.
func _floors() -> PackedFloat32Array:
	var out := PackedFloat32Array()
	var args := OS.get_cmdline_user_args()
	if args.size() < 2:
		return out
	for piece in String(args[1]).split(",", false):
		if piece.strip_edges().is_valid_float():
			out.append(clampf(piece.strip_edges().to_float(), 0.0, 1.0))
	return out


## One sprite, recoloured. `weapon_palette.gdshader`'s fragment shader, in
## GDScript.
func _stamp(src: Image, out: Image, col: int, row: int, shift: float,
		grey_floor: float) -> void:
	var ox := PAD + col * (FRAME + PAD)
	var oy := PAD + row * (FRAME + PAD)
	for y in FRAME:
		for x in FRAME:
			var px := src.get_pixel(x, y)
			if px.a <= 0.0:
				continue
			var tinted := px
			if absf(shift) >= 0.0005:
				# Saturation decides how far a pixel travels, so the near-grey
				# outline and highlights stay where the artist put them.
				var weight := lerpf(grey_floor, 1.0, px.s)
				tinted = Color.from_hsv(fposmod(px.h + shift * weight, 1.0),
					clampf(px.s * Player.PALETTE_SATURATION, 0.0, 1.0), px.v, px.a)
			out.set_pixel(ox + x, oy + y,
				out.get_pixel(ox + x, oy + y).lerp(tinted, px.a))


## Every weapon on disk, in a fixed order so two runs can be compared.
func _catalogue() -> Array[StringName]:
	var out: Array[StringName] = []
	var dir := DirAccess.open("res://resources/weapons")
	if dir == null:
		return out
	var names := dir.get_files()
	names.sort()
	for file in names:
		if file.ends_with(".tres"):
			out.append(StringName(file.get_basename()))
	return out


func _out_path() -> String:
	var args := OS.get_cmdline_user_args()
	return args[0] if args.size() > 0 else DEFAULT_OUT
