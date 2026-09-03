## The boss room: the seal, the entrance, the bar fill, and the award.
##
## This owns the *sequence*, not the fight. The boss knows how to enter and how
## to attack; the arena knows that the door shuts first, that the player cannot
## move until the bar is full, and that beating the boss awards a weapon. Those
## are stage-level facts, and putting them in the boss would mean writing them
## again for each of the eight.
##
## The sequence is a phase enum ticked on the physics frame rather than a
## coroutine, for the same reason everything else here is: a headless test can
## step it, and it cannot be left half-run by a scene change.
class_name BossArena
extends Area2D

## The player crossed the threshold and the room sealed behind them.
signal sealed()
## The bar is full and control is back. The fight starts here.
signal fight_started(boss: Boss)
## The boss is gone and the weapon (if any) has been awarded.
signal cleared(boss_index: int, weapon_id: StringName)

enum Phase { WAITING, SEALING, ENTERING, FILLING, FIGHTING, CLEARED }

## Frames the room holds still after the seal, before the beam comes down.
## The original's pause here is what makes the seal read as a seal.
const SEAL_PAUSE_FRAMES := 30
## Frames between the bar finishing and control coming back.
const READY_PAUSE_FRAMES := 12
## Frames from the boss dying to the weapon-get. Long enough for the explosion
## to finish and the room to be quiet for a beat.
const AWARD_PAUSE_FRAMES := 45

## Trigger size in tiles. Tall, so it cannot be jumped over.
@export var size_tiles := Vector2(1.0, 8.0)
## The boss to build, as a script -- the same convention as WeaponData's
## projectiles, and for the same reason: a boss is a script, not a scene file.
@export var boss_script: Script
## Where the boss lands, in tile coordinates relative to this node.
@export var boss_offset_tiles := Vector2(8.0, 0.0)
## The Room this arena is in, for the floor span Spout-style patterns need.
##
## Named explicitly rather than found by walking up the tree: stage 1 adds its
## rooms as *siblings* of everything in them, because a Room is a camera bound
## rather than a container. A parent walk would find nothing and the boss would
## leap into a wall.
@export var arena_room: NodePath

var boss: Boss = null
var phase: Phase = Phase.WAITING

var _player: Player = null
var _frames := 0
var _hud: Hud = null
var _tile := 72.0


func _ready() -> void:
	collision_layer = Layers.bit(Layers.TRIGGER)
	collision_mask = Layers.bit(Layers.PLAYER_BODY)
	monitoring = true

	var autoload := get_node_or_null(^"/root/Tuning")
	if autoload != null:
		_tile = autoload.player.tile_size()

	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size_tiles * _tile
	shape.shape = rect
	shape.position.y = -rect.size.y * 0.5
	add_child(shape)

	body_entered.connect(_on_body_entered)


## Optional: the HUD that should show the boss bar. Without one the sequence
## still runs -- the fill is timed by this node, not by the bar, so a headless
## test gets the same frame counts as a running game.
func use_hud(hud: Hud) -> void:
	_hud = hud


func is_cleared() -> bool:
	return phase == Phase.CLEARED


## Frames the bar takes to fill: one tick per EnergyBar.FILL_FRAMES_PER_TICK,
## for the boss's full 28. Named rather than inlined because the fight cannot
## start before it and a test needs to know how long to step.
func fill_frames() -> int:
	return Health.BAR_TICKS * EnergyBar.FILL_FRAMES_PER_TICK


func _physics_process(_delta: float) -> void:
	_frames += 1
	match phase:
		Phase.SEALING:
			if _frames >= SEAL_PAUSE_FRAMES:
				_start_entrance()
		Phase.FILLING:
			if _frames >= fill_frames() + READY_PAUSE_FRAMES:
				_start_fight()
		Phase.CLEARED:
			pass
		_:
			pass


func _on_body_entered(body: Node2D) -> void:
	if phase != Phase.WAITING or not (body is Player):
		return
	if boss_script == null:
		push_error("BossArena at %s has no boss_script" % get_path())
		return
	_player = body as Player
	phase = Phase.SEALING
	_frames = 0
	# Frozen, not disabled: gravity keeps running so a player who walked in
	# mid-stride lands rather than hanging in the air (see Player.set_frozen).
	_player.set_frozen(true)
	sealed.emit()


func _start_entrance() -> void:
	phase = Phase.ENTERING
	_frames = 0

	boss = boss_script.new() as Boss
	if boss == null:
		push_error("BossArena at %s: boss_script is not a Boss" % get_path())
		phase = Phase.WAITING
		_player.set_frozen(false)
		return
	boss.name = "Boss"
	var level := get_parent()
	level.add_child(boss)

	var landing := global_position + boss_offset_tiles * _tile
	if boss.has_method("set_arena_span"):
		var span := _floor_span()
		boss.call("set_arena_span", span.x, span.y)
	boss.intro_landed.connect(_on_intro_landed)
	boss.defeated.connect(_on_boss_defeated)
	boss.begin_intro(landing, _player)


func _on_intro_landed() -> void:
	phase = Phase.FILLING
	_frames = 0
	if _hud != null and boss != null:
		# Tracked at zero and then filled, which is what makes the fill visible:
		# `track` would seed the bar at 28 and there would be nothing to watch.
		_hud.show_boss_bar(boss.health)


func _start_fight() -> void:
	phase = Phase.FIGHTING
	_frames = 0
	if _player != null:
		_player.set_frozen(false)
	if boss != null:
		boss.begin_fight()
		fight_started.emit(boss)


func _on_boss_defeated(defeated_boss: Boss) -> void:
	phase = Phase.CLEARED
	_frames = 0
	var index := defeated_boss.boss_index
	var weapon := defeated_boss.weapon_id
	boss = null

	if _hud != null:
		_hud.hide_boss_bar()

	var state := get_node_or_null(^"/root/GameState")
	if state != null:
		state.mark_boss_defeated(index)
	var weapons := get_node_or_null(^"/root/WeaponManager")
	if weapons != null and weapon != &"":
		weapons.unlock(weapon)

	cleared.emit(index, weapon)


## Left and right edges of the arena floor, from the enclosing Room. Falls back
## to a span centred on the landing point when there is no Room -- a bare test
## tree has none, and a boss that could not be built without one would be
## untestable.
func _floor_span() -> Vector2:
	var room := _room()
	if room != null:
		var bounds := room.world_bounds()
		return Vector2(bounds.position.x + _tile, bounds.end.x - _tile)
	var centre := global_position.x + boss_offset_tiles.x * _tile
	return Vector2(centre - 6.0 * _tile, centre + 6.0 * _tile)


## The named room, or the nearest Room ancestor when none was named.
func _room() -> Room:
	if not arena_room.is_empty():
		var named := get_node_or_null(arena_room) as Room
		if named != null:
			return named
	var node := get_parent()
	while node != null:
		if node is Room:
			return node as Room
		node = node.get_parent()
	return null
