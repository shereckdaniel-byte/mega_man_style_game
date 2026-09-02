## Lints the generated SpriteFrames and the name normalisation that produces
## them. These resources are build output (tools/autosprite_import.gd), so the
## failure mode is a silent one: an animation vanishes or gets misnamed and
## nothing complains until something tries to play it.
extends TestCase

const SPRITE_FRAMES_DIR := "res://resources/sprite_frames"

var importer: AutoSpriteImporter


func before_each() -> void:
	importer = AutoSpriteImporter.new()


# --- Name normalisation -------------------------------------------------------

## AutoSprite directory names are inconsistent: "idle_right" alongside
## "Hit React" and "arm cannon attack". They all have to land on identifiers.
func test_names_normalise_to_identifiers() -> void:
	assert_eq(importer._animation_name("Hit React"), "hurt")
	assert_eq(importer._animation_name("arm cannon attack"), "idle_shoot")
	assert_eq(importer._animation_name("Death"), "death")
	assert_eq(importer._animation_name("Victory"), "victory")


## Sprites are drawn right-facing and mirrored with flip_h, so the suffix is
## noise once imported.
func test_direction_suffix_is_stripped() -> void:
	assert_eq(importer._animation_name("idle_right"), "idle")
	assert_eq(importer._animation_name("walk_right"), "walk")
	assert_eq(importer._animation_name("run_right"), "run")


## An animation AutoSprite invents that is not in NAME_MAP must still import
## under a usable name rather than being dropped.
func test_unmapped_names_survive() -> void:
	assert_eq(importer._snake_case("Charge Beam Windup"), "charge_beam_windup")
	assert_eq(importer._snake_case("  Double  Space "), "double_space")


## Trimming keeps the atlas's own frame order and returns exactly the requested
## inclusive slice. Driven from TRIM itself so retuning a range stays a one-line
## edit rather than a test failure.
func test_trim_keeps_the_requested_slice() -> void:
	var keys: Array = range(25)
	for anim_name: String in AutoSpriteImporter.TRIM:
		var bounds: Array = AutoSpriteImporter.TRIM[anim_name]
		var first: int = int(bounds[0])
		var last: int = int(bounds[1])
		assert_true(first >= 0 and last >= first and last < keys.size(),
			"%s bounds %s fit a 25-frame clip" % [anim_name, bounds])
		var kept: Array = importer._trim(anim_name, keys)
		assert_eq(kept, range(first, last + 1),
			"%s keeps frames %d-%d in order" % [anim_name, first, last])
	assert_eq(importer._trim("idle", keys).size(), 25, "an untrimmed name is untouched")


## A clip shorter than its trim range must clamp rather than crash or come back
## empty, so a regenerated animation with fewer frames still imports.
func test_trim_clamps_to_a_short_clip() -> void:
	assert_eq(importer._trim("slide", [0, 1, 2]).size(), 1, "bounds clamp to a short clip")
	assert_true(importer._trim("slide", []).is_empty(), "an empty clip stays empty")


# --- Generated resources ------------------------------------------------------

func test_sprite_frames_were_generated() -> void:
	assert_false(_generated().is_empty(),
		"no SpriteFrames in %s -- run tools/autosprite_import.gd" % SPRITE_FRAMES_DIR)


func test_every_animation_has_frames_with_real_regions() -> void:
	for path in _generated():
		var frames: SpriteFrames = load(path)
		assert_not_null(frames, path)
		if frames == null:
			continue
		var names := frames.get_animation_names()
		assert_true(names.size() > 0, "%s has no animations" % path)
		for name in names:
			var count := frames.get_frame_count(name)
			assert_true(count > 0, "%s/%s has no frames" % [path.get_file(), name])
			for i in count:
				var tex := frames.get_frame_texture(name, i)
				assert_not_null(tex, "%s/%s frame %d" % [path.get_file(), name, i])
				if tex is AtlasTexture:
					var region: Rect2 = (tex as AtlasTexture).region
					assert_true(region.size.x > 0 and region.size.y > 0,
						"%s/%s frame %d has an empty region" % [path.get_file(), name, i])


## Frame order comes from stringified integer keys in atlas.json. Sorted as
## text, frame 10 lands between 1 and 2 and the animation plays scrambled -- a
## bug that looks like bad art rather than bad code.
func test_frames_are_in_left_to_right_top_to_bottom_order() -> void:
	for path in _generated():
		var frames: SpriteFrames = load(path)
		if frames == null:
			continue
		for name in frames.get_animation_names():
			var count := frames.get_frame_count(name)
			var previous := Vector2(-1, -1)
			for i in count:
				var tex := frames.get_frame_texture(name, i)
				if not (tex is AtlasTexture):
					continue
				var at := (tex as AtlasTexture).region.position
				var advanced := at.y > previous.y or (at.y == previous.y and at.x > previous.x)
				assert_true(advanced,
					"%s/%s frame %d at %s does not advance from %s" % [
						path.get_file(), name, i, at, previous])
				previous = at


## The wind-up frames must be gone from the built resource, not just from the
## helper. A slide only ever shows about five frames, so if frame 0 is still the
## standing pose the character never visibly slides.
func test_trimmed_animations_drop_their_wind_up() -> void:
	var frames: SpriteFrames = load(SPRITE_FRAMES_DIR.path_join("player.tres"))
	assert_not_null(frames, "player.tres")
	if frames == null:
		return
	for anim_name: String in AutoSpriteImporter.TRIM:
		var name := StringName(anim_name)
		if not frames.has_animation(name):
			continue
		var bounds: Array = AutoSpriteImporter.TRIM[anim_name]
		var expected: int = int(bounds[1]) - int(bounds[0]) + 1
		assert_eq(frames.get_frame_count(name), expected,
			"%s keeps frames %d-%d" % [anim_name, bounds[0], bounds[1]])


## Trimming picks which frames play, never how fast. Every animation from one
## AutoSprite batch shares a clip length, so a trimmed one must keep the same
## frame rate as an untrimmed sibling rather than speeding up.
func test_trimming_does_not_change_playback_speed() -> void:
	var frames: SpriteFrames = load(SPRITE_FRAMES_DIR.path_join("player.tres"))
	if frames == null or not frames.has_animation(&"teleport_out"):
		return
	var untrimmed := frames.get_animation_speed(&"teleport_out")
	for anim: StringName in [&"slide", &"walk_shoot", &"teleport_in"]:
		if frames.has_animation(anim):
			assert_almost_eq(frames.get_animation_speed(anim), untrimmed, 0.01,
				"%s plays at the batch's frame rate" % anim)


func test_animation_speeds_are_plausible() -> void:
	for path in _generated():
		var frames: SpriteFrames = load(path)
		if frames == null:
			continue
		for name in frames.get_animation_names():
			var fps := frames.get_animation_speed(name)
			assert_between(fps, 1.0, 60.0, "%s/%s fps" % [path.get_file(), name])


func _generated() -> PackedStringArray:
	var out: PackedStringArray = []
	var dir := DirAccess.open(SPRITE_FRAMES_DIR)
	if dir == null:
		return out
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if not dir.current_is_dir() and entry.ends_with(".tres"):
			out.append(SPRITE_FRAMES_DIR.path_join(entry))
		entry = dir.get_next()
	dir.list_dir_end()
	return out
