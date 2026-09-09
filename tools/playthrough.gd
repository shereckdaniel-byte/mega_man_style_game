## Drives stage 1 from spawn to the boss door, then fights Tide, and reports how
## far it got.
##
##   godot --headless --script res://tools/playthrough.gd
##   godot --headless --script res://tools/playthrough.gd -- stage=substation
##   godot --headless --script res://tools/playthrough.gd -- seed=1 stage=breakers
##   xvfb-run -a godot --script res://tools/playthrough.gd -- <out_dir>   # + a png
##
## **It advances on `physics_frame`, and that is not a detail.** It used to await
## `process_frame` -- a *rendered* frame -- while every constant in it (JUMP_HOLD,
## SLIDE_HOLD, SHOOT_PERIOD, the traversal budget) is a count of physics ticks,
## and the engine runs as many physics ticks per rendered frame as it needs to
## keep up with the wall clock. On a quiet machine that is one, and the two agree.
## Under load it is two or three: the bot then decides once per three ticks,
## holds a jump for 48 ticks instead of 16, and walks blindly past the lip of
## every gap it was watching for.
##
## The numbers that came out of it were therefore a measurement of the machine.
## Four runs of the same commit, same seed, no code change between them:
##
##   alone on the box        0 deaths, reached the door on 22 HP
##   four in parallel       34 deaths, reached the door on 20 HP
##   four in parallel       36 deaths, reached the door on 20 HP
##   four in parallel       32 deaths, never got out of room 1
##
## docs/PLAN.md M5a reads "the bot now takes eight deaths getting through where
## it took none" and calls the difficulty an open question. Eight is a sample
## from that spread. Awaiting `physics_frame` locks one decision to one tick
## whatever else the box is doing, which is what makes any of these figures
## comparable to any other.
##
## It also loads the stage directly rather than the configured main scene. The
## main scene is boot.tscn, which only forwards to stage 1 when a display exists
## -- so run headless, the bot used to spend 9000 frames driving the boot screen
## and report a stage that could not be finished.
##
## A traversal check, not a difficulty check. It answers one question — is the
## stage finishable at all — which is the question authored geometry gets wrong
## in ways that look fine from a screenshot. Three real bugs came out of it: a
## pit that did not kill during i-frames, a kill that left the player walking,
## and a three-tile step in a corridor with no way round.
##
## It reads the deck ahead of the player and jumps for gaps and steps, rather
## than hopping on a fixed cadence, and it climbs: stage 1 is a U now, so a bot
## that only walks right stops at the first shaft and reports a stage that
## cannot be finished. It does not pathfind -- it asks the stage which way the
## next room lies, walks to the shaft, and holds up or down. That matters: a fixed cadence walks into
## gaps a player would clear, so it reports failures the stage does not have. A
## bot that jumps when there is something to jump means a failure is the stage's.
##
## The fight half is a *survivability* check, not a skill one. It shoots on a
## fixed cadence and jumps at anything coming at it low, which is roughly what a
## competent player does and nowhere near what a good one does. If this bot can
## win, the fight is winnable buster-only; if it loses, look at the fight rather
## than concluding anything.
##
## Development tool: not referenced by the game or by CI.
extends SceneTree

## The stages it knows how to drive, by the name passed after `--`.
##
## Loaded directly rather than through `application/run/main_scene`: see the note
## above on why. Stage 1 is the default because it is the one with a difficulty
## question open against it.
const STAGES := {
	"dawn_boardwalk": "res://scenes/stages/dawn_boardwalk/dawn_boardwalk.tscn",
	"substation": "res://scenes/stages/substation/substation.tscn",
	"breakers": "res://scenes/stages/breakers/breakers.tscn",
	"mirror_field": "res://scenes/stages/mirror_field/mirror_field.tscn",
	"turbine_row": "res://scenes/stages/turbine_row/turbine_row.tscn",
	"stack": "res://scenes/stages/stack/stack.tscn",
}
const DEFAULT_STAGE := "dawn_boardwalk"

## Printed where a seed would go when none was given. Any integer is a valid
## seed, including 0 and negatives, so absence is carried by its own flag rather
## than by a magic value.
const UNSEEDED_LABEL := "none"

const DECK_ROW := 11
const DECK_DEPTH := 2
## Cells ahead to look for a hole or a step.
##
## One, not two. Jumping when the hole is two cells away launches the arc a cell
## early and lands it *in* the gap: a jump takes about 40 frames and covers 3.4
## tiles, so starting it 2 tiles before a 2-tile gap puts the landing right in
## the middle. This cost a wrong conclusion once -- the bot fell in, and the
## stage looked unfinishable when the bot was simply jumping too soon.
const LOOKAHEAD := 1

## How a panel path is read, in tiles from the player's feet.
##
## `PANEL_NEAR_TILES` is what keeps the panel the bot is standing on out of the
## answer -- it sits at a dx of about zero and would otherwise be "the next one"
## forever. The other three are a jump: 3.4 tiles across, 2.89 up, and a drop
## that is looser than the rise because falling onto a panel is free.
const PANEL_NEAR_TILES := 0.5
const PANEL_REACH_TILES := 3.2
const PANEL_RISE_TILES := 2.6
const PANEL_DROP_TILES := 4.0

