## Parallax backdrop for stage 1, "Dawn Boardwalk".
##
## Built in code from a plate table rather than authored as a .tscn, for the
## same reason as test_room.gd: every entry here exists to hold two numbers --
## its scroll factor and where it sits against the horizon -- and the table says
## which. SPRITES.md section 8a is the source of the scroll factors.
##
## The boardwalk itself is deliberately absent: it is the surface the player
## stands on, so it is a TileMapLayer with collision, not a plate here.
##
## **Two sets, one per band.** Plates are hung against the viewport with zero
## vertical scroll -- they have to be, or the horizon walks off the top of the
## screen when the camera rises -- which means every room gets the same backdrop
## by construction. That was right while the stage was one row of rooms. Once it
## went under the deck, the rooms beneath the boardwalk were still showing the
## sunrise, and read as another stretch of boardwalk rather than the underside
## of the one you just left.
##
## So the band's plates are swapped when the active room changes. The under-deck
## set is **drawn rather than generated**: it is a depth gradient, silhouetted
## columns and shafts of light through the planks -- shapes that describe
## themselves in code, and that want tuning against the tileset rather than
## regenerating. Its palette is sampled from the surface plates, so the two
## bands look like the same world at two depths instead of two art passes.
extends Node2D

## Source art is pixel art authored at 1 art px == 1 NES px, so a plate is
## scaled by the same world_scale as everything else. Plate coordinates below
## are therefore in art pixels, and 240 of them is one viewport height.
const PLATE_DIR := "res://assets/backgrounds/dawn_boardwalk/"

## Copies drawn either side of the origin copy. A plate is a full viewport wide,
## so one either side is already more than a camera can outrun in a frame.
const REPEAT_TIMES := 3

## Where the waterline sits, in plate pixels from the top of the viewport.
##
## Everything in the backdrop is hung off this one number: the skyline stands on
## it, the water starts at it, and the sun clears it. It is set just below the
## sun's disc -- the sun is centred on plate row 100 with a radius of about 26,
## so 130 leaves it fully clear of the water, which is the "low sun just above
## the horizon" the art direction asks for.
const HORIZON := 130.0

## `scroll` is Parallax2D.scroll_scale.x. `top` is the plate's top edge in plate
## pixels from the top of the viewport. `z` orders against the player, who sits
## at the default z of 0 -- so the pilings, alone, are drawn in front of them.
##
## Vertical scroll is 0 on every plate. A plate is placed against the viewport
## rather than the world, so it must not drift when the camera rises or the
## horizon would walk off the top of the screen.
const PLATES := [
	{"name": "Sky", "file": "sky.png", "scroll": 0.05, "top": 0.0, "z": -100},
	{"name": "Skyline", "file": "skyline.png", "scroll": 0.2, "top": HORIZON - 40.0, "z": -90},
	{"name": "Water", "file": "water.png", "scroll": 0.4, "top": HORIZON, "z": -80},
	{"name": "Pilings", "file": "pilings.png", "scroll": 1.2, "top": 156.0, "z": 100},
]

## Plate size for the drawn under-deck set, in art pixels. One viewport tall and
## a little over one wide, matching the surface plates so both bands tile at the
## same rate.
const UNDER_SIZE := Vector2i(400, 240)

## How far down the plate the boardwalk's underside reaches, in art px. Two and
## a bit tiles: enough to read as structure overhead without eating the room.
const SOFFIT_DEPTH := 46

## The under-deck set. Same three columns as PLATES; the texture comes from
## `kind` instead of a file.
const UNDER_PLATES := [
	{"name": "UnderGloom", "kind": "gloom", "scroll": 0.05, "top": 0.0, "z": -100},
	{"name": "UnderColumns", "kind": "columns", "scroll": 0.35, "top": 0.0, "z": -90},
	{"name": "UnderSoffit", "kind": "soffit", "scroll": 0.8, "top": 0.0, "z": -80},
	{"name": "UnderFore", "kind": "foreground", "scroll": 1.3, "top": 0.0, "z": 100},
]

var _bands: Dictionary = {}


func _ready() -> void:
	var autoload := get_node_or_null(^"/root/Tuning")
	var scale_factor: float = autoload.player.world_scale if autoload != null else 4.5

	var surface := Node2D.new()
	surface.name = "Surface"
	add_child(surface)
	_bands[0] = surface
	for plate in PLATES:
		_add_plate(surface, plate, _load_plate(plate), scale_factor)

	var under := Node2D.new()
	under.name = "UnderDeck"
	add_child(under)
	_bands[1] = under
	var palette := _sample_palette()
	for plate in UNDER_PLATES:
		_add_plate(under, plate, _draw_under_plate(String(plate["kind"]), palette),
			scale_factor)

	show_band(0)


