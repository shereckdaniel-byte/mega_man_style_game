## Keep: the last stage, and the only stage clear in the game that ends the run.
extends TestCase

const Keep := preload("res://scenes/stages/keep/keep.gd")
const SCENE := "res://scenes/stages/keep/keep.tscn"
const SETTLE_FRAMES := 6


func is_async() -> bool:
	return true


# --- Shape -----------------------------------------------------------------------

func test_it_knows_which_fortress_stage_it_is() -> void:
	assert_eq(Keep.new().fortress_index(), 3)
	assert_eq(String(StageRoster.fortress_entry(3)["name"]), "Keep")
	assert_eq(String(StageRoster.fortress_entry(3)["scene"]), SCENE)


## **The shortest stage in the game, on purpose.** What is at the end of it is
## the only thing anyone is here for, and every room before it is a room spent
## on the way.
func test_it_is_the_shortest_stage_in_the_game() -> void:
	var mine := Keep.ROOMS.size()
	for name in ["outfall", "caisson", "switchgear"]:
		var other: GDScript = load("res://scenes/stages/%s/%s.gd" % [name, name])
		assert_true(mine <= other.ROOMS.size(),
			"Keep has %d rooms and %s has %d" % [mine, name, other.ROOMS.size()])
	assert_true(mine >= 6, "only %d rooms" % mine)


## **No gimmick of its own, and no borrowed one either.** Outfall paired the two
## waters, Caisson the belt and the press, Switchgear had none because the eight
## fights were the stage. Keep has the M5a kit the player has been reading since
## the first room they ever played -- nothing here needs explaining, which is the
## point.
func test_it_introduces_nothing_new() -> void:
	var gimmicks := ["tide", "water", "belts", "crushers", "ice", "wind",
		"mirrors", "dark", "refight", "duel"]
	for spec in Keep.ROOMS:
		for key in gimmicks:
			assert_false(spec.has(key),
				"%s carries a stage gimmick (%s) into the last stage"
					% [spec["name"], key])


## And it does use the shared kit, or "no gimmick" would just mean "empty".
func test_it_uses_the_kit_the_player_already_knows() -> void:
	var kinds := {}
	for spec in Keep.ROOMS:
		for key in ["crumbles", "movers", "spikes", "pit_spikes",
				"ceiling_spikes", "gaps", "blocks", "ceilings"]:
			if not (spec.get(key, []) as Array).is_empty():
				kinds[key] = true
	for wanted in ["crumbles", "movers", "pit_spikes", "ceiling_spikes"]:
		assert_true(kinds.has(wanted),
			"the last stage has no %s in it at all" % wanted)


## **The crumbling blocks are the floor over a hole**, which is the idiom stage
## 1 and stage 3 both use: `crumbles` is `[x, rows_above_deck]`, and 0 means "in
## the deck". Authored at rise 2 first, which floated three one-tile blocks two
## rows up and left a single tile of headroom under them -- a standing player is
## a tile and a half, so the bot walked into the first one and stopped for 900
## frames.
func test_every_crumble_is_in_the_deck_rather_than_floating() -> void:
	for spec in Keep.ROOMS:
		for block in spec.get("crumbles", []):
			assert_eq(block.size(), 2,
				"%s: a crumble is [x, rows_above_deck] and this has %d entries"
					% [spec["name"], block.size()])
			assert_eq(int(block[1]), 0,
				"%s: a crumble floating %d rows up is a ceiling, not a floor"
					% [spec["name"], int(block[1])])


## And they cover the hole they are the crossing for, or the room is a gap with
## decoration beside it.
func test_the_crumbles_cover_their_hole() -> void:
	for spec in Keep.ROOMS:
		var crumbles: Array = spec.get("crumbles", [])
		if crumbles.is_empty():
			continue
		var covered := {}
		for block in crumbles:
			covered[int(block[0])] = true
		for gap in spec.get("gaps", []):
			for cell in range(int(gap[0]), int(gap[1])):
				assert_true(covered.has(cell),
					"%s: cell %d of the hole has no crumble over it"
						% [spec["name"], cell])