## Frames a panel must have left before the bot commits to it. A jump is airborne
## about forty (see `PhaseBlock.BEAT_FRAMES`), so anything less is a hop onto
## something that will not be there.
const PANEL_LEAD_FRAMES := 40

## Frames `_hop_reach` simulates before giving up on an arc coming back down.
## A full jump is airborne about forty; 200 is far past any hold this bot uses
## and is only here so the loop is bounded.
const HOP_MAX_FRAMES := 200

## Frames to hold jump, for a full arc.
##
## Derived, not chosen: the rise lasts `jump_velocity_pf / gravity_pf` =
## 4.9375 / 0.25 = 19.75 physics frames, and releasing before that cuts the jump
## by design (states/jump.gd). Anything past 20 is the same jump, so 24 is 20
## with margin.
##
## It was 16, which is a jump cut at four-fifths of its rise -- 198 px instead of
## 208, and about a third of a tile short across. That was invisible while the
## bot advanced on rendered frames, because 16 of those were 28 physics ticks and
## the release landed past the apex anyway. Locking the loop to physics made the
## constant mean what it says, and the bot promptly fell into the Pilings gap
## five times running: a two-cell gap it clears with 47 px to spare on a full
## jump and misses by a few on a cut one.
const JUMP_HOLD := 24
## How close to the shaft's centre, in tiles, before the bot commits to climbing.
const SHAFT_TOLERANCE := 0.6
## Frames to keep climbing after the room changes, so the bot steps clear of the
## shaft instead of dropping straight back down it.
const CLIMB_CLEAR_FRAMES := 40
## Frames without horizontal progress before we call it stuck.
const STUCK_FRAMES := 900

## Frames to give the walk from spawn to the boss door before calling it a loss.
##
## **Sized against the longest stage, not the average one.** It was 9000 while
## every stage was eight or nine rooms and stage 1 crossed in about 2400. Stage 1
## is nineteen rooms now and takes 6800, which fits -- and a run that hit one
## more bad jump would not have, so the bot would have reported a stage it can
## finish as one it cannot. Twice the longest known crossing leaves room for the
## stage after this one.
const TRAVERSAL_FRAMES := 14000

## Frames to give the boss fight before calling it a loss.
const FIGHT_FRAMES := 5400
## Frames between trigger pulls. The buster caps at 3 live pellets anyway; this
## keeps the bot from spamming just_pressed every frame.
const SHOOT_PERIOD := 8
## How close, in tiles, the bot tries to stay to the boss. Close enough to hit,
## far enough to read a wave coming.
const FIGHT_RANGE_TILES := 5.0
## Closer than this and the bot backs off.
const RETREAT_RANGE_TILES := 3.0
## How far ahead, in tiles, the bot looks for spikes. Further than the gap
## lookahead: a jump has to *start* before the spikes, not on them.
const SPIKE_LOOKAHEAD_TILES := 2.2
## Cells ahead to look for a low tunnel. Two, so the slide starts before the
## ceiling rather than under it.
const CEILING_LOOKAHEAD := 2
## How far a slide carries, in cells. PlayerTuning puts it at 4.06 tiles, and a
## slide can be neither steered nor cancelled once committed.
const SLIDE_REACH_CELLS := 5
## An incoming shot nearer than this, in tiles, is worth dodging.
const DODGE_RANGE_TILES := 2.6
## Frames to hold the slide input.
const SLIDE_HOLD := 6

var _stage: Node
var _player: Player
var _deck: TileMapLayer
var _tile := 72.0
var _jump_left := 0
var _slide_left := 0
var _climb_left := 0
var _room_index := 0
var _climbing_up := false
var _log: PlaytestLog
## `seed=` and whether it was given. See `_read_seed`.
var _seed := 0
var _seeded := false


func _initialize() -> void:
	_run()


## `seed=<int>` from the arguments after `--`. Absent means unseeded.
##
## **The default is deliberately unseeded, and that is the whole design of this
## option.** `Boss._rng` calls `randomize()` in `_ready`, so a fight is a
## different fight on every run: Breakers came back 18 HP / 0 deaths and then
## 28 / 1 within the hour on identical code, and Mirror Field 26 / 0, 23 / 0 and
## 28 / 1. A single run is a sample. Seeding by default would hide that spread
## behind one fight repeated forever, which is worse than knowing the number is
## noisy -- `PlaytestLog.summary_line` has said so in a docstring since M5.
##
## What a seed is *for* is comparing two things that should be the same. The
## boss-facing fix in M6m changed `sprite.flip_h`, which `Boss.facing()` reads,
## so it could have moved the first pattern of every fight; seeded runs against
## `main` came back frame-identical on all four stages, which is a fact no
## number of unseeded runs could have established.
##
## **Every source of randomness the run touches has to be seeded, or the promise
## is a lie.** There are two: `Boss._rng` picks the pattern order, and
## `Enemy._drop_rng` rolls what a killed enemy leaves behind. The stage backdrops
## seed their own generators with a written-down constant and nothing else in the
## game is random. A third one added later and not wired in here would not fail
## anything -- runs would simply stop reproducing, quietly -- so
## `tests/test_pickups.gd` asserts the drop half and `tests/test_boss.gd` the
## pattern half.
func _read_seed() -> void:
	for argument in OS.get_cmdline_user_args():
		if not argument.begins_with("seed="):
			continue
		var text := argument.substr(5).strip_edges()
		if not text.is_valid_int():
			push_error("seed=%s is not an integer; running unseeded" % text)
			return
		_seed = text.to_int()
		_seeded = true
		return


