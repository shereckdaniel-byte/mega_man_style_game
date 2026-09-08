## Parallax backdrop for stage 4, "Mirror Field".
##
## Same shape and the same `show_band` / `band_node` contract as stages 1-3 --
## `AuthoredStage` swaps bands on a room change and does not care which stage it
## is talking to. Two bands here: the salt pan the array stands on, and the
## receiver tower's platform at the top of the stage's one climb.
##
## ### This is the bright one, and that is a decision about the set
##
## Three stages so far are a dawn, a blackout and a rust yard. Their palettes are
## all low and warm-to-cold, and a fourth in that register would read as more of
## the same world seen again rather than as somewhere new. A heliostat field at
## noon is the strongest contrast available inside the same drowned coast: a
## bleached sky, white salt, and a field of mirrors throwing the sun back at it.
##
## It is also what makes the gimmick legible. A `PhaseBlock`'s panel is pale
## glass and its mount is dark steel, so the thing that has to read from across
## the room -- **which mounts are full and which are empty** -- reads as light
## against dark on a bright ground and would be dark-on-dark on any of the other
## three.
##
## ### The sun stays on the sky plate
##
## The rule `tests/test_backdrops.gd` exists for: a landmark lives on exactly one
## plate, or the copies slide apart. Stage 1 drew the sun's reflection into the
## water, stage 2's keying left the moon behind as an island, and stage 3's
## generated sky came back with a whole scene in it that had to be cropped above
## its own horizon. All three are the same fault. **A field of mirrors is the
## worst possible place to get this wrong** -- every panel in the middle
## distance is a specular highlight, and highlights that scroll at 0.2 against a
## sun at 0.05 are a sky with the light coming from two places.
##
## So the sun is on `sky.png` and nowhere else, and the mirror rows carry no
## bright pixels at all: they are silhouette and haze, which is what a mirror
## looks like when it is pointed somewhere other than at you.
extends Node2D

## Source art is authored at 1 art px == 1 NES px, so a plate scales by the same
## world_scale as everything else and plate coordinates are in art pixels --
## 240 of them is one viewport height.
const PLATE_DIR := "res://assets/backgrounds/mirror_field/"

## Copies drawn either side of the origin copy. A plate is a full viewport wide,
## so one either side is already more than a camera can outrun in a frame.
const REPEAT_TIMES := 3

## Where the pan's surface sits in each band, in plate pixels from the top of the
## viewport.
##
## A room is one screen tall with its deck on row 11 of 15, so the deck lands at
## 11/15 of 240 = 176 plate px. Stage 3 shipped its waterline at 150 and put its
## own walkway sixteen pixels under the sea; the number is written down here
## rather than eyeballed for exactly that reason.
const DECK_PLATE_ROW := 176.0
const HORIZON_FIELD := DECK_PLATE_ROW
## The tower sees further. Eight plate pixels of extra horizon and the rows drawn
## at 0.6 scale, **both axes** -- squashing only the height gives a field of
## stubby mirrors at the same apparent distance rather than a field further away
## (SPRITES.md section 8c).
const HORIZON_TOWER := DECK_PLATE_ROW - 8.0

## Vertical scroll is 0 on every plate. A plate is placed against the viewport
## rather than the world, so it must not drift when the camera rises, or the
## horizon walks off the top of the screen.
##
## `z` orders against the player, who sits at the default z of 0.
const FIELD_PLATES := [
	{"name": "Sky", "file": "sky.png", "scroll": 0.05, "top": 0.0, "z": -100},
	{"name": "Rows", "file": "rows.png", "scroll": 0.2,
		"top": HORIZON_FIELD - 88.0, "z": -90},
	{"name": "Pan", "file": "pan.png", "scroll": 0.4, "top": HORIZON_FIELD,
		"z": -80},
]

const TOWER_PLATES := [
	{"name": "Sky", "file": "sky.png", "scroll": 0.05, "top": 0.0, "z": -100},
	{"name": "Rows", "file": "rows.png", "scroll": 0.18,
		"top": HORIZON_TOWER - 56.0, "z": -90, "scale": 0.6},
	{"name": "Pan", "file": "pan.png", "scroll": 0.35, "top": HORIZON_TOWER,
		"z": -80},
]

const BAND_TOWER := 0
const BAND_FIELD := 1

var _bands: Dictionary = {}


func _ready() -> void:
	_bands[BAND_TOWER] = _build_band("Tower", TOWER_PLATES)
	_bands[BAND_FIELD] = _build_band("Field", FIELD_PLATES)
	show_band(BAND_FIELD)


## Shows one band's plates and hides the others.
func show_band(band: int) -> void:
	for key in _bands:
		var node: Node2D = _bands[key]
		if node != null:
			node.visible = key == band


func band_node(band: int) -> Node2D:
	return _bands.get(band, null)


func _build_band(name: String, plates: Array) -> Node2D:
	var holder := Node2D.new()
	holder.name = name
	add_child(holder)
	for plate in plates:
		var texture := _load_plate(plate)
		if texture == null:
			continue
		_add_plate(holder, plate, texture)
	return holder


func _load_plate(plate: Dictionary) -> Texture2D:
	var path: String = PLATE_DIR + String(plate["file"])
	if not ResourceLoader.exists(path):
		# Loud, not silent. A missing plate is a hole in the sky, and the
		# symptom -- a band of flat colour where the horizon should be -- looks
		# exactly like art nobody made.
		push_error("mirror_field: missing plate %s" % path)
		return null
	return load(path) as Texture2D


func _add_plate(into: Node2D, plate: Dictionary, texture: Texture2D) -> void:
	var autoload := get_node_or_null(^"/root/Tuning")
	var world: float = autoload.player.world_scale if autoload != null else 4.5
	# Optional per-plate scale, for a plate that is the same art seen from
	# further away. Both axes, deliberately -- see HORIZON_TOWER.
	var art: float = float(plate.get("scale", 1.0))
	var scale_factor := world * art

	var layer := Parallax2D.new()
	layer.name = String(plate["name"])
	layer.scroll_scale = Vector2(float(plate["scroll"]), 0.0)
	layer.repeat_size = Vector2(float(texture.get_width()) * scale_factor, 0.0)
	layer.repeat_times = REPEAT_TIMES
	# Against the viewport, not the world: see the note on vertical scroll above.
	layer.follow_viewport = true
	into.add_child(layer)

	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.centered = false
	sprite.scale = Vector2(scale_factor, scale_factor)
	# `top` is in plate pixels against the viewport, so it scales by world and
	# not by the plate's own art scale -- a plate drawn smaller must still sit on
	# the horizon the band put it on.
	sprite.position = Vector2(0.0, float(plate["top"]) * world)
	sprite.z_index = int(plate["z"])
	# Pixel art magnified: nearest, like the tilesets. The project default is
	# Linear and must stay Linear for the character (SPRITES.md section 8).
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	layer.add_child(sprite)
