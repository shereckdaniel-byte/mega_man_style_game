## Builds TileSet resources with collision from PixelLab tileset exports.
##
## Same shape as AutoSpriteImporter and for the same reason: the logic lives in
## a plain RefCounted because EditorScript cannot be run headless, and a thin
## SceneTree entry point wraps it for the command line.
##
##   tools/pixellab_tileset_import.gd   SceneTree, for the command line
##
## EXPORT LAYOUT (verified against a real export, 2026-09)
##
##   assets/tilesets/<stage>/
##     tileset.png    4x4 grid of 16 px tiles, transparent background
##     tileset.json   the /metadata response, saved verbatim
##
## WHAT THE METADATA MEANS
##
## The layout is `tileset15_4x4`: a Wang *corner* set. Each tile is named
## `wang_N`, and N's bits say which of its four corners are background:
##
##   1 = SE   2 = SW   4 = NE   8 = NW      bit set == background, clear == solid
##
## So `wang_0` is fully solid interior and `wang_15` is fully empty -- which is
## why the layout is called tileset15 and not tileset16. Fifteen tiles carry
## terrain; the sixteenth is the "no tile" case and is deliberately not created.
##
## Corner terrain means the terrain grid is offset half a tile from the visual
## grid: `wang_12` (both north corners background) is a top-surface tile whose
## solid half is its *bottom* half, with the plank surface drawn across the
## middle. Collision follows the art, not the tile bounds -- see _quadrants.
##
## The corner data was checked against the art's own alpha channel across all
## sixteen tiles before being trusted for collision, and agreed exactly.
class_name PixelLabTilesetImporter
extends RefCounted

const SRC_ROOT := "res://assets/tilesets"
const OUT_ROOT := "res://resources/tilesets"

## Bit -> the corner it marks as background. See the header.
const CORNER_BITS := {"NW": 8, "NE": 4, "SW": 2, "SE": 1}

## Godot's corner neighbours, in the same key order.
const CORNER_NEIGHBOURS := {
	"NW": TileSet.CELL_NEIGHBOR_TOP_LEFT_CORNER,
	"NE": TileSet.CELL_NEIGHBOR_TOP_RIGHT_CORNER,
	"SW": TileSet.CELL_NEIGHBOR_BOTTOM_LEFT_CORNER,
	"SE": TileSet.CELL_NEIGHBOR_BOTTOM_RIGHT_CORNER,
}

## Collision layer 1, "world" -- the same bit the tuning room's solids use, and
## the one the player's mask already looks for. Mask is 0: static terrain has no
## reason to detect anything itself.
const WORLD_LAYER := 1 << 0

var _failed := false


func run() -> bool:
	_failed = false
	var dirs := _stage_dirs()
	if dirs.is_empty():
		push_error("no tilesets under %s" % SRC_ROOT)
		return false

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_ROOT))
	for stage in dirs:
		_import(stage)
	return not _failed


func _stage_dirs() -> PackedStringArray:
	var out := PackedStringArray()
	var dir := DirAccess.open(SRC_ROOT)
	if dir == null:
		return out
	for name in dir.get_directories():
		if FileAccess.file_exists("%s/%s/tileset.json" % [SRC_ROOT, name]):
			out.append(name)
	out.sort()
	return out


func _import(stage: String) -> void:
	var json_path := "%s/%s/tileset.json" % [SRC_ROOT, stage]
	var png_path := "%s/%s/tileset.png" % [SRC_ROOT, stage]

	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(json_path))
	if not (parsed is Dictionary):
		push_error("%s: could not parse" % json_path)
		_failed = true
		return
	var meta: Dictionary = parsed["tileset_data"]

	var texture := load(png_path) as Texture2D
	if texture == null:
		push_error("%s: missing texture" % png_path)
		_failed = true
		return

	var tile_size := Vector2i(int(meta["tile_size"]["width"]), int(meta["tile_size"]["height"]))

	var tileset := TileSet.new()
	tileset.tile_size = tile_size
	tileset.add_physics_layer()
	tileset.set_physics_layer_collision_layer(0, WORLD_LAYER)
	tileset.set_physics_layer_collision_mask(0, 0)
	tileset.add_terrain_set()
	tileset.set_terrain_set_mode(0, TileSet.TERRAIN_MODE_MATCH_CORNERS)
	tileset.add_terrain(0)
	tileset.set_terrain_name(0, 0, stage)

	var source := TileSetAtlasSource.new()
	source.texture = texture
	source.texture_region_size = tile_size
	tileset.add_source(source, 0)

	var created := 0
	for entry in meta["tiles"]:
		var tile: Dictionary = entry
		var background := _background_mask(tile)
		# The all-background tile is the "no tile" case, not a tile.
		if background == 15:
			continue

		var box: Dictionary = tile["bounding_box"]
		var coords := Vector2i(int(box["x"]) / tile_size.x, int(box["y"]) / tile_size.y)
		source.create_tile(coords)
		var data := source.get_tile_data(coords, 0)

		for rect in _quadrants(background, tile_size):
			var index := data.get_collision_polygons_count(0)
			data.add_collision_polygon(0)
			data.set_collision_polygon_points(0, index, rect)

		data.terrain_set = 0
		data.terrain = 0
		for corner in CORNER_BITS:
			if background & int(CORNER_BITS[corner]) == 0:
				data.set_terrain_peering_bit(CORNER_NEIGHBOURS[corner], 0)
		created += 1

	var out_path := "%s/%s.tres" % [OUT_ROOT, stage]
	var err := ResourceSaver.save(tileset, out_path)
	if err != OK:
		push_error("%s: save failed (%d)" % [out_path, err])
		_failed = true
		return
	print("%s: %d tiles -> %s" % [stage, created, out_path])


func _background_mask(tile: Dictionary) -> int:
	var mask := 0
	for corner in CORNER_BITS:
		if String(tile["corners"][corner]) == "upper":
			mask |= int(CORNER_BITS[corner])
	return mask


## Solid quadrants as polygons, in tile-local coordinates -- Godot puts the
## origin at the tile's centre, so a 16 px tile spans -8..+8.
##
## Merged where they are adjacent so the common cases cost one convex polygon
## rather than four: a full tile is one box, a surface tile one half-box. The
## physics result is identical either way; the polygon count is not.
func _quadrants(background: int, tile_size: Vector2i) -> Array:
	var half := Vector2(tile_size) * 0.5
	var solid := {}
	for corner in CORNER_BITS:
		solid[corner] = background & int(CORNER_BITS[corner]) == 0

	if solid["NW"] and solid["NE"] and solid["SW"] and solid["SE"]:
		return [_box(-half.x, -half.y, half.x, half.y)]

	var out := []
	# North row, then south row; merge the pair when both halves are solid.
	for row in [["NW", "NE", -half.y, 0.0], ["SW", "SE", 0.0, half.y]]:
		var west: bool = solid[row[0]]
		var east: bool = solid[row[1]]
		var top: float = row[2]
		var bottom: float = row[3]
		if west and east:
			out.append(_box(-half.x, top, half.x, bottom))
		elif west:
			out.append(_box(-half.x, top, 0.0, bottom))
		elif east:
			out.append(_box(0.0, top, half.x, bottom))
	return out


func _box(x0: float, y0: float, x1: float, y1: float) -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(x0, y0), Vector2(x1, y0), Vector2(x1, y1), Vector2(x0, y1),
	])