func _seed_label() -> String:
	return str(_seed) if _seeded else UNSEEDED_LABEL


## Pins the boss's pattern order, once the arena has built it.
##
## Called from the fight loop rather than at startup because the boss does not
## exist until the arena spawns it, and `_ready` randomises. The arena spawns it
## during the seal, well before `begin_fight` picks the first pattern.
func _seed_boss(arena: BossArena) -> bool:
	if not _seeded or arena.boss == null:
		return false
	arena.boss.seed_rng(_seed)
	return true


## `stage=<name>` from the arguments after `--`, or the default.
##
## Keyed rather than positional because the tool already takes a positional
## out_dir, and "the first argument is the stage unless it looks like a path" is
## the kind of rule that silently drives the wrong stage.
func _requested_stage() -> String:
	for argument in OS.get_cmdline_user_args():
		if not argument.begins_with("stage="):
			continue
		var name := argument.substr(6).strip_edges()
		if STAGES.has(name):
			return name
		push_error("unknown stage %s; known: %s" % [name, ", ".join(STAGES.keys())])
	return DEFAULT_STAGE


func _run() -> void:
	await physics_frame
	var stage_name := _requested_stage()
	_read_seed()
	# Drops are seeded before the stage loads, because the first enemy can die
	# before the fight loop -- which is where the boss gets seeded -- ever runs.
	if _seeded:
		Enemy.seed_drops(_seed)
	print("stage: %s  seed: %s" % [stage_name, _seed_label()])
	change_scene_to_file(STAGES[stage_name])
	for i in 60:
		await physics_frame

	_stage = current_scene
	_player = _stage.get_node("Player")
	# "Terrain" in every stage: AuthoredStage names it for what it is, so the
	# bot is not stage-specific for the sake of one node name.
	_deck = _stage.get_node("Terrain")
	var autoload := root.get_node_or_null(^"/root/Tuning")
	if autoload != null:
		_tile = autoload.player.tile_size()

	var state := root.get_node_or_null(^"/root/GameState")
	if state != null:
		state.lives = 99

	# The ledger, so a run says *where* it lost health and to what rather than
	# handing back one number. Same class the stage attaches for a human run, so
	# a bot report and a playtester's report can be read side by side.
	_log = PlaytestLog.new()
	_log.name = "PlaytestLog"
	_stage.add_child(_log)
	_log.watch(_player, _stage)

	var goal: float = _stage.boss_door_position().x
	_stage.room_changed.connect(func(r: Room) -> void:
		print("  entered %s" % r.name)
		for i in _stage.rooms().size():
			if _stage.rooms()[i] == r:
				_room_index = i
				break
		# Keep holding the climb briefly so the bot steps off the shaft rather
		# than turning round and dropping straight back down it.
		_climb_left = CLIMB_CLEAR_FRAMES)
	print("goal_x=%.0f  rooms=%d" % [goal, _stage.rooms().size()])

	var best: float = _player.global_position.x
	var last_room := 0
	var stuck := 0
	var reached := false
	for frame in TRAVERSAL_FRAMES:
		await physics_frame
		if _stage.is_transitioning():
			_release()
			continue
		_drive(frame)
		var x: float = _player.global_position.x
		# Progress is a room change *or* ground gained. Climbing a shaft makes
		# no horizontal progress at all, so an x-only stuck detector calls a
		# working ladder a soft lock.
		if _room_index != last_room:
			last_room = _room_index
			best = x
			stuck = 0
		elif x > best + 4.0:
			best = x
			stuck = 0
		else:
			stuck += 1
		# The room matters as well as the x. Stage 1 is a U, and the Tide room
		# sits *underneath* the boss door in the same column -- an x-only check
		# reports success while the player is still under the deck.
		if _room_index >= _stage.boss_door_room_index() and x >= goal:
			reached = true
			print("REACHED the boss door at frame %d" % frame)
			break
		if frame % 60 == 0:
			print("  f%-5d x=%-6.0f y=%-6.0f cell=%-4d hp=%-3d %-6s floor=%s"
				% [frame, _player.global_position.x, _player.global_position.y,
					_cell_x(), _player.health.current,
					_player.state_machine.current_name(), _player.is_on_floor()])
		if stuck > STUCK_FRAMES:
			print("STUCK at x=%.0f for %d frames" % [x, stuck])
			break
	_release()

	print("result: reached=%s  x=%.0f/%.0f  room=%s  deaths=%d  hp=%d"
		% [reached, _player.global_position.x, goal, _stage.room.name,
			_log.deaths, _player.health.current])

	var won := false
	if reached:
		won = await _fight()

	_release()
	for line in _log.report():
		print(line)
	# The seed on the summary line as well as in the header, because the summary
	# is the line that gets pasted into a document and the header is the one that
	# scrolls away. A number quoted without its seed is not reproducible.
	print("%s seed=%s" % [_log.summary_line(), _seed_label()])
	# The screenshot needs something to have been drawn, so it is only offered
	# when there is a display: `xvfb-run -a godot --script ... -- <out_dir>`.
	# Headless it is skipped rather than saving a blank, which is what asking the
	# root viewport for its texture with nothing rendered into it produces.
	# PackedStringArray has no filter(), so this is a loop rather than a one-liner.
	var args: Array[String] = []
	for argument in OS.get_cmdline_user_args():
		if not argument.begins_with("stage="):
			args.append(argument)
	if args.size() > 0:
		if DisplayServer.get_name() == "headless":
			print("no display: skipping the screenshot (run under xvfb-run for one)")
		else:
			root.get_texture().get_image().save_png("%s/playthrough.png" % args[0])
	quit(0 if reached and won else 1)


