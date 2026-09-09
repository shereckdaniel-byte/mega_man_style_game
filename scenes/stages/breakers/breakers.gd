## Stage 3, "Breakers" -- the ship-scrapping yard, and Rust's stage.
##
## Nineteen rooms that **climb**. Stage 1 is a W and stage 2 a long J; both end
## roughly where they started. This one starts at the waterline among the beached
## hulls and finishes three screens up on the gantry, and the whole stage is the
## ascent:
##
##   col   0     1     2      3      4      5     6    7     8     9    10   11    12    13   14   15   16
##  band 0                                                     Gantry-Jib-Sprdr-Cradle-Deck-Crane-Gate-Arena
##                                                                ^
##  band 1                                     Hold-Frames-Blkhd-Alley-Ribs
##                                               ^
##  band 2 Waterline-Bilge-Keel-Scupper-Boiler-Slipway
##
## **Six rooms per band, not three-two-four.** The old nine spent barely two
## screens in the hull, which made the middle band a landing rather than a place;
## at six each the three bands are three environments and the two ladders are
## events rather than transitions.
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
##   * **Keel** -- the same press with somewhere else to be: it stands between
##     the door and a gap, so the timing buys progress rather than passage.
##   * **Slipway** -- one press, `CLEARANCE_SLIDE`. It rests two rows off the
##     deck, so at rest you slide under it. Same object, opposite answer.
##   * **Boiler Room** -- both clearances in one room, twenty cells apart. The
##     point Slipway made across a room boundary, made where it costs something.
##   * **Hold** -- two sealed presses out of phase, so the safe windows do not
##     line up and the room is a rhythm rather than a gate.
##   * **Bulkhead** -- three on a rolling phase, which turns the gate into a
##     wave the player walks along.
##   * **Jib**, **Spreader** -- the clearances again out on the gantry, now with
##     no room in the table saying which is which; the player reads it from
##     where the press rests.
##   * **Crane** -- one sealed press on the approach to a crossing, which is the
##     only time a press shares a room with something else that is timed.
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
		"name": "Keel", "col": 2, "band": BAND_WATER,
		# The sealed press again, now with somewhere else to be. Bilge taught it
		# alone in an empty room; here it stands between the door and a gap, so
		# the timing is spent on getting somewhere rather than on getting past.
		"gaps": [[15, 17]], "blocks": [],
		"crushers": [[6, 3, PRESS_ROWS, CLEARANCE_SEALED, 0]],
		"enemies": [
			[WALKER, SKIN_WALKER, &"walk", 12.0, 0.0],
			[FLYER, SKIN_FLYER, &"fly", 20.0, 4.0],
		],
		"pit_spikes": [[15, 3, 2]],
		"checkpoint": 2.0,
	},
	{
		"name": "Scupper", "col": 3, "band": BAND_WATER,
		# No press. Four press rooms in a row would make the stage about one
		# object, and the kit is what keeps a stage from being a gimmick with
		# scenery -- so this is planks over the bilge water, which is the same
		# element stage 1 uses and a different thing to be afraid of.
		"gaps": [[8, 10], [15, 17]], "blocks": [],
		"crumbles": [[8, 0], [9, 0], [15, 0], [16, 0]],
		"enemies": [
			[CRAWLER, SKIN_CRAWLER, &"crawl", 5.0, 0.0],
			[HOPPER, SKIN_HOPPER, &"hop", 12.0, 0.0],
			[TURRET, SKIN_TURRET, &"idle", 22.0, 2.0],
		],
		"pit_spikes": [[8, 3, 2], [15, 3, 2]],
		"checkpoint": 2.0,
	},
	{
		"name": "Boiler Room", "col": 4, "band": BAND_WATER,
		# **Both answers, in one room, for the first time.** A sealed press and a
		# slide press twenty cells apart: the first has to be waited out, the
		# second has to be gone under, and they are the same object at rest at
		# two different heights. Slipway made that point across a room boundary;
		# this makes it inside one, which is where it actually costs something.
		#
		# Out of phase, because two presses in step are one wide press and
		# tests/test_breakers.gd says so.
		"gaps": [], "blocks": [],
		"crushers": [
			[7, 3, PRESS_ROWS, CLEARANCE_SEALED, 0],
			[16, 3, PRESS_ROWS, CLEARANCE_SLIDE, 60],
		],
		"enemies": [
			[WALKER, SKIN_WALKER, &"walk", 12.0, 0.0],
			[CRAWLER, SKIN_CRAWLER, &"crawl", 22.0, 0.0],
		],
		"checkpoint": 2.0,
	},
	{
		"name": "Slipway", "col": 5, "band": BAND_WATER,
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
		"name": "Hold", "col": 5, "band": BAND_HULL,
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
		"name": "Frames", "col": 6, "band": BAND_HULL,
		# Inside the hull now. A press to wait out, then planks to run -- one
		# thing that punishes hurrying followed by one that punishes hesitating,
		# which is the pair the stage has been building toward.
		"gaps": [[14, 16]], "blocks": [],
		"crushers": [[6, 3, PRESS_ROWS, CLEARANCE_SEALED, 0]],
		"crumbles": [[14, 0], [15, 0]],
		"enemies": [
			[CRAWLER, SKIN_CRAWLER, &"crawl", 11.0, 0.0],
			[FLYER, SKIN_FLYER, &"fly", 20.0, 4.0],
		],
		"pit_spikes": [[14, 3, 2]],
		"checkpoint": 2.0,
	},
	{
		"name": "Bulkhead", "col": 7, "band": BAND_HULL,
		# Three sealed presses on a rolling phase, which turns the stage's one
		# timing object into a **rhythm**. Hold made two out of step so the safe
		# windows do not line up; three at 0, 64 and 128 make a wave the player
		# walks along rather than three gates they solve one at a time.
		#
		# Nothing else in the room. A rhythm is the ask.
		"gaps": [], "blocks": [],
		"crushers": [
			[5, 3, PRESS_ROWS, CLEARANCE_SEALED, 0],
			[12, 3, PRESS_ROWS, CLEARANCE_SEALED, 64],
			[19, 3, PRESS_ROWS, CLEARANCE_SEALED, 128],
		],
		"enemies": [
			[CRAWLER, SKIN_CRAWLER, &"crawl", 24.0, 0.0],
		],
		"checkpoint": 2.0,
	},
	{
		"name": "Shaft Alley", "col": 8, "band": BAND_HULL,
		# A breath from the presses, and the room that reminds the stage it is a
		# climb: two platforms up, with the gap taken off flat deck before either
		# of them.
		"gaps": [[7, 9]], "blocks": [],
		"one_ways": [[14, 2, 4], [20, 4, 4]],
		"enemies": [
			[HOPPER, SKIN_HOPPER, &"hop", 4.0, 0.0],
			[SPAWNER, SKIN_SPAWNER, &"idle", 12.0, 4.0],
			[FLYER, SKIN_FLYER, &"fly", 18.0, 6.0],
		],
		"pit_spikes": [[7, 3, 2]],
		"checkpoint": 2.0,
	},
	{
		"name": "Ribs", "col": 9, "band": BAND_HULL,
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
		"name": "Gantry", "col": 9, "band": BAND_GANTRY,
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
		"name": "Jib", "col": 10, "band": BAND_GANTRY,
		# Out on the gantry, and the slide press comes back. Bilge and Slipway
		# taught the two clearances a stage apart from the rooms that use them;
		# up here the player is expected to read which one it is from where it
		# rests, without being told.
		"gaps": [[16, 18]], "blocks": [],
		"crushers": [[5, 3, PRESS_ROWS, CLEARANCE_SLIDE, 0]],
		"enemies": [
			[TURRET, SKIN_TURRET, &"idle", 11.0, 2.0],
			[FLYER, SKIN_FLYER, &"fly", 21.0, 4.0],
		],
		"pit_spikes": [[16, 3, 2]],
		"checkpoint": 2.0,
	},
	{
		"name": "Spreader", "col": 11, "band": BAND_GANTRY,
		# Both clearances *and* a hole between them, which is Boiler Room's room
		# with the floor removed from the middle. The gap is off flat deck and
		# three cells clear of either press, so the timing and the jump are
		# consecutive problems rather than one compound one.
		"gaps": [[11, 13]], "blocks": [],
		"crushers": [
			[5, 3, PRESS_ROWS, CLEARANCE_SEALED, 0],
			[18, 3, PRESS_ROWS, CLEARANCE_SLIDE, 72],
		],
		"enemies": [
			[CRAWLER, SKIN_CRAWLER, &"crawl", 15.0, 0.0],
			[FLYER, SKIN_FLYER, &"fly", 23.0, 5.0],
		],
		"pit_spikes": [[11, 3, 2]],
		"checkpoint": 2.0,
	},
	{
		"name": "Cradle", "col": 12, "band": BAND_GANTRY,
		# No press and no hole: the last flat ground before Crane, which is the
		# only room in the stage that asks for a press and a crossing at once.
		# Every stage gets one of these before its hardest room, and stage 1's is
		# called Rise for the same reason.
		"gaps": [], "blocks": [[6, 2, 3, 2], [13, 2, 4, 2]],
		"enemies": [
			[WALKER, SKIN_WALKER, &"walk", 10.0, 2.0],
			[TURRET, SKIN_TURRET, &"idle", 20.0, 2.0],
			[HOPPER, SKIN_HOPPER, &"hop", 23.0, 0.0],
		],
		"checkpoint": 2.0,
	},
	{
		"name": "Deck Crane", "col": 13, "band": BAND_GANTRY,
		# A press, then two plank runs. Three screens above the waterline the
		# stage is asking for exactly what it asked for in the bilge, which is
		# the point: the ascent changed the view and not the vocabulary.
		# **Cell 9 and phase 40, not cell 6 and phase 0.** At 6 the press stands
		# five cells inside the door on a cycle that starts down, so a player who
		# walks in at the wrong moment walks into it -- and this room's approach
		# is already busy, because the planks past it reward hurrying. The bot
		# lost 22 HP and a life here and nowhere else in the hull or on the
		# gantry.
		#
		# Crane solved the same problem the same way one room later and has had
		# an offset since M6h. A press near a door needs to be up when the door
		# opens; further in, phase 0 is fine because the player arrives already
		# watching it.
		"gaps": [[14, 16], [20, 22]], "blocks": [],
		"crushers": [[9, 3, PRESS_ROWS, CLEARANCE_SEALED, 40]],
		"crumbles": [[14, 0], [15, 0], [20, 0], [21, 0]],
		"enemies": [
			[CRAWLER, SKIN_CRAWLER, &"crawl", 11.0, 0.0],
			[FLYER, SKIN_FLYER, &"fly", 18.0, 5.0],
		],
		"pit_spikes": [[14, 3, 2], [20, 3, 2]],
		"checkpoint": 2.0,
	},
	{
		"name": "Crane", "col": 14, "band": BAND_GANTRY,
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
		"name": "Gate", "col": 15, "band": BAND_GANTRY,
		# Lit and deliberately empty. The run-up to a boss is a breath, and
		# `tests/test_stage_authoring.gd` holds every stage to it: a gap or an
		# enemy in the room before the door turns the walk to a fight into a
		# thing you can arrive at on two health.
		"gaps": [], "blocks": [],
		"enemies": [],
		"checkpoint": 2.0,
	},
	{
		"name": "Arena", "col": 16, "band": BAND_GANTRY,
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


