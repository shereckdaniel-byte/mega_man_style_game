## The front end as a player meets it: does every screen *build*, and does what
## it builds have any size.
##
## These two questions sound too dull to need a test and are exactly the two
## that were being answered wrong. Everything else about the menus was covered —
## `test_frontend.gd` walks the title's rows and its refusals, `test_stage_select.gd`
## walks the grid — and all of it passed while the ending screen was a blank
## grey rectangle and the password screen was a grid crushed into the top-left
## corner with the title showing through it. Both bugs are invisible to a test
## that only calls methods.
##
## ### Why compiling is asserted rather than assumed
##
## `ending.gd` had a parse error for as long as the file existed. A script that
## fails to parse still `preload`s to a non-null GDScript — it just cannot be
## instantiated — so `test_frontend.gd`, which preloads it, compiled to nothing,
## and the runner's own "could not load" guard never fired because the *test*
## file loaded fine. Its four ending tests then called `new()` on a script that
## could not make an object, got null, asserted things about null, and reported
## ok. Four green tests, one screen that had never once drawn.
##
## So: every script under `scenes/ui/` is loaded and asked whether it can build
## an object. It is the cheapest possible check and it is the one that was
## missing.
##
## ### Why size is asserted
##
## Both layout bugs were one call: `set_anchors_preset` where
## `set_anchors_and_offsets_preset` was meant. The first keeps whatever rect it
## finds, and a bare `Control` has none until something gives it one — so a node
## anchored to the full rect from inside `_ready`, when it is already in the
## tree, gets offsets that pin it at 0x0 permanently. It draws every frame, into
## nothing. Nothing about the node's *behaviour* changes, which is why the
## method-level tests never noticed.
extends TestCase

const UI_DIR := "res://scenes/ui"


func is_async() -> bool:
	return true


func after_each_async() -> void:
	for child in tree.root.get_children():
		if child.scene_file_path.begins_with(UI_DIR) or child is PasswordScreen \
				or child is TitleScreen or child is EndingScreen \
				or child is OptionsScreen:
			child.queue_free()
	await tree.physics_frame


# --- Compiling -------------------------------------------------------------------------

## **Every front-end script parses and can build an object.** See the class
## docstring: a parse error here is a blank screen that the rest of the suite
## reports as working.
func test_every_ui_script_compiles() -> void:
	var scripts := _ui_scripts()
	assert_true(scripts.size() >= 10,
		"only found %d scripts under %s" % [scripts.size(), UI_DIR])
	for path in scripts:
		var script: GDScript = load(path)
		assert_not_null(script, "%s did not load" % path)
		if script == null:
			continue
		assert_true(script.can_instantiate(),
			"%s loaded but cannot be instantiated -- parse error?" % path)


## And every scene that wraps one opens. A scene whose script will not compile
## instantiates to a node with no behaviour rather than to an error, which is
## the ending screen's failure exactly.
func test_every_ui_scene_instantiates() -> void:
	for path in _ui_scenes():
		var packed: PackedScene = load(path)
		assert_not_null(packed, "%s did not load" % path)
		if packed == null:
			continue
		assert_true(packed.can_instantiate(), "%s cannot be instantiated" % path)


# --- Size ------------------------------------------------------------------------------

## **The password screen covers the screen it opens over.** It is a `Control`
## added to somebody else's `CanvasLayer`, so it starts at 0x0 and has to ask
## for the viewport's rect from inside `_ready` -- the one place where
## `set_anchors_preset` silently does the opposite of what it reads like.
##
## When this was wrong the grid sat in the top-left corner at its natural size
## and the backdrop covered nothing at all, so the title screen's menu showed
## straight through the password grid.
func test_the_password_screen_fills_the_viewport() -> void:
	var host := CanvasLayer.new()
	tree.root.add_child(host)
	var screen := PasswordScreen.open(host)
	await tree.physics_frame
	await tree.physics_frame

	var viewport := tree.root.get_visible_rect().size
	assert_eq(screen.size, viewport,
		"the password screen is %s in a %s viewport" % [screen.size, viewport])

	# The backdrop is what actually hides the screen underneath, and it is a
	# separate node with its own anchors -- a full-size parent with a 0x0
	# backdrop still shows everything behind it.
	var backdrop := _first_of_type(screen, "ColorRect") as ColorRect
	assert_not_null(backdrop, "the password screen has no backdrop")
	if backdrop != null:
		assert_eq(backdrop.size, viewport,
			"the password backdrop is %s in a %s viewport" % [backdrop.size, viewport])
	host.queue_free()


## **The title's horizon has a width.** `Sea` anchors itself to the full rect
## from inside its own `_ready`, which is the same trap, and it drew every frame
## into a box with no size -- so the title screen shipped as a flat colour with
## text on it and the art nobody could see was still being redrawn.
func test_the_titles_sea_has_a_size() -> void:
	var title: TitleScreen = load("res://scenes/ui/title.gd").new()
	tree.root.add_child(title)
	await tree.physics_frame
	await tree.physics_frame

	var sea := title.get_node_or_null(^"Backdrop/Sea") as Control
	assert_not_null(sea, "the title has no Sea node")
	if sea != null:
		var viewport := tree.root.get_visible_rect().size
		assert_eq(sea.size, viewport,
			"the sea is %s in a %s viewport" % [sea.size, viewport])
	title.queue_free()


## The ending builds its credits. This is the assertion the four ending tests
## in `test_frontend.gd` believed they were making: with the parse error in
## place the screen was null and they all passed anyway.
func test_the_ending_builds_its_credits() -> void:
	# `can_instantiate` before `new`, not as well as it: a script that will not
	# compile still answers `new()` with an error and a null, and a test that
	# walks on into `add_child(null)` reports whatever the engine does with that
	# rather than the thing it meant to check.
	var script: GDScript = load("res://scenes/ui/ending.gd")
	assert_true(script != null and script.can_instantiate(),
		"the ending screen would not compile")
	if script == null or not script.can_instantiate():
		return
	var ending: EndingScreen = script.new()
	tree.root.add_child(ending)
	await tree.physics_frame

	var credits := ending.get_node_or_null(^"Backdrop/Credits") as Control
	assert_not_null(credits, "the ending has no Credits node")
	if credits != null:
		assert_eq(credits.get_child_count(), EndingScreen.CREDITS.size(),
			"%d credit lines built from %d"
				% [credits.get_child_count(), EndingScreen.CREDITS.size()])
	ending.queue_free()


# --- Helpers ---------------------------------------------------------------------------

func _ui_scripts() -> PackedStringArray:
	return _files_under(UI_DIR, ".gd")


func _ui_scenes() -> PackedStringArray:
	return _files_under(UI_DIR, ".tscn")


func _files_under(dir_path: String, suffix: String) -> PackedStringArray:
	var out: PackedStringArray = []
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return out
	for name in dir.get_files():
		# Exported builds hand back the .remap name; the resource behind it is
		# the one without it.
		var file := name.trim_suffix(".remap")
		if file.ends_with(suffix):
			out.append("%s/%s" % [dir_path, file])
	out.sort()
	return out


func _first_of_type(node: Node, type_name: String) -> Node:
	for child in node.get_children():
		if child.is_class(type_name):
			return child
		var hit := _first_of_type(child, type_name)
		if hit != null:
			return hit
	return null