## Walks into the arena and fights the stage's boss with the buster alone.
##
## **It used to fight Tide on every stage**, which is to say it printed "TIDE
## DOWN" and then waited 360 frames for `tide_crawler` to be unlocked. On stage 1
## that is right. On stages 2-4 the award lands, the wrong id never appears, the
## wait runs to the end -- long enough for the stage-exit sequence to free the
## level and its `PlaytestLog` out from under the caller -- and a run that beat
## the boss and took its weapon is reported as a loss with a script error behind
## it. The stage was fine every time.
##
## Same class of fault as the six enemy skins that never flipped: a thing that
## was written when there was one stage and was never revisited when there were
## four. The expected weapon now comes off the boss.
func _fight() -> bool:
	var arena: BossArena = _stage.arena()
	if arena == null:
		print("no arena on this stage")
		return false

	var weapons := root.get_node_or_null(^"/root/WeaponManager")
	var awarded: Array[StringName] = []
	arena.cleared.connect(func(_i: int, w: StringName) -> void: awarded.append(w))

	var last_phase := -1
	# Nothing to do when running unseeded, so the check is spent before the loop
	# rather than asked once per frame for the length of a fight.
	var seeded := not _seeded
	for frame in FIGHT_FRAMES:
		await physics_frame
		if not seeded:
			seeded = _seed_boss(arena)
		if arena.phase != last_phase:
			last_phase = arena.phase
			print("  arena phase -> %s at fight frame %d" % [_phase_name(last_phase), frame])
		if arena.is_cleared():
			print("%s DOWN at fight frame %d, player hp=%d"
				% [_stage.boss_name().to_upper(), frame, _player.health.current])
			var expected := _expected_weapon(arena, awarded)
			# Let the weapon-get screen come and go. Bounded by the award rather
			# than by the clock: waiting out the full 360 lets the stage exit,
			# which frees the level and the ledger the caller is about to print.
			for _i in 360:
				await physics_frame
				if _weapon_landed(weapons, expected):
					break
			var got := _weapon_landed(weapons, expected)
			print("awarded=%s  expected=%s  unlocked=%s  ammo=%d"
				% [str(awarded), expected, got,
					weapons.get_ammo(expected) if weapons != null else -1])
			return got
		if _player.health.is_dead():
			print("player died during the fight at frame %d" % frame)
			return false
		_drive_fight(arena, frame)
		if frame % 120 == 0:
			var hp := arena.boss.health.current if arena.boss != null else -1
			var pattern := "-"
			if arena.boss != null and arena.boss.current_pattern() != null:
				pattern = String(arena.boss.current_pattern().id)
			print("  f%-5d boss=%-3d player=%-3d pattern=%-7s step=%d  px=%.0f bx=%.0f gap=%.1ft shots=%d eshots=%d frozen=%s"
				% [frame, hp, _player.health.current, pattern,
					arena.boss.pattern_step() if arena.boss != null else -1,
					_player.global_position.x,
					arena.boss.global_position.x if arena.boss != null else -1.0,
					absf(arena.boss.global_position.x - _player.global_position.x) / _tile if arena.boss != null else -1.0,
					_player.live_shots(), _count_enemy_shots(), _player.is_frozen()])
	print("fight timed out")
	return false


