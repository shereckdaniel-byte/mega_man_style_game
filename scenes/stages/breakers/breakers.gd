## Stage 3, "Breakers" -- the ship-scrapping yard, and Rust's stage.
##
## Nine rooms that **climb**. Stage 1 is a U (down in the middle and up again),
## stage 2 is a J (commit down early, run along the bottom, one climb at the
## end). Both end roughly where they started. This one starts at the waterline
## among the beached hulls and finishes three screens up on the gantry, and the
## whole stage is the ascent:
##
##      col 0       1        2        3        4      5      6
##  band 0                          Gantry - Crane - Gate - Arena
##                                     ^
##  band 1                    Hold - Ribs
##                              ^
##  band 2  Waterline - Bilge - Slipway
##
## Three bands rather than two, which nothing before this used. `AuthoredStage`
## already supported it -- `band_deck_row` is `DECK_ROW + band * ROOM_HEIGHT` and
## has never cared how many there are -- so the shape cost nothing but the table.
##
## ### The gimmick: presses
##
## `CrusherPress` is the first piece of level that is dangerous *sometimes*, and
## the first that can kill on ground the player is standing on rather than ground
## they chose to jump over. Four rooms have one; they are introduced one idea at
## a time, and the idea is always **clearance at rest**:
##
##   * **Bilge** -- one press, `CLEARANCE_SEALED`. It comes down onto the deck,
##     so there is no under; the room is asking you to cross while it is up.
##   * **Slipway** -- one press, `CLEARANCE_SLIDE`. It rests two rows off the
##     deck, so at rest you slide under it. Same object, opposite answer.
##   * **Hold** -- two sealed presses out of phase, so the safe windows do not
##     line up and the room is a rhythm rather than a gate.
##   * **Crane** -- one sealed press on the approach to a crossing, which is the
##     first time a press shares a room with something else that is timed.
##
## ### Why clearance is a named constant and not a number per press
##
## Exactly the argument `SLIDE_CLEARANCE` and `SPIKED_CLEARANCE` settled in
## `AuthoredStage`. A press's teeth reach `CrusherPress.TEETH_TILES` below its
## body, so "one row of clearance" does not mean a sliding player fits -- the
## teeth eat most of that row. The arithmetic is in `CLEARANCE_SLIDE` and
## `tests/test_breakers.gd` checks it against the real hitboxes rather than
## against this comment.
##
## ### What is not different from stages 1 and 2 is deliberate
##
## The vocabulary is still the M5a kit. What changes is that the kit is now being
## asked for underneath something that is trying to flatten you.
extends AuthoredStage

const BACKGROUND := preload("res://scenes/stages/breakers/parallax_background.gd")
const TILESET := preload("res://resources/tilesets/breakers.tres")
const RUST := preload("res://scenes/actors/bosses/rust.gd")
const CRUSHER := preload("res://scenes/level/crusher_press.gd")
## Rust's art. By path rather than preloaded so the stage still opens if the
## sprite frames are mid-regeneration.
const BOSS_FRAMES_PATH := "res://resources/sprite_frames/rust.tres"

const WALKER := preload("res://scenes/actors/enemies/walker.gd")
const HOPPER := preload("res://scenes/actors/enemies/hopper.gd")
const TURRET := preload("res://scenes/actors/enemies/turret.gd")
const FLYER := preload("res://scenes/actors/enemies/flyer.gd")
const SPAWNER := preload("res://scenes/actors/enemies/spawner.gd")
const CRAWLER := preload("res://scenes/actors/enemies/wall_crawler.gd")

## The waterline, the hull's inside, and the gantry over the top of it.
const BAND_WATER := 2
const BAND_HULL := 1
const BAND_GANTRY := 0

## The breakers' six, one per archetype.
##
## Same rule as the substation's (docs/PLAN.md section 4): the behaviour is the
## archetype and the art is the theme, so this is a column of names and the
## behaviour each wears is whatever `scenes/actors/enemies/` already does.
##
## Named off the yard rather than invented: a cutter is the oxy-acetylene rig
## that opens a hull, a jack is the bottle jack that lifts a section off the
## blocks, a rivet gun is what put the plates together in the first place, slag
## is what drips off a cut, a skip is what the pieces go into, and a seam is the
## weld a machine runs along a plate.
const SKIN_WALKER := "cutter"
const SKIN_HOPPER := "jack"
const SKIN_TURRET := "rivetgun"
const SKIN_FLYER := "slag"
const SKIN_SPAWNER := "skip"
const SKIN_CRAWLER := "seam"

## How tall a press is, in rows. Two: one row reads as a lid and three fills the
## screen from a standing player's eye level.
const PRESS_ROWS := 2

