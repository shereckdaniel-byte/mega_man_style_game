## Stage 4, "Mirror Field" -- the solar array, and Prism's stage.
##
## Nine rooms in an **L**. Stage 1 is a U, stage 2 a J, stage 3 a staircase that
## climbs all the way; this one runs flat across the field for five rooms and
## then turns straight up into the receiver tower and stays there.
##
##      col 0       1        2        3       4        5       6      7
##  band 0                                 Landing - Focus - Gate - Arena
##                                            ^
##  band 1  Array - Pylons - Trough -  Salt - Foot
##
## ### The flatness is the design, not a shortcut
##
## Stages 1-3 all take their variety from the shape of the terrain: a descent
## under a boardwalk, a trench, an ascent through a hull. A heliostat field is
## flat by construction -- it is a plain of mirrors on a salt pan -- and this
## stage leans on that rather than fighting it. **There is almost no authored
## vertical terrain here, because the panels are the vertical terrain.** That is
## what stops stage 4 being stage 3 in paler tiles: the gimmick is not seasoning
## on top of a landscape, it *is* the landscape.
##
## ### The gimmick: panels
##
## `PhaseBlock` carries the grammar and its docstring is where it is written
## down. What belongs here is the order the five rooms teach it in, which is
## Breakers' method -- one idea at a time, and the idea is always about **what a
## miss costs**:
##
##   * **Pylons** -- the panel alone, over solid deck, and *optional*: the arc
##     between the two mirror banks is the quick way, and walking round is the
##     slow one. A miss costs a walk. This is where the beat is learned.
##   * **Trough** -- the same three panels, now flush across a gap with spikes in
##     it. Same object, and now a miss costs a life.
##   * **Salt** -- five panels, and the room where the rule bites: two are up at
##     a time, so the one behind you is already gone. **You cannot stop.**
##   * **Foot** -- no panels at all. After two panel rooms the stage needs a room
##     that is only platforming, or the gimmick stops being an event and becomes
##     the floor. Same argument Ribs makes in Breakers.
##   * **Focus** -- the exam: two paths half a beat out of step, over two gaps,
##     with three cells of deck between them to re-read the rhythm on.
##
## ### Two things this stage deliberately does not contain
##
## **No crumbling blocks.** They are the other piece of timed geometry in the kit
## and they look like a platform that gives way -- which is what a panel is,
## under a different rule. The one stage whose whole gimmick is timed platforms
## is the one stage that must not also contain the other kind, or the player
## cannot tell from looking which rule governs which block.
##
## **No moving platforms.** A mover is the kit's answer to "this gap is wider
## than the jump", and so is a panel path. Putting both in one stage offers two
## answers to the same question and makes neither mean anything. The crossings
## here are all panels, which is what makes them the stage.
extends AuthoredStage

const BACKGROUND := preload("res://scenes/stages/mirror_field/parallax_background.gd")
## TODO(art): swap to res://resources/tilesets/mirror_field.tres once generated.
## Greyboxed against stage 3's tiles so the layout and the pacing can be driven
## by the bot before any generation is paid for -- PLAN.md's own rule, layout
## first and art second.
const TILESET := preload("res://resources/tilesets/breakers.tres")
const PRISM := preload("res://scenes/actors/bosses/prism.gd")
const PANEL := preload("res://scenes/level/phase_block.gd")
## Prism's art. By path rather than preloaded so the stage still opens if the
## sprite frames are mid-regeneration.
const BOSS_FRAMES_PATH := "res://resources/sprite_frames/prism.tres"

const WALKER := preload("res://scenes/actors/enemies/walker.gd")
const HOPPER := preload("res://scenes/actors/enemies/hopper.gd")
const TURRET := preload("res://scenes/actors/enemies/turret.gd")
const FLYER := preload("res://scenes/actors/enemies/flyer.gd")
const SPAWNER := preload("res://scenes/actors/enemies/spawner.gd")
const CRAWLER := preload("res://scenes/actors/enemies/wall_crawler.gd")

## The field on its salt pan, and the receiver tower over the top of it.
const BAND_FIELD := 1
const BAND_TOWER := 0

