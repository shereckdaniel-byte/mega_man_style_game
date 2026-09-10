## The screens at either end of a run: title, intro, ending, options.
##
## These are the only screens in the game a player can reach without playing it,
## which makes them the ones where a mistake is seen first and by everybody. The
## rules worth pinning are all about *refusals* and *routes*: a title that offers
## a continue with no save, an ending that can be dismissed by a button somebody
## was already holding, an options screen that binds pause to something and
## traps the player inside itself.
extends TestCase

const TitleScript := preload("res://scenes/ui/title.gd")
const IntroScript := preload("res://scenes/ui/intro.gd")
const EndingScript := preload("res://scenes/ui/ending.gd")
const OptionsScript := preload("res://scenes/ui/options.gd")


func is_async() -> bool:
	return true


func after_each_async() -> void:
	for child in tree.root.get_children():
		if child is TitleScreen or child is IntroScreen or child is EndingScreen \
				or child is OptionsScreen:
			child.queue_free()
	await tree.physics_frame


# --- The route -----------------------------------------------------------------------

## **Every screen the router names exists.** A route to a missing scene is a
## `push_error` and a player left standing in whatever they were in.
func test_every_routed_scene_is_on_disk() -> void:
	for path in [SceneRouter.TITLE, SceneRouter.INTRO, SceneRouter.STAGE_SELECT,
			SceneRouter.ENDING]:
		assert_true(ResourceLoader.exists(path), "%s is not on disk" % path)


## Boot opens the intro rather than dropping straight into the stage select.
## That route is the whole reason the title exists: boot has read slot 0 since
## M6, and until M8 there was nowhere to decide *not* to use it.
func test_boot_opens_the_front_of_the_game() -> void:
	var boot: GDScript = load("res://scenes/ui/boot.gd")
	assert_eq(String(boot.FIRST_SCENE), SceneRouter.INTRO,
		"boot goes to %s" % boot.FIRST_SCENE)


# --- The title -------------------------------------------------------------------------

## **CONTINUE is dimmed and refuses when there is no save, rather than being
## hidden.** A row that appears and disappears makes the menu change shape
## between visits, which is the same argument the stage select makes about its
## unbuilt cells.
func test_continue_refuses_without_a_save() -> void:
	SaveGame.erase(0)
	var title: TitleScreen = TitleScript.new()
	tree.root.add_child(title)
	await tree.physics_frame
	assert_false(title.has_save())
	# The cursor opens on something that works rather than on a "no".
	assert_eq(title.cursor, TitleScreen.ROW_NEW,
		"the cursor opens on row %d with no save" % title.cursor)
	title.cursor = TitleScreen.ROW_CONTINUE
	assert_false(title.confirm(), "continue worked with no save")


## And it is there when there is one.
func test_continue_is_offered_when_a_save_exists() -> void:
	SaveGame.write(0, {"bosses_defeated": 3, "items_unlocked": 0, "etanks": 1,
		"lives": 2, "fortress_progress": 0})
	var title: TitleScreen = TitleScript.new()
	tree.root.add_child(title)
	await tree.physics_frame
	assert_true(title.has_save())
	assert_eq(title.cursor, TitleScreen.ROW_CONTINUE)
	SaveGame.erase(0)


## **NEW GAME clears the run before it starts one.** Boot has already read the
## save by the time anybody reaches this screen, so starting fresh without a
## reset would leave a half-loaded state -- the boss bits gone and the E-tanks
## still there.
func test_new_game_clears_what_boot_loaded() -> void:
	var state := tree.root.get_node_or_null(^"GameState")
	if state == null:
		return
	state.bosses_defeated = 0xFF
	state.etanks = 4
	state.fortress_progress = 0b11
	var title: TitleScreen = TitleScript.new()
	tree.root.add_child(title)
	await tree.physics_frame
	title.cursor = TitleScreen.ROW_NEW
	title.confirm()
	assert_eq(state.bosses_defeated, 0, "the eight survived a new game")
	assert_eq(state.etanks, 0, "the E-tanks survived a new game")
	assert_eq(state.fortress_progress, 0, "the fortress survived a new game")


func test_the_title_cursor_wraps() -> void:
	var title: TitleScreen = TitleScript.new()
	tree.root.add_child(title)
	await tree.physics_frame
	title.cursor = 0
	title.move_cursor(-1)
	assert_eq(title.cursor, TitleScreen.ROWS - 1)
	title.move_cursor(1)
	assert_eq(title.cursor, 0)


# --- The intro ---------------------------------------------------------------------------

## **Skippable from the first frame.** An intro that has to be sat through is an
## intro that is resented on the second run, and this one is seen by the same
## person many times.
func test_the_intro_can_be_skipped_immediately() -> void:
	var intro: IntroScreen = IntroScript.new()
	tree.root.add_child(intro)
	await tree.physics_frame
	assert_eq(intro.card(), 0)
	assert_false(intro.is_finished())
	intro.skip()
	assert_true(intro.is_finished())