## Shows the plates for a band and hides the rest.
##
## Called by the stage on every room change rather than worked out here: which
## band a room is in is the stage's fact, and a backdrop that went looking for
## it would need to know how rooms are laid out.
func show_band(band: int) -> void:
	for key: int in _bands:
		var node: Node2D = _bands[key]
		node.visible = key == band


## The plates for a band, or null if the band has none. Exists so the stage's
## bands and the backdrop's can be checked against each other -- a room in a
## band with no plates draws whatever the last room left up.
func band_node(band: int) -> Node2D:
	return _bands.get(band) as Node2D


func _load_plate(plate: Dictionary) -> Texture2D:
	var path: String = PLATE_DIR + String(plate["file"])
	var texture := load(path) as Texture2D
	if texture == null:
		push_error("dawn_boardwalk: missing plate %s" % path)
	return texture


func _add_plate(into: Node2D, plate: Dictionary, texture: Texture2D,
		scale_factor: float) -> void:
	if texture == null:
		return

	var size := Vector2(texture.get_size()) * scale_factor

	var layer := Parallax2D.new()
	layer.name = String(plate["name"])
	layer.scroll_scale = Vector2(float(plate["scroll"]), 0.0)
	# Tiles horizontally as the room scrolls; 0 on y leaves it un-repeated.
	layer.repeat_size = Vector2(size.x, 0.0)
	# repeat_size alone only says how wide a copy is. Without repeat_times the
	# layer draws one copy and leaves bare viewport either side of it, which is
	# visible the moment the camera moves off the plate's origin.
	layer.repeat_times = REPEAT_TIMES
	layer.z_index = int(plate["z"])
	into.add_child(layer)

	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.centered = false
	sprite.position = Vector2(0.0, float(plate["top"]) * scale_factor)
	sprite.scale = Vector2(scale_factor, scale_factor)
	# The project default is Linear and must stay Linear for the character, which
	# is smooth HD art minified to 0.61x. These plates are the opposite case:
	# pixel art magnified 4.5x, which Linear would blur into mush.
	# CanvasItem.texture_filter is the per-node override that lets both be right
	# in the same frame. See SPRITES.md section 8.
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	layer.add_child(sprite)


# --- The drawn under-deck set -----------------------------------------------------

## Colours lifted from the surface plates, so the two bands read as one world.
##
## Sampled rather than hand-picked: the water plate already holds the palette
## this stage was generated in, and typing approximations of it here would drift
## the moment the art is regenerated. Falls back to fixed values only if the
## plate cannot be read at all.
func _sample_palette() -> Dictionary:
	var deep := Color(0.05, 0.08, 0.16)
	var mid := Color(0.10, 0.16, 0.30)
	var pale := Color(0.55, 0.66, 0.82)

	var water := load(PLATE_DIR + "water.png") as Texture2D
	if water != null:
		var image := water.get_image()
		if image != null:
			if image.is_compressed():
				image.decompress()
			# Both tones come from the *bottom* of the water plate, not its
			# middle. Mid-height is where the sunset reflects, so sampling
			# there tinted the whole under-deck mauve -- pretty, and nothing
			# like being beneath a pier. The bottom rows are the water's own
			# colour with no sky in them.
			deep = image.get_pixel(image.get_width() / 2, image.get_height() - 3)
			mid = image.get_pixel(image.get_width() / 3, image.get_height() - 12)
	var sky := load(PLATE_DIR + "sky.png") as Texture2D
	if sky != null:
		var image := sky.get_image()
		if image != null:
			if image.is_compressed():
				image.decompress()
			# The light coming through the planks is the sky's light.
			pale = image.get_pixel(image.get_width() / 2, 40)

	return {"deep": deep, "mid": mid, "pale": pale}