## The field's six, one per archetype.
##
## Same rule as every stage since the substation's (docs/PLAN.md section 4): the
## behaviour is the archetype and the art is the theme, so this is a column of
## names and the behaviour each wears is whatever `scenes/actors/enemies/`
## already does.
##
## Named off the plant rather than invented: a tracker is the drive that turns a
## heliostat to follow the sun, a ballast is the concrete foot it stands on, a
## Fresnel is a lens, a glint is what you see off a mirror from a mile away, a
## rack is what panels are shipped and stored in, and a wiper is the robot that
## crawls across a panel's face to clean it.
const SKIN_WALKER := "tracker"
const SKIN_HOPPER := "ballast"
const SKIN_TURRET := "fresnel"
const SKIN_FLYER := "glint"
const SKIN_SPAWNER := "rack"
const SKIN_CRAWLER := "wiper"

## Half a beat, for a set that runs out of step with its neighbour.
##
## **Derived from `PhaseBlock`, not written as a number.** A room is allowed to
## offset a set's phase and nothing else (see `PhaseBlock`'s docstring); writing
## `26` here would be a timing invented at the placement, which is the mistake
## `CrusherPress` exists to prevent. Half a beat is the smallest offset that
## makes an arrival land off the rhythm -- a whole beat just runs the second
## path one step behind the first, which the player never notices.
const HALF_BEAT := PANEL.BEAT_FRAMES / 2

