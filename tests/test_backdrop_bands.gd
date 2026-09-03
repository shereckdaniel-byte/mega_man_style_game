## The backdrop follows the player under the deck.
##
## Plates are hung against the viewport with no vertical scroll -- they have to
## be, or the horizon walks off the top of the screen when the camera rises --
## so a camera dropping into a room below the boardwalk changes nothing about
## what is drawn behind it. Without a second set of plates and something to swap
## them, the rooms under the deck show the same sunrise as the deck itself, and
## the stage reads as one long boardwalk at two heights.
##
## What is checked here is the join between the stage's bands and the
## backdrop's. Both failure modes are silent: a band the stage uses and the
## backdrop has no plates for leaves whatever the last room put up, and a
## backdrop that stopped answering `show_band` does the same. Neither logs
## anything, and both look like art that was never made.
extends TestCase

const STAGE := preload("res://scenes/stages/dawn_boardwalk/dawn_boardwalk.gd")
const BACKGROUND := preload("res://scenes/stages/dawn_boardwalk/parallax_background.gd")

var backdrop: Node2D


func is_async() -> bool:
	return true


func before_each_async() -> void:
	backdrop = Node2D.new()
	backdrop.set_script(BACKGROUND)
	tree.root.add_child(backdrop)
	await tree.physics_frame


func after_each_async() -> void:
	if is_instance_valid(backdrop):
		backdrop.queue_free()
	await tree.physics_frame


func test_the_backdrop_has_plates_for_every_band_the_stage_uses() -> void:
	for index in STAGE.ROOMS.size():
		var band: int = int(STAGE.ROOMS[index]["band"])
		var node: Node2D = backdrop.band_node(band)
		assert_not_null(node, "%s sits in band %d, and the backdrop has plates for it"
			% [STAGE.ROOMS[index]["name"], band])
		assert_true(node.get_child_count() > 0,
			"band %d has plates, not just an empty node" % band)


## Both bands are used: a stage that never left the deck would pass every other
## assertion here while the under-deck art sat unreachable.
func test_the_stage_uses_both_bands() -> void:
	var bands: Array[int] = []
	for index in STAGE.ROOMS.size():
		var band: int = int(STAGE.ROOMS[index]["band"])
		if not bands.has(band):
			bands.append(band)
	assert_true(bands.has(STAGE.BAND_DECK), "some rooms are on the deck")
	assert_true(bands.has(STAGE.BAND_UNDER), "and some are under it")


func test_showing_a_band_hides_the_others() -> void:
	backdrop.show_band(STAGE.BAND_UNDER)
	assert_false(backdrop.band_node(STAGE.BAND_DECK).visible, "the sunrise is gone")
	assert_true(backdrop.band_node(STAGE.BAND_UNDER).visible, "the underside is showing")


## And back again -- a one-way swap leaves the player climbing out of the dark
## into more dark.
func test_climbing_back_up_restores_the_sky() -> void:
	backdrop.show_band(STAGE.BAND_UNDER)
	backdrop.show_band(STAGE.BAND_DECK)
	assert_true(backdrop.band_node(STAGE.BAND_DECK).visible, "the sky is back")
	assert_false(backdrop.band_node(STAGE.BAND_UNDER).visible, "and the underside is put away")


## The under-deck plates are drawn, not loaded, so "the art is missing" cannot
## be the failure -- but "the art is 400x240 of one flat colour" can, and looks
## the same from the stage. Every plate has to carry some range.
func test_the_drawn_plates_are_not_blank() -> void:
	var under: Node2D = backdrop.band_node(STAGE.BAND_UNDER)
	for layer in under.get_children():
		var sprite := layer.get_child(0) as Sprite2D
		assert_not_null(sprite, "%s draws something" % layer.name)
		var image := sprite.texture.get_image()
		var first := image.get_pixel(0, 0)
		var varied := false
		for y in range(0, image.get_height(), 7):
			for x in range(0, image.get_width(), 7):
				if not image.get_pixel(x, y).is_equal_approx(first):
					varied = true
					break
			if varied:
				break
		assert_true(varied, "%s has more than one colour in it" % layer.name)


## The two bands are meant to read as one world at two depths. They are sampled
## from the same plates to make that true, so the under-deck gloom must stay in
## the sky's family of hues rather than drifting into its own palette -- the
## first pass sampled the sunset's reflection and came out mauve.
func test_the_underside_is_lit_by_the_same_water() -> void:
	var gloom: Node2D = backdrop.band_node(STAGE.BAND_UNDER).get_child(0)
	var image := (gloom.get_child(0) as Sprite2D).texture.get_image()
	var deep := image.get_pixel(image.get_width() / 2, image.get_height() - 1)
	assert_true(deep.b > deep.r,
		"the deep water under the deck is blue, not mauve (%s)" % deep)
	assert_true(deep.v < 0.5, "and it is dark down there (v=%.2f)" % deep.v)