## Clearance left under a press **at rest**, in rows. This is the number that
## decides what the room is asking for, so it is named rather than authored.
##
##   sealed   0 rows     the press reaches the deck. There is no under; cross
##                       while it is up, or stand on top of it.
##   slide    1.5 rows   24 NES px of opening, less CrusherPress.TEETH_TILES of
##                       teeth (0.34 rows, 5.4 px) hanging into it, leaves 18.6
##                       px usable. A sliding player is 14 px and has 4.6 px of
##                       margin; a standing one is 24 px and is caught by 5.4.
##
## **The window here is narrower than the spiked tunnel's, and it is not a whole
## number of rows.** 1 row is 16 px of opening less 5.4 of teeth = 10.6, which a
## 14 px slide does not fit through at all; 2 rows is 26.6 px usable, which a
## 24 px *standing* player walks through, so the press stops asking for anything.
## Only 1.5 catches one and passes the other. That is a tighter constraint than
## SPIKED_CLEARANCE had, because a press's teeth are shallower than a ceiling
## spike's 12 px, and it was found by `tests/test_breakers.gd` failing on the
## first version of this comment -- which had the arithmetic wrong in exactly the
## direction that ships a press nobody has to slide under.
const CLEARANCE_SEALED := 0.0
const CLEARANCE_SLIDE := 1.5