## And it ends on its own, so a player who puts the controller down still
## arrives at the title.
func test_the_intro_ends_by_itself() -> void:
	var total: int = IntroScreen.CARDS.size() * IntroScreen.CARD_FRAMES
	assert_true(total <= 60 * 60,
		"the intro runs for %d frames, which is over a minute" % total)
	assert_true(IntroScreen.CARDS.size() >= 3,
		"only %d cards" % IntroScreen.CARDS.size())


# --- The ending ---------------------------------------------------------------------------

## **The first press skips to the end of the scroll; the second leaves.** One
## press doing both would end the game on a button somebody was still holding
## from the last shot of the last fight.
func test_the_ending_takes_two_presses_to_leave() -> void:
	var ending: EndingScreen = EndingScript.new()
	tree.root.add_child(ending)
	await tree.physics_frame
	assert_false(ending.is_finished())
	var press := InputEventAction.new()
	press.action = &"jump"
	press.pressed = true
	ending._unhandled_input(press)
	assert_false(ending.is_finished(), "one press ended the game")
	await tree.physics_frame
	ending._unhandled_input(press)
	assert_true(ending.is_finished(), "the second press did nothing")


## The credits hold before they move, and they name the people and the parts.
func test_the_credits_hold_and_then_scroll() -> void:
	var ending: EndingScreen = EndingScript.new()
	tree.root.add_child(ending)
	await tree.physics_frame
	assert_eq(ending.scrolled(), 0.0, "the credits moved before the hold")
	assert_true(EndingScreen.HOLD_FRAMES >= 120,
		"the epilogue holds for %d frames, which is under two seconds"
			% EndingScreen.HOLD_FRAMES)
	assert_true(EndingScreen.CREDITS.size() >= 20,
		"only %d lines of credits" % EndingScreen.CREDITS.size())
	assert_true(EndingScreen.EPILOGUE.size() >= 5)


# --- Options -------------------------------------------------------------------------------

## Every row says something, or it is a row nobody can read.
func test_every_options_row_has_text() -> void:
	var options: OptionsScreen = OptionsScript.new()
	tree.root.add_child(options)
	await tree.physics_frame
	for row in OptionsScreen.Row.size():
		assert_false(options.row_text(row as OptionsScreen.Row).strip_edges().is_empty(),
			"row %d is blank" % row)


## **A volume change applies immediately.** No OK button: a settings screen with
## an apply step is a screen where somebody turns the volume down, hears nothing
## change, and turns it down again.
func test_moving_a_volume_changes_the_bus_now() -> void:
	var audio := tree.root.get_node_or_null(^"AudioManager")
	if audio == null:
		return
	var was := Settings.sfx
	var options: OptionsScreen = OptionsScript.new()
	tree.root.add_child(options)
	await tree.physics_frame
	Settings.sfx = 1.0
	Settings.apply()
	options.cursor = OptionsScreen.Row.SFX
	options.adjust(-1)
	assert_true(Settings.sfx < 1.0, "the setting did not move")
	assert_almost_eq(float(audio.get_volume(&"Sfx")), Settings.sfx, 0.03,
		"the bus is at %.2f and the setting says %.2f"
			% [audio.get_volume(&"Sfx"), Settings.sfx])
	Settings.sfx = was
	Settings.apply()


## The window scale steps through the offered sizes and stops at the ends rather
## than wrapping -- a player pressing left repeatedly should arrive at "smallest"
## and stay there, not jump to "largest".
func test_the_window_scale_clamps_rather_than_wrapping() -> void:
	var was := Settings.scale
	Settings.scale = float(Settings.SCALES[0])
	Settings.step_scale(-1)
	assert_eq(Settings.scale, float(Settings.SCALES[0]), "it wrapped at the bottom")
	Settings.scale = float(Settings.SCALES[Settings.SCALES.size() - 1])
	Settings.step_scale(1)
	assert_eq(Settings.scale, float(Settings.SCALES[Settings.SCALES.size() - 1]),
		"it wrapped at the top")
	Settings.scale = was


## **Escape cancels a rebind rather than binding escape.** Otherwise the first
## thing a curious player does on this row traps them in it.
func test_escape_cancels_a_rebind() -> void:
	var options: OptionsScreen = OptionsScript.new()
	tree.root.add_child(options)
	await tree.physics_frame
	options.cursor = OptionsScreen.Row.REBIND
	options.confirm()
	assert_true(options.listening != &"", "the row did not start listening")
	var escape := InputEventKey.new()
	escape.physical_keycode = KEY_ESCAPE
	escape.pressed = true
	assert_false(options.take_key(escape), "escape was bound")
	assert_eq(options.listening, &"", "it is still listening")


## A rebind replaces the keyboard binding and leaves the pad alone: a player at
## a keyboard has not asked to lose their controller.
func test_a_rebind_keeps_the_pad_binding() -> void:
	var action := &"jump"
	var pads_before := _pad_events(action)
	var key := InputEventKey.new()
	key.physical_keycode = KEY_K
	key.pressed = true
	assert_true(Settings.rebind(action, key))
	assert_true(Settings.binding_text(action).contains("K"),
		"jump reads as %s" % Settings.binding_text(action))
	assert_eq(_pad_events(action), pads_before, "the pad binding was lost")
	Settings.reset_bindings()


