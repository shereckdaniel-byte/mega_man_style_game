## Project settings are easy to clobber by accident in the editor and the damage
## is subtle -- blurry sprites, a jittery camera, physics running at the display
## refresh rate. Assert the ones that matter.
extends TestCase

const EXPECTED_LAYERS := [
	"world", "one_way", "ladder", "player_body", "player_hurtbox", "player_attack",
	"enemy_body", "enemy_hurtbox", "enemy_attack", "pickup", "hazard", "trigger",
	"platform",
]


## 1920x1080 at 72 px tiles is 26.7 x 15 tiles. The original was 16 x 14, so the
## vertical view matches closely and the horizontal view is wider -- the cost of
## 16:9, and something level design has to account for.
##
## The tile count is what matters, not the pixel count: viewport and world_scale
## cancel, so this assertion is what stops someone changing one without the other
## and silently altering how much level the player can see.
func test_viewport_frames_the_intended_number_of_tiles() -> void:
	var w := int(ProjectSettings.get_setting("display/window/size/viewport_width"))
	var h := int(ProjectSettings.get_setting("display/window/size/viewport_height"))
	assert_eq(w, 1920)
	assert_eq(h, 1080)
	var tile := PlayerTuning.new().tile_size()
	assert_almost_eq(float(h) / tile, 15.0, 0.001, "viewport is exactly 15 tiles tall")
	assert_between(float(w) / tile, 26.0, 27.0, "and about 27 tiles wide")


func test_stretch_scales_the_canvas() -> void:
	assert_eq(ProjectSettings.get_setting("display/window/stretch/mode"), "canvas_items")


## The art is smooth HD, not pixel art: there is no pixel grid to preserve, so
## integer scaling would only add black borders, and nearest filtering would
## alias the minified sprites. Both were correct before the art arrived and are
## wrong now -- see SPRITES.md section 1.
func test_texture_filtering_is_linear() -> void:
	assert_eq(int(ProjectSettings.get_setting(
		"rendering/textures/canvas_textures/default_texture_filter")), 1,
		"1 == Linear; nearest aliases art that is minified to 0.41x")


func test_pixel_snapping_is_off() -> void:
	assert_false(bool(ProjectSettings.get_setting(
		"rendering/2d/snap/snap_2d_transforms_to_pixel")),
		"snapping is a pixel-art tool; on smooth art it only adds stutter")
	assert_false(bool(ProjectSettings.get_setting(
		"rendering/2d/snap/snap_2d_vertices_to_pixel")))


func test_physics_runs_at_60hz() -> void:
	assert_eq(int(ProjectSettings.get_setting("physics/common/physics_ticks_per_second")), 60,
		"every movement constant in PlayerTuning assumes 60 Hz")


## Gravity is applied per-actor so that hovering, water, and Jet-mode can each
## override it without fighting a global.
func test_global_gravity_is_disabled() -> void:
	assert_almost_eq(float(ProjectSettings.get_setting("physics/2d/default_gravity")), 0.0)


func test_renderer_is_compatibility() -> void:
	assert_eq(ProjectSettings.get_setting("rendering/renderer/rendering_method"),
		"gl_compatibility", "nothing here needs Forward+, and web export needs this")


func test_all_collision_layers_are_named() -> void:
	for i in EXPECTED_LAYERS.size():
		var key := "layer_names/2d_physics/layer_%d" % (i + 1)
		assert_eq(ProjectSettings.get_setting(key), EXPECTED_LAYERS[i],
			"layer %d" % (i + 1))