# --- The sun and its reflection -----------------------------------------------

## **A reflection has to scroll with the thing it reflects.**
##
## The sun's glint was drawn into `water.png`, which scrolls at 0.4 against the
## sky's 0.05, so it slid out from under the sun as the camera moved -- two
## screens along they were most of a room apart. Lifting it onto its own plate at
## the sky's rate fixes it by construction, and this is what stops a later edit
## to either scroll factor from quietly undoing that.
func test_the_sun_and_its_reflection_scroll_together() -> void:
	var sun := _plate(BACKGROUND.SUN_PLATE)
	var glint := _plate(BACKGROUND.GLINT_PLATE)
	assert_false(sun.is_empty(), "no %s plate" % BACKGROUND.SUN_PLATE)
	assert_false(glint.is_empty(), "no %s plate" % BACKGROUND.GLINT_PLATE)
	assert_almost_eq(float(glint["scroll"]), float(sun["scroll"]), 0.0001,
		"the glint scrolls at %.2f and the sun at %.2f -- they will drift apart"
			% [float(glint["scroll"]), float(sun["scroll"])])


## And they must tile on the same cadence, or they drift a plate-width at a time
## instead of continuously. Same source width is the simplest way to guarantee it.
func test_the_sun_and_its_reflection_tile_together() -> void:
	var sun_texture := _texture(BACKGROUND.SUN_PLATE)
	var glint_texture := _texture(BACKGROUND.GLINT_PLATE)
	assert_not_null(sun_texture)
	assert_not_null(glint_texture)
	assert_eq(glint_texture.get_width(), sun_texture.get_width(),
		"the glint plate is a different width from the sky, so they repeat out of step")


## The disc has to actually be under the sun, not merely locked to it. Measured
## from the art rather than from a constant, so regenerating either plate is
## checked rather than assumed.
func test_the_reflection_sits_under_the_sun() -> void:
	var sun_x := _warm_centre(_texture(BACKGROUND.SUN_PLATE))
	var glint_x := _warm_centre(_texture(BACKGROUND.GLINT_PLATE))
	assert_true(absf(sun_x - glint_x) <= 3.0,
		"the sun is centred at plate x=%.1f and its reflection at x=%.1f"
			% [sun_x, glint_x])


## Nothing sun-shaped is left in the water plate. The disc was drawn into it
## originally, and a copy left behind would show through as a second reflection
## that does not move with the first.
func test_the_water_plate_no_longer_carries_the_reflection() -> void:
	var water := _texture("Water")
	assert_not_null(water)
	var image := water.get_image()
	var bright := 0
	for y in image.get_height():
		for x in image.get_width():
			var c := image.get_pixel(x, y)
			# The disc was a large area of strongly warm pixels; the water's own
			# highlights are pale and neutral, so warmth is what separates them.
			if c.r + c.g - 2.0 * c.b > 0.7:
				bright += 1
	assert_true(bright < 60,
		"%d sun-coloured pixels left in the water plate" % bright)


func _plate(name: String) -> Dictionary:
	for plate in BACKGROUND.PLATES:
		if String(plate["name"]) == name:
			return plate
	return {}


func _texture(name: String) -> Texture2D:
	var plate := _plate(name)
	if plate.is_empty():
		return null
	var path: String = BACKGROUND.PLATE_DIR + String(plate["file"])
	return load(path) as Texture2D if ResourceLoader.exists(path) else null


## Where a plate's warm region is centred: the sun in one, its reflection in the
## other.
##
## The **centre of the warm area**, not the single warmest pixel. The two are 13
## px apart here -- the sun's brightest pixel is off to one side of its own disc
## and the reflection's is off to the other -- which is a fact about dithering
## rather than about where either disc is. Thresholding at half of each plate's
## own peak, because the reflection is dimmer than the sun by design and a shared
## absolute cut-off finds fourteen pixels of it.
func _warm_centre(texture: Texture2D) -> float:
	var image := texture.get_image()
	var peak := 0.0
	for y in image.get_height():
		for x in image.get_width():
			var c := image.get_pixel(x, y)
			if c.a >= 0.5:
				peak = maxf(peak, c.r + c.g - 2.0 * c.b)
	var total := 0
	var sum_x := 0.0
	for y in image.get_height():
		for x in image.get_width():
			var c := image.get_pixel(x, y)
			if c.a >= 0.5 and c.r + c.g - 2.0 * c.b > peak * 0.5:
				total += 1
				sum_x += float(x)
	return sum_x / float(maxi(total, 1))
