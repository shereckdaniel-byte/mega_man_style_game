## Portraits are cropped to the character, not to the cell.
##
## The art is framed inconsistently inside its 256 px cells — Tide was generated
## on its own before the roster and fills 58-70% of its cell, where the seven
## generated together fill 90-97%. Gameplay already compensates
## (`Enemy._build_sprite` scales each actor's art to its own body size), so this
## only ever showed up where the raw frame is drawn: the stage select and the
## weapon-get screen, where Tide stood visibly smaller than everyone next to it.
##
## These assertions are about *consistency between characters*, which is the only
## thing a portrait has to get right, and they are what stops the next
## separately-generated boss from reintroducing it.
extends TestCase

const ROSTER := preload("res://scripts/core/stage_roster.gd")
const StageSelect := preload("res://scenes/ui/stage_select.gd")


func test_every_boss_has_a_portrait() -> void:
	for row in ROSTER.ENTRIES:
		var path: String = row["frames"]
		if not ResourceLoader.exists(path):
			continue
		assert_not_null(BossPortrait.of(load(path) as SpriteFrames),
			"%s produced no portrait" % row["boss"])


## The crop is tight: no transparent margin left on any side.
func test_a_portrait_has_no_empty_border() -> void:
	for row in ROSTER.ENTRIES:
		var path: String = row["frames"]
		if not ResourceLoader.exists(path):
			continue
		var texture := BossPortrait.of(load(path) as SpriteFrames)
		if texture == null:
			continue
		var image := texture.get_image()
		var used := image.get_used_rect()
		assert_eq(used.position, Vector2i.ZERO,
			"%s portrait has %s of empty margin at the top-left"
				% [row["boss"], used.position])
		assert_eq(used.size, image.get_size(),
			"%s portrait is %s of art in a %s texture"
				% [row["boss"], used.size, image.get_size()])


## **The one this file exists for**, and it asks about what the player sees
## rather than about the pixels.
##
## A cropped portrait is drawn with `STRETCH_KEEP_ASPECT_CENTERED` into a fixed
## box, so it renders at the box's full height as long as it is not wider than
## the box is proportionally — and every portrait that fills the height reads as
## the same size character, whatever its source resolution. Tide's cropped art is
## genuinely 69% the pixel height of the tallest, and that is fine; what would
## not be fine is a portrait so wide that the box clamps its width instead and it
## sits short in its cell, which is the shape of the original complaint.
##
## Compared against the select screen's own box so the two cannot drift apart.
func test_every_portrait_fills_the_height_of_its_cell() -> void:
	var box: Vector2 = Vector2(StageSelect.CELL_SIZE.x, StageSelect.CELL_SIZE.y - 74.0)
	var limit := box.x / box.y
	for row in ROSTER.ENTRIES:
		var path: String = row["frames"]
		if not ResourceLoader.exists(path):
			continue
		var texture := BossPortrait.of(load(path) as SpriteFrames)
		if texture == null:
			continue
		var aspect := float(texture.get_width()) / float(texture.get_height())
		assert_true(aspect <= limit,
			"%s is %.2f wide for its height; over %.2f the box clamps the width and it draws short"
				% [row["boss"], aspect, limit])


## And the crop actually did something for the boss it was written for: Tide's
## raw frame carries a large empty margin, and the portrait must not.
func test_tides_portrait_is_tighter_than_its_raw_frame() -> void:
	var path := "res://resources/sprite_frames/wave_man.tres"
	if not ResourceLoader.exists(path):
		return
	var frames := load(path) as SpriteFrames
	var anim := BossPortrait._best_animation(frames)
	var raw := frames.get_frame_texture(anim, 0).get_image()
	var portrait := BossPortrait.of(frames).get_image()
	assert_true(portrait.get_height() < raw.get_height(),
		"the portrait (%d px) is no tighter than the raw cell (%d px)"
			% [portrait.get_height(), raw.get_height()])