## One frame of fighting: close to range, shoot on a cadence, jump anything low
## and incoming.
## The weapon this stage's boss is meant to hand over.
##
## Read from what the arena announced, falling back to the boss itself -- rather
## than from a copy of the roster kept here, which is the arrangement
## `StageRoster` was extracted to stop.
##
## **Resolved at the moment of the clear, not before it.** Asked at the top of
## the fight the boss does not exist yet, and the answer comes back `buster` --
## which is always unlocked, so the check passes for a stage that awarded
## nothing at all. A test that cannot fail is worse than no test.
func _expected_weapon(arena: BossArena, awarded: Array[StringName]) -> StringName:
	if awarded.size() > 0 and awarded[0] != &"":
		return awarded[0]
	if arena.boss != null and arena.boss.weapon_id != &"":
		return arena.boss.weapon_id
	return &""


## `is_unlocked` says yes to the buster unconditionally, so an empty or missing
## expectation has to be a failure rather than a pass.
func _weapon_landed(weapons: Node, expected: StringName) -> bool:
	if weapons == null or expected == &"" or expected == &"buster":
		return false
	return weapons.is_unlocked(expected)


func _drive_fight(arena: BossArena, frame: int) -> void:
	_release_move()

	if arena.boss == null or not is_instance_valid(arena.boss):
		# Still walking in, or the boss is exploding. Head for the arena.
		Input.action_press(&"move_right")
		return

	var to_boss: float = arena.boss.global_position.x - _player.global_position.x
	var gap := absf(to_boss) / _tile
	# Hold the trigger toward the boss whenever it is not too close.
	#
	# Not "stand still at the ideal range": the player fires the way they face,
	# and facing follows the movement input, so a bot that stopped moving kept
	# whichever way it happened to be pointing -- usually away, after backing
	# off -- and emptied its whole magazine into the far wall for 90 seconds
	# while the boss sat untouched. Standing still is not a neutral choice here.
	if gap < RETREAT_RANGE_TILES:
		Input.action_press(&"move_left" if to_boss > 0.0 else &"move_right")
	else:
		Input.action_press(&"move_right" if to_boss > 0.0 else &"move_left")

	if frame % SHOOT_PERIOD == 0:
		Input.action_press(&"shoot")
	elif frame % SHOOT_PERIOD == 1:
		Input.action_release(&"shoot")

	if _slide_left > 0:
		_slide_left -= 1
		if _slide_left == 0:
			Input.action_release(&"jump")
			Input.action_release(&"move_down")
		return
	if _jump_left > 0:
		_jump_left -= 1
		if _jump_left == 0:
			Input.action_release(&"jump")
		return
	if not _player.is_on_floor():
		return
	# Two shot heights, two answers -- which is the whole point of having both
	# patterns. Jumping a chest-height shot walks into it.
	if _incoming_shot(-0.2, 1.6):
		Input.action_press(&"move_down")
		Input.action_press(&"jump")
		_slide_left = SLIDE_HOLD
	elif _incoming_shot(-1.6, 0.4):
		Input.action_press(&"jump")
		_jump_left = JUMP_HOLD


## Is there an enemy shot close, in the given band above the player's feet?
##
## `low` and `high` are in tiles above the feet, and y grows downward, so the
## band is expressed as offsets: (-1.6, 0.4) is knee-to-head, (-0.2, 1.6) is
## chest-and-up.
func _incoming_shot(low: float, high: float) -> bool:
	var reach := DODGE_RANGE_TILES * _tile
	for child in _stage.get_children():
		if not (child is EnemyShot):
			continue
		var shot := child as EnemyShot
		var delta := shot.global_position - _player.global_position
		if absf(delta.x) > reach:
			continue
		if delta.y >= low * _tile and delta.y <= high * _tile:
			return true
	return false


func _count_enemy_shots() -> int:
	var n := 0
	for child in _stage.get_children():
		if child is EnemyShot:
			n += 1
	return n


func _release_move() -> void:
	for action in [&"move_right", &"move_left"]:
		if Input.is_action_pressed(action):
			Input.action_release(action)


func _phase_name(phase: int) -> String:
	var names := ["WAITING", "SEALING", "ENTERING", "FILLING", "FIGHTING", "CLEARED"]
	return names[phase] if phase >= 0 and phase < names.size() else "?"


## Which way the exit from the current room lies: 0 across, +1 down, -1 up.
func _exit_direction() -> int:
	var rooms: Array = _stage.room_table()
	if _room_index + 1 >= rooms.size():
		return 0
	var here: int = int(rooms[_room_index]["band"])
	var there: int = int(rooms[_room_index + 1]["band"])
	return signi(there - here)


## The world x of the shaft the current room exits through, or -1 across.
func _shaft_x() -> float:
	var rooms: Array = _stage.room_table()
	var spec: Dictionary = rooms[_room_index]
	var shaft: Array = spec.get("shaft", spec.get("shaft_up", []))
	if shaft.is_empty():
		return -1.0
	var origin: int = _stage.room_origin(_room_index)
	return (float(origin) + float(shaft[0]) + float(shaft[1]) * 0.5) * _tile