func _draw_under_plate(kind: String, palette: Dictionary) -> Texture2D:
	var image := Image.create(UNDER_SIZE.x, UNDER_SIZE.y, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	match kind:
		"gloom":
			_draw_gloom(image, palette)
		"columns":
			_draw_columns(image, palette, 4, 7, 0.55)
		"soffit":
			_draw_soffit(image, palette)
		"foreground":
			_draw_columns(image, palette, 2, 16, 1.0)
	return ImageTexture.create_from_image(image)


## The water column itself: light near the surface, black further down.
func _draw_gloom(image: Image, palette: Dictionary) -> void:
	# Both ends are the deep-water tone: a little lifted where the light gets in
	# under the planks, and much darker below. Keeping one hue is what makes it
	# read as depth rather than as a colour wash.
	var top_tone: Color = (palette["deep"] as Color).lightened(0.14)
	var bottom_tone: Color = (palette["deep"] as Color).darkened(0.45)
	for y in UNDER_SIZE.y:
		# Darkens with depth, and fastest just under the deck where the light
		# from above runs out.
		var t := clampf(float(y) / float(UNDER_SIZE.y), 0.0, 1.0)
		var row := top_tone.lerp(bottom_tone, sqrt(t))
		image.fill_rect(Rect2i(0, y, UNDER_SIZE.x, 1), row)

	# The horizontal streaks the surface water plate uses, carried down here so
	# the two bands share a texture vocabulary. Thinner and rarer with depth.
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260903
	for i in 70:
		var y := rng.randi_range(SOFFIT_DEPTH, UNDER_SIZE.y - 1)
		var depth := float(y) / float(UNDER_SIZE.y)
		if rng.randf() < depth * 0.8:
			continue  # fewer of them further down
		var w := rng.randi_range(6, 26)
		var x := rng.randi_range(0, UNDER_SIZE.x - w)
		var streak: Color = (palette["deep"] as Color).lerp(palette["pale"],
			0.30 * (1.0 - depth))
		image.fill_rect(Rect2i(x, y, w, 1), streak)


## Piling columns descending out of sight.
func _draw_columns(image: Image, palette: Dictionary, count: int, width: int,
		darkness: float) -> void:
	var deep: Color = palette["deep"]
	var mid: Color = palette["mid"]
	var body := mid.lerp(deep, darkness)
	var lit := body.lerp(palette["pale"], 0.22)

	var rng := RandomNumberGenerator.new()
	rng.seed = 4711 + count
	var step := UNDER_SIZE.x / maxi(count, 1)
	for i in count:
		var x := i * step + rng.randi_range(4, maxi(step - width - 4, 6))
		# Columns start at the soffit and run off the bottom of the plate: the
		# player never sees a piling end, which is what sells the depth.
		image.fill_rect(Rect2i(x, SOFFIT_DEPTH - 4, width, UNDER_SIZE.y), body)
		# One lit edge, on the side the sun is on.
		image.fill_rect(Rect2i(x, SOFFIT_DEPTH - 4, maxi(width / 4, 1),
			UNDER_SIZE.y), lit)
		# Cross-bracing, so a column reads as built rather than as a bar.
		var brace := SOFFIT_DEPTH + 26
		while brace < UNDER_SIZE.y:
			image.fill_rect(Rect2i(maxi(x - 3, 0), brace, width + 6, 3), lit)
			brace += rng.randi_range(52, 78)


## The underside of the boardwalk, and the light coming through it.
func _draw_soffit(image: Image, palette: Dictionary) -> void:
	var deep: Color = palette["deep"]
	var pale: Color = palette["pale"]
	var beam := deep.darkened(0.25)

	# The planks, seen from beneath.
	image.fill_rect(Rect2i(0, 0, UNDER_SIZE.x, SOFFIT_DEPTH), beam)
	# Joists across them, picked out slightly lighter.
	var joist := beam.lerp(pale, 0.12)
	var x := 0
	while x < UNDER_SIZE.x:
		image.fill_rect(Rect2i(x, 0, 3, SOFFIT_DEPTH), joist)
		x += 19

	# Light through the gaps between planks: a wedge widening and fading as it
	# falls. This is the whole reason the under-deck reads as *under* something
	# rather than as a dark room.
	var rng := RandomNumberGenerator.new()
	rng.seed = 90210
	for i in 11:
		var gap_x := rng.randi_range(8, UNDER_SIZE.x - 8)
		var length := rng.randi_range(90, 180)
		for step in length:
			var y := SOFFIT_DEPTH + step
			if y >= UNDER_SIZE.y:
				break
			var spread := 1 + step / 12
			var fade := 1.0 - float(step) / float(length)
			var shaft := Color(pale.r, pale.g, pale.b, 0.30 * fade * fade)
			image.fill_rect(Rect2i(maxi(gap_x - spread, 0), y,
				mini(spread * 2, UNDER_SIZE.x), 1), shaft)
