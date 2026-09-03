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