## One row per room, in the order the player meets them. The key reference is in
## AuthoredStage's docstring; `mirrors` is this stage's own:
##
##   {"path": [[x, rows_above_deck], ...], "phase": frames}
##
## **The list order is the beat order**, which is what makes a set coherent by
## construction -- there is nowhere to write "beat 2 is empty" or "two panels on
## beat 3", because the beats *are* the indices. The cycle length follows from
## the path's size and is not authorable; `phase` is the one timing number a room
## may supply, exactly as `phase_frames` is for a press.
const ROOMS := [
	{
		"name": "Array", "col": 0, "band": BAND_FIELD,
		# The room with nothing in it that can kill you, which every stage owes
		# the player first. Two trackers walking their rails, and the stage's one
		# teaching gap.
		#
		# The gap is in column 0 because column 0 has nothing under it -- which
		# here is true of the whole of band 1, since it is the deepest band in
		# every column it occupies. It stays in room 1 anyway, because a teaching
		# gap belongs in the room that is teaching.
		"gaps": [[18, 20]], "blocks": [],
		"enemies": [
			[WALKER, SKIN_WALKER, &"walk", 14.0, 0.0],
			[WALKER, SKIN_WALKER, &"walk", 23.0, 0.0],
		],
		"checkpoint": 2.0,
	},
	{
		"name": "Pylons", "col": 1, "band": BAND_FIELD,
		# **The panel, taught alone and taught free.** Two mirror banks with an
		# arc of three panels between their tops. The banks are two rows high, so
		# a player who ignores the panels entirely climbs one, drops to the deck,
		# walks, and climbs the other -- slower, and it works.
		#
		# Optional on first appearance is the house pattern rather than a
		# softening: stage 2's Riser and stage 3's Ribs both introduce the
		# crumbling planks with the one-ways above them as the slow way to the
		# same place. A panel is an *offer*, where a press is a threat, and an
		# offer is learned by taking it and finding out what happens.
		#
		# The ballast is back at cell 6, before the banks. An enemy that can
		# shove you mid-arc turns a timing decision into an accident, which is
		# the lesson Crane cost 52 HP to learn.
		"gaps": [], "blocks": [[9, 2, 4, 2], [19, 2, 4, 2]],
		"enemies": [
			[HOPPER, SKIN_HOPPER, &"hop", 6.0, 0.0],
		],
		"checkpoint": 2.0,
		"mirrors": [
			{"path": [[13, 4], [15, 6], [17, 4]], "phase": 0},
		],
	},
	{
		"name": "Trough", "col": 2, "band": BAND_FIELD,
		# The wash trough between two mirror rows, and the second idea: the same
		# three panels, and now they are the only floor there is.
		#
		# **Flush with the deck, not raised.** The first paid crossing should ask
		# for the timing and nothing else -- a path that also climbs asks two
		# questions at once, and the answer to the second one is not the thing
		# being taught.
		#
		# The wiper is on the far side. Sliding, jumping and fighting are three
		# things and a crossing is already one of them.
		"gaps": [[10, 16]], "blocks": [],
		"enemies": [
			[CRAWLER, SKIN_CRAWLER, &"crawl", 22.0, 0.0],
		],
		"checkpoint": 2.0,
		"pit_spikes": [[10, 3, 6]],
		"mirrors": [
			{"path": [[10, 0], [12, 0], [14, 0]], "phase": 0},
		],
	},
	{
		"name": "Salt", "col": 3, "band": BAND_FIELD,
		# The evaporation pan, and the room where the rule bites. Five panels
		# across ten cells: two are solid at any moment, so the one behind you has
		# already gone by the time you land. **You cannot stop, and you cannot go
		# back.**
		#
		# A shallow arc rather than a flat run, because five identical hops read
		# as one obstacle repeated and an arc reads as a route.
		"gaps": [[9, 19]], "blocks": [],
		"enemies": [
			[FLYER, SKIN_FLYER, &"fly", 24.0, 4.0],
		],
		"checkpoint": 2.0,
		"pit_spikes": [[9, 3, 10]],
		"mirrors": [
			{"path": [[9, 0], [11, 1], [13, 2], [15, 1], [17, 0]], "phase": 0},
		],
	},
	{
		"name": "Foot", "col": 4, "band": BAND_FIELD,
		# The tower's foot, and the stage's breath. No panels: after Trough and
		# Salt the stage needs a room that is only platforming, or the gimmick
		# stops being an event and becomes the floor. Ribs makes the same
		# argument in Breakers and for the same reason.
		#
		# **No gaps, and that is structural.** Landing is directly above this
		# column, so a hole here would drop the player past its door into a room
		# the stage does not think they are in.
		"gaps": [], "blocks": [[6, 2, 3, 2], [17, 2, 4, 2]],
		"enemies": [
			[WALKER, SKIN_WALKER, &"walk", 13.0, 0.0],
			[SPAWNER, SKIN_SPAWNER, &"idle", 20.0, 2.0],
		],
		"checkpoint": 2.0,
		"one_ways": [[11, 4, 4]],
		# Up at cell 23, near the far end: the climb is the room's exit, and a
		# shaft in the middle would have the player walk past it to a dead end.
		# Three cells of deck past the hole is SHAFT_LANDING_CELLS exactly.
		"shaft_up": [23, 2],
	},
	{
		"name": "Landing", "col": 4, "band": BAND_TOWER,
		# **Deliberately almost nothing, and that is the whole design of it.**
		#
		# Two rooms stacked in a column share their x range, so a `shaft_up` at
		# cell N leaves the room above only `ROOM_WIDTH - N` cells: the player
		# climbs out and is already at its door. The playthrough bot crosses this
		# one in about a second, and no arrangement of the ladder avoids it --
		# whichever end it goes, one of the two rooms is short.
		#
		# So the short room is the one with nothing in it. Stages 1 and 2 get
		# this right by luck, because the room above their ladder is the empty
		# run-up to the boss. **Breakers gets it wrong twice**: its Hold has two
		# presses out of phase in it -- the third of that stage's four press
		# ideas -- and its Gantry has the stage's only spawner, and the bot
		# crosses both in 1.3 seconds having entered them a cell and a half from
		# their exit. Both rooms are authored, tested, and never seen.
		#
		# An earlier draft of this stage put the ladder at cell 8 instead, to
		# make the upper room the long one. That works for the length and fails
		# for a different reason: the upper room cannot have gaps (Foot is below
		# it), a room with no gaps has a walkable floor from end to end, and no
		# authored terrain can block it -- `MAX_STEP_TILES` guarantees every
		# block is climbable. So its panels were an arc over a floor the bot
		# simply walked along. **A panel path is only ever the way through if
		# there is a hole under it**, which means the rooms that carry paths must
		# be the ones with nothing below them.
		#
		# What is here is a checkpoint, placed where the player actually arrives
		# rather than at cell 2 -- respawning at the far end of a room you enter
		# three cells from its exit is twenty-three cells of walking back.
		"gaps": [], "blocks": [],
		"enemies": [],
		"checkpoint": 26.0,
	},
	{
		"name": "Focus", "col": 5, "band": BAND_TOWER,
		# The receiver's focal point, and the exam: **two paths, half a beat out
		# of step**, with three cells of deck between them to re-read the rhythm
		# on. Nothing here is a new rule -- that is what makes it the last room.
		# A stage's hardest room should ask for everything it taught rather than
		# introduce a seventh thing.
		#
		# **Two crossings rather than one interleaved one**, and that is the
		# grammar rather than a preference. A set has to be crossable on its own
		# -- consecutive panels within a jump of each other, which
		# `test_stage_authoring.gd` holds every stage to -- so two sets woven
		# through one gap would have to space each set's own panels four cells
		# apart and neither would be crossable alone. Two gaps, two sets, two
		# rhythms.
		#
		# Column 5 carries nothing beneath it, which is what lets this room have
		# holes at all. See Landing.
		"gaps": [[6, 14], [17, 25]], "blocks": [],
		"enemies": [
			[CRAWLER, SKIN_CRAWLER, &"crawl", 26.0, 0.0],
		],
		"checkpoint": 2.0,
		"pit_spikes": [[6, 3, 8], [17, 3, 8]],
		"mirrors": [
			{"path": [[6, 0], [8, 1], [10, 1], [12, 0]], "phase": 0},
			{"path": [[17, 0], [19, 1], [21, 1], [23, 0]], "phase": HALF_BEAT},
		],
	},
	{
		"name": "Gate", "col": 6, "band": BAND_TOWER,
		# Deliberately empty. The run-up to a boss is a breath, and
		# `tests/test_stage_authoring.gd` holds every stage to it: a gap or an
		# enemy in the room before the door turns the walk to a fight into a
		# thing you can arrive at on two health.
		"gaps": [], "blocks": [],
		"enemies": [],
		"checkpoint": 2.0,
	},
	{
		"name": "Arena", "col": 7, "band": BAND_TOWER,
		# Flat, empty and no checkpoint. **No panels either**, and for the reason
		# Breakers keeps the press out of Rust's arena: Prism's Sweep already
		# takes the floor away for a while, and a fight that also asked the
		# player to stand on geometry that leaves would be two space problems
		# whose answers conflict.
		"gaps": [], "blocks": [],
		"enemies": [],
		"checkpoint": NO_CHECKPOINT,
	},
]