## One frame of input: walk right, shoot, and jump when the deck ahead demands it.
##
## It shoots the whole way for a reason. The traversal bot used to only walk and
## jump, which meant the stage runs measured *surviving* the enemies rather than
## fighting them -- and that is precisely the blind spot that let the Dockrat
## ship unkillable for two milestones. A run that never fires cannot notice that
## firing does nothing.
func _drive(frame: int = 0) -> void:
	if frame % SHOOT_PERIOD == 0:
		Input.action_press(&"shoot")
	elif frame % SHOOT_PERIOD == 1:
		Input.action_release(&"shoot")

	# Still stepping clear of a shaft after a vertical transition.
	if _climb_left > 0:
		_climb_left -= 1
		_release_move()
		Input.action_press(&"move_up" if _climbing_up else &"move_down")
		return
	Input.action_release(&"move_up")
	Input.action_release(&"move_down")

	# Off the ladder before anything else. Climb zeroes horizontal velocity, so
	# a bot that has finished climbing and starts walking simply hangs there --
	# which is what "stuck 36 px from the boss door" turned out to be. Jumping
	# off is the game's own way down from a ladder (states/climb.gd).
	if _player.state_machine.current_name() == &"Climb" and _exit_direction() == 0:
		Input.action_press(&"jump")
		_jump_left = 4
		return

	var heading := 1
	var vertical := _exit_direction()
	if vertical != 0:
		var shaft := _shaft_x()
		if shaft >= 0.0:
			var dx := shaft - _player.global_position.x
			if absf(dx) <= SHAFT_TOLERANCE * _tile:
				# On the shaft: climb, and stop walking into its wall.
				_release_move()
				_climbing_up = vertical < 0
				Input.action_press(&"move_up" if _climbing_up else &"move_down")
				return
			heading = 1 if dx > 0.0 else -1

	_release_move()
	Input.action_press(&"move_right" if heading > 0 else &"move_left")

	# Jumping is applied whichever way the bot is walking. The first version
	# returned early while heading for a shaft, so the bot walked into the
	# two-tile block in the Descent room and stood there for 900 frames --
	# reported as a stuck stage, caused entirely by the bot forgetting it could
	# jump when it had somewhere to be.
	if _jump_left > 0:
		_jump_left -= 1
		if _jump_left == 0:
			Input.action_release(&"jump")
		return
	if not _player.is_on_floor():
		return
	# A ceiling ahead is slid under, not jumped -- and the check comes first,
	# because jumping into a low tunnel is how you die in one.
	#
	# Two guards, both learned the hard way. Re-triggering while already sliding
	# chains slide onto slide: each one restarts the full four-tile dash, so the
	# bot kept re-committing as it passed under a three-cell overhang and came
	# out four tiles further along than it meant to -- straight into the gap
	# beyond, fourteen times running. And a slide cannot be steered or cancelled,
	# so starting one with a hole inside its reach is a decision to fall in.
	if _player.state_machine.current_name() != &"Slide" \
			and not _hole_within(heading, SLIDE_REACH_CELLS) \
			and _ceiling_ahead(heading):
		Input.action_press(&"move_down")
		Input.action_press(&"jump")
		_slide_left = SLIDE_HOLD
		return
	if _hole_ahead(heading):
		# A gap wider than a jump is a ride, not a leap. Wait at the lip until
		# the platform is alongside rather than walking off into the water --
		# which the bot did twenty-one times, because "there is a hole, jump"
		# is the only answer it had and the hole is eight cells across.
		var ferry := _platform_for(heading)
		if ferry != null:
			if not _platform_is_boardable(ferry) \
					or not _platform_is_outbound(ferry, heading):
				_release_move()
				return
			# Level and alongside: step on. Jumping onto a platform that is
			# already at your feet only risks overshooting it into the water
			# behind.
			var rise := _player.global_position.y - ferry.global_position.y
			if absf(rise) < 0.5 * _tile:
				return
			Input.action_press(&"jump")
			_jump_left = JUMP_HOLD
			return
		# **A panel path is a ferry that does not move.** Instead of waiting for
		# the platform to come to the lip, you wait for the floor to arrive --
		# and then the hop is a measured one rather than a full jump, because
		# the next panel is two cells away and a full jump covers three and a
		# half. See `_hop_hold`.
		var panel := _panel_for(heading)
		if panel != null:
			if not _panel_is_landable(panel):
				_release_move()
				return
			Input.action_press(&"jump")
			_jump_left = _hop_hold(panel.global_position - _player.global_position)
			return
	if _hole_ahead(heading) or _step_ahead(heading) or _spikes_ahead(heading):
		Input.action_press(&"jump")
		_jump_left = JUMP_HOLD


func _cell_x() -> int:
	return int(floor(_player.global_position.x / _tile))


func _solid(cell: Vector2i) -> bool:
	return _deck.get_cell_source_id(cell) != -1