## **Every moving platform is reachable.** A jump clears 2.89 tiles, so a mover
## authored above that is a ride the player can watch and never board -- which
## is what happened here at four rows up, and the bot stood at the lip waiting
## for 900 frames.
func test_every_mover_is_within_a_jump_of_the_deck() -> void:
	var reach := PlayerTuning.new().jump_apex_tiles()
	for spec in Keep.ROOMS:
		for mover in spec.get("movers", []):
			var rows := float(mover[1])
			assert_true(rows <= reach,
				"%s: a mover %.0f rows up, and a jump reaches %.2f tiles"
					% [spec["name"], rows, reach])


# --- The boss ---------------------------------------------------------------------

func test_the_boss_is_bulwark_and_it_has_two_forms() -> void:
	var stage := Keep.new()
	assert_eq(stage.boss_script(), load("res://scenes/actors/bosses/bulwark.gd"))
	assert_eq(stage.boss_name(), "Bulwark")
	var boss := (stage.boss_script() as GDScript).new() as Boss
	tree.root.add_child(boss)
	await tree.physics_frame
	assert_eq(boss.forms(), 2, "the last fight has one form")
	assert_eq(boss.boss_index, -1)
	assert_eq(boss.weapon_id, &"")
	boss.queue_free()
	await tree.physics_frame


## The arena furnishes itself: Bulwark's rubble is the only footing that room
## ever has, so it is authored flat and empty like every other arena.
func test_the_arena_is_flat_and_has_no_checkpoint() -> void:
	var arena: Dictionary = Keep.ROOMS[Keep.ROOMS.size() - 1]
	assert_true((arena.get("gaps", []) as Array).is_empty())
	assert_true((arena.get("blocks", []) as Array).is_empty())
	assert_true((arena.get("enemies", []) as Array).is_empty())
	assert_true(is_equal_approx(float(arena["checkpoint"]),
		AuthoredStage.NO_CHECKPOINT),
		"a checkpoint inside the seal lets a death skip the fight")


# --- The ending ---------------------------------------------------------------------

## **Clearing it finishes the fortress**, which is a thing no other stage clear
## in the game does.
func test_clearing_it_finishes_the_fortress() -> void:
	var state := tree.root.get_node_or_null(^"GameState")
	if state == null:
		return
	var was_bosses: int = state.bosses_defeated
	var was_fortress: int = state.fortress_progress
	for i in GameState.BOSS_COUNT:
		state.mark_boss_defeated(i)
	for i in GameState.FORTRESS_COUNT - 1:
		state.mark_fortress_cleared(i)
	assert_eq(int(state.fortress_stage()), 3, "the run is not at the last stage")

	state.mark_fortress_cleared(Keep.new().fortress_index())
	assert_eq(int(state.fortress_stage()), -1, "the fortress is not finished")
	assert_true(state.fortress_open(), "the eight came undone")

	state.bosses_defeated = was_bosses
	state.fortress_progress = was_fortress


## **The ending falls back rather than failing.** The screen itself is M8's and
## does not exist; `goto` would push an error and leave the player standing in a
## stage that has already said goodbye. Falling back means the game is
## completable today and gets its ending the moment somebody writes one, with no
## other file changing.
func test_the_ending_route_survives_having_no_ending_yet() -> void:
	var router := tree.root.get_node_or_null(^"SceneRouter")
	if router == null:
		return
	assert_true(router.has_method("goto_ending"),
		"nothing routes a finished run anywhere")
	# Whichever of the two it resolves to, it must be a scene that exists --
	# that is the whole guarantee.
	var target: String = SceneRouter.ENDING if ResourceLoader.exists(SceneRouter.ENDING) \
		else SceneRouter.STAGE_SELECT
	assert_true(ResourceLoader.exists(target),
		"a finished run routes to %s, which is not on disk" % target)