func room_table() -> Array:
	return ROOMS


func stage_tile_set() -> TileSet:
	return TILESET


func backdrop_script() -> GDScript:
	return BACKGROUND


func boss_script() -> GDScript:
	return PRISM


func boss_frames_path() -> String:
	return BOSS_FRAMES_PATH


func boss_name() -> String:
	return "Prism"


## The panels. This stage's own key, placed here for the same reason stage 1's
## tide and stage 3's presses are: the shared kit should not grow a slot for
## every stage's one idea.
##
## **A block is told its index and its path's length, and nothing else about
## time.** Everything that decides when it is solid follows from those two and
## from `PhaseBlock`'s constants, so a room cannot author a set that leaves a
## beat empty or puts two panels on one -- the beats are the list's indices.
func place_stage_elements(spec: Dictionary, _index: int, origin: int, deck: int,
		tile: float) -> void:
	# **On the deck's surface, not on its tile row.** A panel is a piece of
	# walkway -- the player stands on it -- and the two are half a tile apart on a
	# corner tileset. M6j found this the expensive way: every kit element placed
	# at a deck row floated, which is what made the crumbling blocks look dropped
	# into a room rather than cut out of it. The panels were authored against the
	# tile row before that landed and would have floated in exactly the same way.
	# See `AuthoredStage.deck_surface_offset` and the rule in `_add_elements`.
	var surface := float(deck) + deck_surface_offset()
	for set_index in (spec.get("mirrors", []) as Array).size():
		var entry: Dictionary = spec["mirrors"][set_index]
		var path: Array = entry["path"]
		for beat in path.size():
			var at: Array = path[beat]
			var panel := PANEL.new() as PhaseBlock
			panel.name = "Panel_%d_%d" % [origin + int(at[0]), deck - int(at[1])]
			panel.size_tiles = Vector2(1.0, 1.0)
			panel.beat_index = beat
			panel.path_length = path.size()
			panel.phase_frames = int(entry.get("phase", 0))
			panel.position = Vector2(float(origin + int(at[0])),
				surface - float(at[1])) * tile
			add_child(panel)


## Every panel in the stage, in placement order. For the playtest tools and for
## `tests/test_mirror_field.gd`, which checks the built nodes rather than only
## the table -- the shaft bug at M6i was a table that was right and a translation
## that was not.
func panels() -> Array[PhaseBlock]:
	var out: Array[PhaseBlock] = []
	for child in get_children():
		if child is PhaseBlock:
			out.append(child as PhaseBlock)
	return out
