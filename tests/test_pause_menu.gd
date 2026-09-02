## The pause sub-screen: weapon switching, and spending an E-tank.
##
## Driven through the same methods the input handler calls, rather than by
## synthesising key events -- `move_selection`, `confirm`, `use_etank` are the
## menu's actual interface and the input handler is a thin wrapper over them.
##
## `after_each` unpauses unconditionally. The menu pauses the whole SceneTree,
## so a test that failed with the menu open would leave every test after it
## running against a paused tree, and the failures would look like anything but
## this file's fault.
extends TestCase

const PLAYER_SCENE := preload("res://scenes/actors/player/player.tscn")
const PauseMenuScript := preload("res://scenes/ui/pause_menu.gd")

var root: Node2D
var menu: PauseMenu
var player: Player
var weapons: Node
var state: Node


func is_async() -> bool:
	return true


func before_each_async() -> void:
	root = Node2D.new()
	tree.root.add_child(root)

	player = PLAYER_SCENE.instantiate()
	root.add_child(player)

	menu = PauseMenuScript.new() as PauseMenu
	root.add_child(menu)
	menu.bind(player)

	weapons = tree.root.get_node_or_null(^"WeaponManager")
	state = tree.root.get_node_or_null(^"GameState")
	if weapons != null:
		weapons.reset()
	if state != null:
		state.etanks = 0
	await tree.physics_frame


func after_each_async() -> void:
	tree.paused = false
	if weapons != null:
		weapons.reset()
	if state != null:
		state.etanks = 0
	if is_instance_valid(root):
		root.queue_free()
	await tree.physics_frame


func test_the_menu_starts_closed() -> void:
	assert_false(menu.is_open)


func test_opening_pauses_the_tree_and_closing_releases_it() -> void:
	menu.open()
	assert_true(menu.is_open)
	assert_true(tree.paused, "the menu opened without pausing play")
	menu.close()
	assert_false(menu.is_open)
	assert_false(tree.paused, "the menu closed and left the tree paused")


## With nothing unlocked the list is the buster and the E-tank row, and that is
## the state a new game is in -- so it is the one most likely to be hit.
func test_a_fresh_run_lists_the_buster_and_the_etank_row() -> void:
	if weapons == null:
		return
	menu.open()
	assert_eq(menu.rows.size(), 2, "rows were %s" % str(menu.rows))
	assert_has(menu.rows, weapons.BUSTER)
	assert_has(menu.rows, PauseMenu.ETANK_ROW)


func test_an_unlocked_weapon_appears_and_can_be_equipped() -> void:
	if weapons == null:
		return
	weapons.unlock(&"tide_crawler")
	menu.open()
	assert_has(menu.rows, &"tide_crawler")
	menu.selected = menu.rows.find(&"tide_crawler")
	assert_true(menu.confirm())
	assert_eq(weapons.current, &"tide_crawler")


## Wrapping matters more than it sounds: with two or three rows, wrapping is how
## the player reaches the row above without holding up through the whole list.
func test_the_selection_wraps_in_both_directions() -> void:
	menu.open()
	var count := menu.rows.size()
	menu.selected = 0
	menu.move_selection(-1)
	assert_eq(menu.selected, count - 1)
	menu.move_selection(1)
	assert_eq(menu.selected, 0)


# --- E-tanks ---------------------------------------------------------------------

func test_an_etank_refills_the_player_and_is_spent() -> void:
	if state == null:
		return
	state.etanks = 1
	player.health.current = 4
	menu.open()
	assert_true(menu.use_etank())
	assert_eq(player.health.current, player.health.max_hp)
	assert_eq(state.etanks, 0)


## The original refuses this, and the refusal is the point: an E-tank spent at
## full health is simply gone, and that is a mistake worth not allowing.
func test_an_etank_is_refused_at_full_health() -> void:
	if state == null:
		return
	state.etanks = 1
	player.health.current = player.health.max_hp
	menu.open()
	assert_false(menu.use_etank())
	assert_eq(state.etanks, 1, "the tank was consumed and did nothing")


func test_an_etank_is_refused_when_there_are_none() -> void:
	if state == null:
		return
	state.etanks = 0
	player.health.current = 4
	menu.open()
	assert_false(menu.use_etank())
	assert_eq(player.health.current, 4)
