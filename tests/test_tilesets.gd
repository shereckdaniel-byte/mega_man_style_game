## Lints the generated TileSets and the corner decoding that produces them.
##
## These are build output (tools/pixellab_tileset_import.gd), and the failure
## mode is quiet in a way that only shows up as a physics bug: a tile whose
## collision does not match its art gives a player who stands on thin air or
## clips into a plank, and nothing complains at import time.
extends TestCase

const TILESET_DIR := "res://resources/tilesets"
const SOURCE_DIR := "res://assets/tilesets"

var importer: PixelLabTilesetImporter


func before_each() -> void:
	importer = PixelLabTilesetImporter.new()


# --- Corner decoding ----------------------------------------------------------

## PixelLab names each tile wang_N, and N's bits say which corners are
## *background*. The whole importer hangs off this being the right way round --
## invert it and every tile gets collision exactly where its art is not.
func test_wang_number_decodes_to_the_background_corners() -> void:
	assert_eq(importer._background_mask(_tile("upper", "upper", "upper", "upper")), 15)
	assert_eq(importer._background_mask(_tile("lower", "lower", "lower", "lower")), 0)
	assert_eq(importer._background_mask(_tile("lower", "lower", "lower", "upper")), 1, "SE")
	assert_eq(importer._background_mask(_tile("lower", "lower", "upper", "lower")), 2, "SW")
	assert_eq(importer._background_mask(_tile("lower", "upper", "lower", "lower")), 4, "NE")
	assert_eq(importer._background_mask(_tile("upper", "lower", "lower", "lower")), 8, "NW")


## Every tile in the shipped export must agree with its own name, which is the
## cheapest possible check that the convention above still holds for a tileset
## generated later.
func test_every_shipped_tile_agrees_with_its_name() -> void:
	for stage in importer._stage_dirs():
		var meta := _metadata(stage)
		assert_false(meta.is_empty(), "%s has metadata" % stage)
		for entry in meta["tiles"]:
			var tile: Dictionary = entry
			var name := String(tile["name"])
			var expected := int(name.split("_")[1])
			assert_eq(importer._background_mask(tile), expected, "%s/%s" % [stage, name])


# --- Collision geometry -------------------------------------------------------

## Corner terrain offsets the terrain grid half a tile from the visual grid, so
## a top-surface tile is solid across its *bottom* half. Collision has to follow
## the art rather than the tile bounds or the player walks a half-tile too high.
func test_a_surface_tile_is_solid_across_its_bottom_half() -> void:
	# wang_12: both north corners background.
	var polygons := importer._quadrants(12, Vector2i(16, 16))
	assert_eq(polygons.size(), 1, "one merged box, not two quadrants")
	assert_eq(polygons[0], PackedVector2Array([
		Vector2(-8, 0), Vector2(8, 0), Vector2(8, 8), Vector2(-8, 8),
	]))


func test_a_full_tile_is_one_box() -> void:
	var polygons := importer._quadrants(0, Vector2i(16, 16))
	assert_eq(polygons.size(), 1)
	assert_eq(polygons[0], PackedVector2Array([
		Vector2(-8, -8), Vector2(8, -8), Vector2(8, 8), Vector2(-8, 8),
	]))


## The all-background tile is the "no tile" case -- it is why the layout is
## called tileset15 and not tileset16 -- and must contribute no collision.
func test_the_empty_tile_has_no_collision() -> void:
	assert_eq(importer._quadrants(15, Vector2i(16, 16)).size(), 0)


## A single solid corner is a half-width box on the correct side. Getting the
## side wrong is invisible in a screenshot and very visible under the player.
func test_a_single_corner_is_a_half_box_on_that_side() -> void:
	# wang_7: only NW is solid.
	var north_west := importer._quadrants(7, Vector2i(16, 16))
	assert_eq(north_west.size(), 1)
	assert_eq(north_west[0], PackedVector2Array([
		Vector2(-8, -8), Vector2(0, -8), Vector2(0, 0), Vector2(-8, 0),
	]))
	# wang_11: only NE is solid.
	var north_east := importer._quadrants(11, Vector2i(16, 16))
	assert_eq(north_east.size(), 1)
	assert_eq(north_east[0], PackedVector2Array([
		Vector2(0, -8), Vector2(8, -8), Vector2(8, 0), Vector2(0, 0),
	]))


