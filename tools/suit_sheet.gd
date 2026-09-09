## Renders every weapon's suit colour onto one sheet, so a colour choice can be
## looked at rather than argued about.
##
##   godot --headless --script res://tools/suit_sheet.gd [-- out.png]
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

	var ids := _catalogue()
	var base: WeaponData = weapons.data_for(&"buster")
	if base == null:
		printerr("no buster to measure from")
		quit(1)
		return

	var src := Image.load_from_file(SHEET)
	src.convert(Image.FORMAT_RGBA8)
	var rows := int(ceil(float(ids.size()) / float(COLS)))
	var out := Image.create(PAD + COLS * (FRAME + PAD),
		PAD + rows * (FRAME + PAD), false, Image.FORMAT_RGBA8)
	out.fill(Color(0.09, 0.10, 0.13, 1.0))

	var drawn := 0
	for id in ids:
		var data: WeaponData = weapons.data_for(id)
		if data == null:
			continue
		var shift := wrapf(data.suit_colour().h - base.suit_colour().h, -0.5, 0.5)
		_stamp(src, out, drawn, shift)
		print("%-14s %+0.3f turns (%+4.0f deg)" % [id, shift, shift * 360.0])
		drawn += 1

	var path := _out_path()
	out.resize(out.get_width() / 2, out.get_height() / 2, Image.INTERPOLATE_LANCZOS)
	if out.save_png(path) != OK:
		printerr("could not write %s" % path)
		quit(1)
		return
	print("%d suits -> %s" % [drawn, ProjectSettings.globalize_path(path)])
	quit(0)


## One sprite, recoloured. `weapon_palette.gdshader`'s fragment shader, in
## GDScript.
func _stamp(src: Image, out: Image, slot: int, shift: float) -> void:
	var ox := PAD + (slot % COLS) * (FRAME + PAD)
	var oy := PAD + (slot / COLS) * (FRAME + PAD)
	for y in FRAME:
		for x in FRAME:
			var px := src.get_pixel(x, y)
			if px.a <= 0.0:
				continue
			var col := px
			if absf(shift) >= 0.0005:
				# Saturation decides how far a pixel travels, so the near-grey
				# outline and highlights stay where the artist put them.
				var weight := lerpf(Player.PALETTE_GREY_FLOOR, 1.0, px.s)
				col = Color.from_hsv(fposmod(px.h + shift * weight, 1.0),
					clampf(px.s * Player.PALETTE_SATURATION, 0.0, 1.0), px.v, px.a)
			out.set_pixel(ox + x, oy + y,
				out.get_pixel(ox + x, oy + y).lerp(col, px.a))


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