## And a reset puts everything back, which is the only undo this screen has.
func test_reset_restores_the_shipped_bindings() -> void:
	var before := Settings.binding_text(&"shoot")
	var key := InputEventKey.new()
	key.physical_keycode = KEY_P
	key.pressed = true
	Settings.rebind(&"shoot", key)
	assert_true(Settings.binding_text(&"shoot") != before)
	Settings.reset_bindings()
	assert_eq(Settings.binding_text(&"shoot"), before,
		"shoot came back as %s" % Settings.binding_text(&"shoot"))


## **A rebound key has to be pressable, which is not the same as being bound.**
##
## `Settings.rebind` used to store the live event the options screen captured,
## and that event carries the device id of the keyboard that pressed it.
## `InputMap` then matched the action only for that device. The row read back
## correctly, `binding_text` showed the new key, and the key did nothing --
## a player who rebound one control lost it, and a settings file with an `input`
## section rebuilt *every* binding that way on the next launch, which is how the
## title screen stopped answering at all.
func test_a_rebound_key_can_actually_be_pressed() -> void:
	var action := &"jump"
	var key := InputEventKey.new()
	key.physical_keycode = KEY_K
	key.pressed = true
	key.device = 3                     # as a real press from some keyboard arrives
	assert_true(Settings.rebind(action, key))
	for device in [0, -1, 7]:
		var press := InputEventKey.new()
		press.physical_keycode = KEY_K
		press.pressed = true
		press.device = device
		assert_true(press.is_action_pressed(action),
			"K from device %d does not press jump" % device)
	Settings.reset_bindings()


## The same fact for the path that runs on every launch: bindings read back out
## of a settings file answer any device, not the one that happened to be first.
func test_bindings_loaded_from_a_file_can_be_pressed() -> void:
	var was := Settings.binding_text(&"shoot")
	Settings._load_bindings({"shoot": [KEY_P]})
	for device in [0, -1, 7]:
		var press := InputEventKey.new()
		press.physical_keycode = KEY_P
		press.pressed = true
		press.device = device
		assert_true(press.is_action_pressed(&"shoot"),
			"a stored binding for P does not answer device %d" % device)
	Settings.reset_bindings()
	assert_eq(Settings.binding_text(&"shoot"), was)


## A reset has to hand back bindings that are pressable too -- it is the undo
## for a rebind that went wrong, and an undo that leaves the game unplayable is
## worse than the mistake.
func test_reset_hands_back_pressable_bindings() -> void:
	var key := InputEventKey.new()
	key.physical_keycode = KEY_P
	key.pressed = true
	key.device = 3
	Settings.rebind(&"shoot", key)
	Settings.reset_bindings()
	var press := InputEventKey.new()
	press.physical_keycode = KEY_X
	press.pressed = true
	press.device = 0
	assert_true(press.is_action_pressed(&"shoot"),
		"after a reset, X does not shoot")


## Every rebindable action is a real action, or the screen offers a row that
## cannot do anything.
func test_every_rebindable_action_exists() -> void:
	for action in Settings.REBINDABLE:
		assert_true(InputMap.has_action(action),
			"%s is offered for rebinding and is not an action" % action)


## **The colourblind option changes the panel, not just a preference.** A
## setting that is stored and never read is a setting that does nothing, which
## is the failure this one is most exposed to.
func test_the_colourblind_option_reaches_the_panels() -> void:
	var was := Settings.colourblind
	Settings.colourblind = false
	var normal := Settings.panel_colour(Color(0.63, 0.80, 0.90))
	assert_false(Settings.panel_hatched())
	Settings.colourblind = true
	assert_true(Settings.panel_hatched(),
		"the high-contrast cue adds no shape, only a colour")
	assert_true(Settings.panel_colour(Color(0.63, 0.80, 0.90)) != normal,
		"the high-contrast panel is the same colour as the normal one")
	Settings.colourblind = was


## Settings round-trip through their file, so a preference survives a restart.
func test_settings_round_trip() -> void:
	var was := [Settings.master, Settings.music, Settings.sfx, Settings.colourblind]
	Settings.master = 0.4
	Settings.music = 0.2
	Settings.sfx = 0.9
	Settings.colourblind = true
	assert_true(Settings.save_settings())
	Settings.master = 1.0
	Settings.music = 1.0
	Settings.sfx = 1.0
	Settings.colourblind = false
	Settings.load_settings()
	assert_almost_eq(Settings.master, 0.4, 0.001)
	assert_almost_eq(Settings.music, 0.2, 0.001)
	assert_almost_eq(Settings.sfx, 0.9, 0.001)
	assert_true(Settings.colourblind)
	Settings.master = was[0]
	Settings.music = was[1]
	Settings.sfx = was[2]
	Settings.colourblind = was[3]
	Settings.save_settings()


func _pad_events(action: StringName) -> int:
	var count := 0
	for event in InputMap.action_get_events(action):
		if event is InputEventJoypadButton or event is InputEventJoypadMotion:
			count += 1
	return count