## The deck row of the room the player is in.
##
## Not the constant it used to be. Stage 1 has two bands now, and a bot that
## always looks at row 11 is looking at the boardwalk while standing on the
## pilings fifteen rows below it -- every cell reads as a hole and it jumps
## continuously.
func _deck_row() -> int:
	return _stage.room_deck_row(_room_index)


## No deck under the next couple of cells: jump the gap.
func _hole_ahead(heading: int) -> bool:
	var deck := _deck_row()
	for step in range(1, LOOKAHEAD + 1):
		var x := _cell_x() + step * heading
		var floored := false
		for y in range(deck, deck + DECK_DEPTH):
			if _solid(Vector2i(x, y)):
				floored = true
		if not floored:
			return true
	return false


## Spikes on the deck ahead: jump them.
##
## The bot has to know every verb the level speaks. Stage 1 gained spikes and
## this did not, so the bot walked into them at a steady pace and reported the
## stage as unfinishable -- twenty-eight deaths against geometry a player clears
## by tapping jump. A checker whose vocabulary is narrower than the level's does
## not measure the level, it measures the checker.
##
## Looked up in the scene rather than in the tile map: spikes are Hazard nodes,
## not deck cells, so `_solid()` cannot see them.
func _spikes_ahead(heading: int) -> bool:
	var reach := SPIKE_LOOKAHEAD_TILES * _tile
	var feet := _player.global_position
	for child in _stage.get_children():
		if not (child is Hazard) or child is KillPlane:
			continue
		var spike := child as Node2D
		var dx := (spike.global_position.x - feet.x) * float(heading)
		if dx < 0.0 or dx > reach:
			continue
		# Only what is on the ground the player is walking along; a hazard a
		# band away is not in the way.
		if absf(spike.global_position.y - feet.y) > 1.5 * _tile:
			continue
		return true
	return false


## A moving platform **in the current room**, if one exists.
##
## The room filter is the whole point. Scanning the stage instead found Under
## East's ferry from inside Pilings, four rooms away, and the bot stood at the
## lip of a two-cell gap waiting for a platform that was never coming -- a jump
## it had been making without trouble all along. A gap is only a crossing if
## the thing crossing it is here.
func _platform_for(_heading: int) -> MovingPlatform:
	if _stage.room == null:
		return null
	var bounds: Rect2 = _stage.room.world_bounds()
	for child in _stage.get_children():
		if child is MovingPlatform and bounds.has_point((child as Node2D).global_position):
			return child as MovingPlatform
	return null


## Is the platform about to carry the rider *forwards*?
##
## Boardable is not enough, and this is the whole of stage 3's Crane room. A
## ping-pong platform comes back past the near lip on its return leg, and it is
## alongside and level then too -- so the bot stepped on, kept holding forward
## because it was still on the near side of a hole, and walked straight off the
## far end of a platform that was travelling the other way. Into the spikes,
## deterministically, on the same frame every run.
##
## A person waits for the ferry going their way. This is that, and the answer
## has to come from `MovingPlatform.next_heading` rather than from `progress`:
## progress 0.16 is both "just set off" and "nearly home", and the first version
## of this check read the second as the first and boarded anyway.
func _platform_is_outbound(ferry: MovingPlatform, heading: int) -> bool:
	var going := ferry.next_heading()
	return going == 0 or going == heading


## Is the platform close enough, and level enough, to step onto?
func _platform_is_boardable(ferry: MovingPlatform) -> bool:
	var delta := ferry.global_position - _player.global_position
	# In front, within a stride, and at about the height the player is standing.
	return delta.x > -0.5 * _tile and delta.x < 2.2 * _tile \
		and absf(delta.y) < 1.2 * _tile


## Is there a hole within `cells` ahead? Used to refuse a slide that would
## carry the player into one.
func _hole_within(heading: int, cells: int) -> bool:
	var deck := _deck_row()
	for step in range(1, cells + 1):
		var x := _cell_x() + step * heading
		var floored := false
		for y in range(deck, deck + DECK_DEPTH):
			if _solid(Vector2i(x, y)):
				floored = true
		if not floored:
			return true
	return false


## A low ceiling ahead: slide under it.
##
## Read from the tile map rather than from the room table, so the bot sees the
## geometry the player sees. A cell filled at head height with the row below it
## open is a tunnel; a cell filled at *both* is a wall, which is `_step_ahead`'s
## business.
##
## Without this the bot walks into the tunnel, stops, and reports the stage as
## unfinishable -- the same failure the spikes produced, for the same reason: a
## checker whose vocabulary is narrower than the level's measures itself.
func _ceiling_ahead(heading: int) -> bool:
	var deck := _deck_row()
	for step in range(1, CEILING_LOOKAHEAD + 1):
		var x := _cell_x() + step * heading
		var head_blocked := _solid(Vector2i(x, deck - 2))
		var body_clear := not _solid(Vector2i(x, deck - 1))
		if head_blocked and body_clear:
			return true
	return false


## Deck at head height ahead: jump the step.
func _step_ahead(heading: int) -> bool:
	var deck := _deck_row()
	var x := _cell_x() + heading
	return _solid(Vector2i(x, deck - 1)) or _solid(Vector2i(x, deck - 2))