## One row per room, in the order the player meets them. The key reference is in
## AuthoredStage's docstring; `crushers` is this stage's own:
##
##   [x, width, height_rows, rest_clearance_rows, phase_frames]
##
## `rest_clearance_rows` is a float: see CLEARANCE_SLIDE.
##
## The press hangs from the room's ceiling and drops until `rest_clearance_rows`
## are left under it. `phase_frames` offsets its cycle so two presses in a room
## can be out of step; the cycle *length* is a fact about `CrusherPress` and is
## deliberately not authorable here.
const ROOMS := [
	{
		"name": "Waterline", "col": 0, "band": BAND_WATER,
		# The room with nothing in it that can kill you, which every stage needs
		# first. Two cutters and the stage's one teaching gap.
		#
		# Column 0 of the bottom band: nothing is underneath it anywhere in the
		# stage, which is the only place a gap can be a pit rather than a hole
		# into a room the player was not sent to. `tests/test_stage_authoring.gd`
		# enforces that across every stage.
		"gaps": [[18, 20]], "blocks": [],
		"enemies": [
			[WALKER, SKIN_WALKER, &"walk", 14.0, 0.0],
			[WALKER, SKIN_WALKER, &"walk", 23.0, 0.0],
		],
		"checkpoint": 2.0,
	},
	{
		"name": "Bilge", "col": 1, "band": BAND_WATER,
		# **The press, taught alone.** Flat deck, no gaps, no spikes, one hopper
		# well clear of it. What is being learned is the cycle -- hold, shudder,
		# slam, rest, grind up -- and learning it over a pit teaches it once.
		#
		# Sealed, because the first press should have the simplest possible
		# answer: it is a door that opens and shuts, and you walk through when it
		# is open.
		"gaps": [], "blocks": [],
		"enemies": [
			[HOPPER, SKIN_HOPPER, &"hop", 21.0, 0.0],
		],
		"checkpoint": 2.0,
		"crushers": [[12, 3, PRESS_ROWS, CLEARANCE_SEALED, 0]],
	},
	{
		"name": "Slipway", "col": 2, "band": BAND_WATER,
		# The second idea: the same object with the opposite answer. This one
		# rests two rows off the deck, so waiting for it to come *down* and
		# sliding under is the fast way through, and standing under it is not.
		#
		# The crawler is on the far side of it, so the room does not ask for the
		# slide and a fight in the same beat.
		"gaps": [], "blocks": [[6, 2, 3, 2]],
		"enemies": [
			[CRAWLER, SKIN_CRAWLER, &"crawl", 20.0, 0.0],
		],
		"checkpoint": 2.0,
		"crushers": [[13, 3, PRESS_ROWS, CLEARANCE_SLIDE, 0]],
		# Up at cell 24, near the far end: the climb is the room's exit, and a
		# shaft in the middle would have the player walk past it to a dead end.
		"shaft_up": [23, 2],
	},
	{
		"name": "Hold", "col": 2, "band": BAND_HULL,
		# Inside the hull, and the first room where the presses are a rhythm
		# rather than a gate: two of them, out of phase by roughly half a cycle,
		# so the gap that opens under one is closing under the other.
		#
		# **No gaps in this room, and that is structural.** Slipway is directly
		# below it, so a hole here would drop the player past its door into a
		# room the stage does not think they are in.
		"gaps": [], "blocks": [[19, 2, 4, 2]],
		"enemies": [
			[TURRET, SKIN_TURRET, &"idle", 25.0, 2.0],
		],
		"checkpoint": 2.0,
		"crushers": [
			[8, 3, PRESS_ROWS, CLEARANCE_SEALED, 0],
			[14, 3, PRESS_ROWS, CLEARANCE_SEALED, 96],
		],
	},
	{
		"name": "Ribs", "col": 3, "band": BAND_HULL,
		# The hull's frames, climbed. No press: after two rooms of them the stage
		# needs a room that is only platforming, or the gimmick stops being an
		# event and becomes the floor.
		#
		# The crumbling plates are optional -- the one-ways above them reach the
		# same ladder more slowly -- which is the same courtesy stage 2's Riser
		# extends to a player who cannot read a rhythm.
		"gaps": [[11, 13]], "blocks": [],
		"enemies": [
			[FLYER, SKIN_FLYER, &"fly", 16.0, 4.0],
		],
		"checkpoint": 2.0,
		"crumbles": [[11, 0], [12, 0]],
		"one_ways": [[10, 3, 5]],
		"pit_spikes": [[11, 3, 2]],
		"shaft_up": [23, 2],
	},
	{
		"name": "Gantry", "col": 3, "band": BAND_GANTRY,
		# Out on top, in the light, and the stage's one spawner room. **No gaps**
		# for the same reason as the Hold: Ribs is directly beneath.
		"gaps": [], "blocks": [[8, 2, 3, 2], [17, 2, 4, 2]],
		"enemies": [
			[SPAWNER, SKIN_SPAWNER, &"idle", 12.0, 4.0],
			[WALKER, SKIN_WALKER, &"walk", 22.0, 0.0],
		],
		"checkpoint": 2.0,
	},
	{
		"name": "Crane", "col": 4, "band": BAND_GANTRY,
		# The last test, and the only room that asks for two timed things: a
		# sealed press on the approach, then the crossing.
		#
		# They are deliberately far apart in x, and further apart than they first
		# were. At cell 9 the press was three cells from the lip, so whoever it
		# held up arrived at the crossing at whatever phase the mover happened to
		# be in and stepped straight off -- the bot did it twice and lost 52 HP
		# in this room. At cell 4 the approach to the lip is eleven cells of
		# clear deck, which is room to wait in. Stage 2 wrote the rule down as
		# "a crossing is not the place to be inventive" and this is the same
		# lesson from the other side: the crossing was fine, its run-up was not.
		#
		# The mover's leg is 150 frames -- stage 2's number, which is stage 1's,
		# rather than a fresh one. At 130 a rider who steps on late is still
		# travelling when it turns.
		"gaps": [[15, 21]], "blocks": [],
		# The jack is on the **far** side of the crossing, not the near one.
		# Waiting at a lip is the room's whole ask, and an enemy that can walk
		# into you while you wait turns a timing decision into a shove: the bot
		# lost a life to exactly that with the jack at cell 7, standing still
		# and doing the right thing.
		"enemies": [
			[HOPPER, SKIN_HOPPER, &"hop", 24.0, 0.0],
		],
		"checkpoint": 2.0,
		"crushers": [[4, 3, PRESS_ROWS, CLEARANCE_SEALED, 40]],
		"movers": [[15, 0, 6.0, 0.0, 150]],
		"pit_spikes": [[15, 3, 6]],
	},
	{
		"name": "Gate", "col": 5, "band": BAND_GANTRY,
		# Lit and deliberately empty. The run-up to a boss is a breath, and
		# `tests/test_stage_authoring.gd` holds every stage to it: a gap or an
		# enemy in the room before the door turns the walk to a fight into a
		# thing you can arrive at on two health.
		"gaps": [], "blocks": [],
		"enemies": [],
		"checkpoint": 2.0,
	},
	{
		"name": "Arena", "col": 6, "band": BAND_GANTRY,
		# Flat, empty and no checkpoint. No press either: Rust's Bloom takes
		# floor away on its own, and a fight that also had a press in it would be
		# asking the player to solve two space problems whose answers conflict.
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
	return RUST


func boss_frames_path() -> String:
	return BOSS_FRAMES_PATH


func boss_name() -> String:
	return "Rust"


## The presses. This stage's own key, placed here for the same reason stage 1's
## tide is: the shared kit should not grow a slot for every stage's one idea.
func place_stage_elements(spec: Dictionary, _index: int, origin: int, deck: int,
		tile: float) -> void:
	for entry in spec.get("crushers", []):
		var press := CRUSHER.new() as CrusherPress
		press.name = "Crusher_%d_%d" % [origin + int(entry[0]), deck]
		press.size_tiles = Vector2(float(entry[1]), float(entry[2]))
		press.drop_tiles = press_drop_rows(float(entry[2]), float(entry[3]))
		press.phase_frames = int(entry[4])
		# The rails run on down to the deck even where the press stops short of
		# it -- see CrusherPress.track_extra_tiles.
		press.track_extra_tiles = float(entry[3])
		# Hung from the room's ceiling, which is where a press in a ship is: the
		# rails are drawn up to it, so a press placed anywhere else would have
		# them ending in mid-air.
		press.position = Vector2(float(origin + int(entry[0])),
			float(deck - ceiling_to_deck_rows())) * tile
		add_child(press)


## How far a press travels, from the room ceiling to `clearance` rows above the
## deck. Exposed rather than inlined so `tests/test_breakers.gd` can check the
## arithmetic against the real geometry instead of restating it.
func press_drop_rows(height_rows: float, clearance_rows: float) -> float:
	return float(ceiling_to_deck_rows()) - height_rows - clearance_rows


## Rows of open air between a room's ceiling and its deck. A room is exactly one
## screen tall by AuthoredStage's construction, so this is that height and not a
## number of this stage's own -- derived rather than restated, because a press
## hung from a ceiling that had moved would hang in mid-air.
func ceiling_to_deck_rows() -> int:
	return DECK_ROW - ROOM_TOP