## Diagonals cannot merge, so they cost two boxes.
func test_a_diagonal_pair_stays_two_boxes() -> void:
	# wang_9: NW and SE background, so NE and SW are solid.
	assert_eq(importer._quadrants(9, Vector2i(16, 16)).size(), 2)


# --- The generated resources --------------------------------------------------

func test_tilesets_were_generated() -> void:
	var stages := importer._stage_dirs()
	assert_true(stages.size() > 0, "at least one tileset export under %s" % SOURCE_DIR)
	for stage in stages:
		var path := "%s/%s.tres" % [TILESET_DIR, stage]
		assert_true(ResourceLoader.exists(path), "%s was imported" % path)


## Fifteen, not sixteen: the all-background tile is deliberately not created.
func test_every_tileset_carries_fifteen_tiles_on_the_world_layer() -> void:
	for stage in importer._stage_dirs():
		var tileset := load("%s/%s.tres" % [TILESET_DIR, stage]) as TileSet
		assert_not_null(tileset, stage)
		assert_eq(tileset.get_physics_layers_count(), 1, "%s physics layers" % stage)
		assert_eq(tileset.get_physics_layer_collision_layer(0), 1 << 0,
			"%s sits on the world layer, the one the player's mask looks for" % stage)
		assert_eq(tileset.get_physics_layer_collision_mask(0), 0,
			"%s is static terrain and detects nothing itself" % stage)

		var source := tileset.get_source(0) as TileSetAtlasSource
		assert_not_null(source, "%s atlas source" % stage)
		assert_eq(source.get_tiles_count(), 15, "%s tile count" % stage)


## Without a corner-match terrain set the autotiler cannot place these at all,
## and a stage would have to name all fifteen tiles by hand.
func test_every_tileset_has_a_corner_match_terrain() -> void:
	for stage in importer._stage_dirs():
		var tileset := load("%s/%s.tres" % [TILESET_DIR, stage]) as TileSet
		assert_eq(tileset.get_terrain_sets_count(), 1, "%s terrain sets" % stage)
		assert_eq(tileset.get_terrain_set_mode(0), TileSet.TERRAIN_MODE_MATCH_CORNERS,
			"%s matches corners, not sides" % stage)
		assert_eq(tileset.get_terrains_count(0), 1, "%s terrains" % stage)


## The check that ties the two halves together: for every generated tile, the
## collision boxes must cover exactly the quadrants its own metadata calls
## solid. This is what would catch an atlas coordinate slipping by a tile.
func test_generated_collision_matches_the_metadata_corners() -> void:
	for stage in importer._stage_dirs():
		var tileset := load("%s/%s.tres" % [TILESET_DIR, stage]) as TileSet
		var source := tileset.get_source(0) as TileSetAtlasSource
		var size := tileset.tile_size

		for entry in _metadata(stage)["tiles"]:
			var tile: Dictionary = entry
			var background := importer._background_mask(tile)
			if background == 15:
				continue
			var box: Dictionary = tile["bounding_box"]
			var coords := Vector2i(int(box["x"]) / size.x, int(box["y"]) / size.y)

			var data := source.get_tile_data(coords, 0)
			assert_not_null(data, "%s/%s at %v" % [stage, tile["name"], coords])
			var expected: Array = importer._quadrants(background, size)
			assert_eq(data.get_collision_polygons_count(0), expected.size(),
				"%s/%s polygon count" % [stage, tile["name"]])
			for i in expected.size():
				assert_eq(data.get_collision_polygon_points(0, i), expected[i],
					"%s/%s polygon %d" % [stage, tile["name"], i])


# --- Helpers ------------------------------------------------------------------

func _tile(nw: String, ne: String, sw: String, se: String) -> Dictionary:
	return {"corners": {"NW": nw, "NE": ne, "SW": sw, "SE": se}}


func _metadata(stage: String) -> Dictionary:
	var path := "%s/%s/tileset.json" % [SOURCE_DIR, stage]
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed["tileset_data"] if parsed is Dictionary else {}