## The next panel of a path, within a hop of the player.
##
## **Deliberately not filtered by room, unlike `_platform_for`.** That filter
## exists because a mover four rooms away is a false positive a bot will stand at
## a lip waiting for; the reach here is already three tiles, which is a tighter
## bound than a room and cannot pick up anything the player is not about to jump
## to.
##
## Filtering by room also breaks at exactly the place it matters. A room changes
## when the player crosses its door, and Focus's first panel sits a couple of
## cells past Tower's -- so a room-filtered lookup goes blind for the few cells
## either side of the boundary, which is precisely where a path that starts near
## a room's edge begins. The bot walked off Focus's lip into the spikes because
## it could not see a panel one cell in front of it.
##
## Only panels that are **in front** count -- the one the bot is standing on is
## at dx of about zero and would otherwise be returned forever. Nearest wins,
## because a path is crossed a panel at a time and the far one is not the next
## one.
func _panel_for(heading: int) -> PhaseBlock:
	var feet := _player.global_position
	var best: PhaseBlock = null
	var best_dx := INF
	for child in _stage.get_children():
		if not (child is PhaseBlock):
			continue
		var panel := child as PhaseBlock
		var dx := (panel.global_position.x - feet.x) * float(heading)
		var dy := panel.global_position.y - feet.y
		# Ahead by more than a stride, inside a jump across, and inside a jump
		# up. A panel below the player is still a landing -- falling onto one is
		# how a descending path is crossed -- so the downward reach is looser.
		if dx < PANEL_NEAR_TILES * _tile or dx > PANEL_REACH_TILES * _tile:
			continue
		if dy < -PANEL_RISE_TILES * _tile or dy > PANEL_DROP_TILES * _tile:
			continue
		if dx < best_dx:
			best_dx = dx
			best = panel
	return best


## Is the panel worth committing to?
##
## **Solid now is not the question.** A jump takes about forty frames, and a
## panel with ten left is a panel the bot lands through. So the test is whether
## it will still be there on arrival, which is what `solid_frames_left` is for.
## A player reads the flicker and makes the same decision by eye.
func _panel_is_landable(panel: PhaseBlock) -> bool:
	return panel.is_solid() and panel.solid_frames_left() >= PANEL_LEAD_FRAMES


## Frames to hold jump for a hop that lands on `delta` rather than on a lip.
##
## **The bot could only make one jump before this, and it was the biggest one.**
## `JUMP_HOLD` is a full arc: 2.89 tiles up and about 3.4 across. That is the
## right answer at the lip of a gap, where the landing is a whole room of deck
## and overshooting costs nothing -- and it is the wrong answer at a panel two
## cells away, where the arc sails over the target and comes down in the hole
## past it. The bot cleared Trough's first panel and landed a tile and a half
## beyond its second, six times running, and the stage looked unfinishable.
##
## So the hold is measured: the arc is integrated one frame at a time, exactly
## as `PlayerTuning.jump_apex_px` does and for exactly the same reason -- the
## continuous formula is a sixth of a tile out, which here is the difference
## between landing on a panel and landing past it. The shortest hold that both
## reaches far enough and gets high enough wins; a full hold is the fallback, so
## a target out of range is still attempted rather than stood in front of.
func _hop_hold(delta: Vector2) -> int:
	var tuning: PlayerTuning = _player.tuning
	var across := absf(delta.x) / tuning.world_scale
	var rise := -delta.y / tuning.world_scale  # NES px the target sits above us
	for hold in range(1, JUMP_HOLD + 1):
		var reach := _hop_reach(tuning, hold, rise)
		if reach >= across:
			return hold
	return JUMP_HOLD


## How far a jump held for `hold` frames travels before it comes back down to
## `rise` NES px above where it started, or -1 when it never gets that high.
##
## Semi-implicit Euler, in the engine's own order (`v += g` then `y += v`), so
## the answer is the arc the player actually flies rather than the one the
## textbook describes.
func _hop_reach(tuning: PlayerTuning, hold: int, rise: float) -> float:
	var v := -tuning.jump_velocity_pf
	var y := 0.0
	var peak := 0.0
	for frame in range(1, HOP_MAX_FRAMES + 1):
		if frame > hold and v < 0.0:
			v = 0.0  # releasing jump cuts the rise outright (states/jump.gd)
		v = minf(v + tuning.gravity_pf, tuning.terminal_velocity_pf)
		y += v
		peak = minf(peak, y)
		if v > 0.0 and y >= -rise:
			# Coming down, and level with the landing. It only counts if the arc
			# ever cleared it.
			return -1.0 if peak > -rise else float(frame) * tuning.walk_speed_pf
	return -1.0


func _release() -> void:
	for action in [&"move_right", &"move_left", &"move_up", &"move_down",
			&"jump", &"shoot"]:
		if Input.is_action_pressed(action):
			Input.action_release(action)
