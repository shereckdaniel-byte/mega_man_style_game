## Project settings are easy to clobber by accident in the editor and the damage
## is subtle -- blurry sprites, a jittery camera, physics running at the display
## refresh rate. Assert the ones that matter.
extends TestCase

const EXPECTED_LAYERS := [
	"world", "one_way", "ladder", "player_body", "player_hurtbox", "player_attack",
	"enemy_body", "enemy_hurtbox", "enemy_attack", "pickup", "hazard", "trigger",
	"platform",
]


func test_viewport_is_nes_sized() -> void:
	assert_eq(int(ProjectSettings.get_setting("display/window/size/viewport_width")), 256)
	assert_eq(int(ProjectSettings.get_setting("display/window/size/viewport_height")), 224)


func test_stretch_is_integer_scaled() -> void:
	assert_eq(ProjectSettings.get_setting("display/window/stretch/mode"), "canvas_items")
	assert_eq(ProjectSettings.get_setting("display/window/stretch/aspect"), "keep")
	assert_eq(ProjectSettings.get_setting("display/window/stretch/scale_mode"), "integer",
		"non-integer scaling shimmers on horizontal scroll")


func test_texture_filtering_is_nearest() -> void:
	assert_eq(int(ProjectSettings.get_setting(
		"rendering/textures/canvas_textures/default_texture_filter")), 0,
		"0 == Nearest; anything else blurs every sprite in the game")


func test_pixel_snapping_is_on() -> void:
	assert_true(bool(ProjectSettings.get_setting("rendering/2d/snap/snap_2d_transforms_to_pixel")))
	assert_true(bool(ProjectSettings.get_setting("rendering/2d/snap/snap_2d_vertices_to_pixel")))


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
