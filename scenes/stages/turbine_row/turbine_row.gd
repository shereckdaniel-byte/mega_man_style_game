## Stage 5, "Turbine Row" -- the offshore wind farm, and Gale's stage.
##
## Nineteen rooms in a **V**. Stage 1 is a W, stage 2 a long J, stage 3 a
## staircase that only climbs, stage 4 fourteen flat rooms and one turn. This
## one goes **down** first and then climbs twice: out along the causeway, down
## to the sea deck for the long middle, back up to the causeway, and up again
## into the nacelle for the fight.
##
##   col   0     1     2     3     4     5    6     7     8    9     10    11    12    13    14   15
##  band 0                                                                       Hub-Nacell-Gate-Arena
##                                                                                ^
##  band 1 Landfl-Mast-Anemo-Splice-Pier                              Return-Gantry-Foot
##                                 |                                    ^
##  band 2                        Ponton-Slip-Backdr-Bilge-Cross-Kite-Sump
##
## **A descent that has to be climbed back out of is the shape the wind wants.**
## Every other stage's vertical movement is one-way, so its gimmick meets the
## player on a floor that only ever goes one direction. Wind is a horizontal
## force, and the interesting question about a horizontal force is what it does
## to a jump you have to make anyway -- which means the stage needs the same kind
## of jump at three different heights over the sea, and needs the player to come
## back through the middle of it.
##
## ### The gimmick: wind
##
## `WindZone` carries the grammar and its docstring is where the three fairness
## rules are written down. What belongs here is the order the rooms teach it in:
##
##   * **Mast Row** -- a zone over solid deck, with nothing to fall into. The
##     player walks through it and *nothing happens*, which is rule one arriving
##     as an experience rather than as a number: the wind cannot touch a walking
##     player. Then they jump, and it can.
##   * **Anemometer** -- the same zone, blowing against travel, over a two-cell
##     gap. The first paid crossing, and the cheapest possible one: a two-cell
##     gap is inside a standing jump, so a gust costs a stumble and not a life.
##   * **Slipstream** -- the wind with you, over a wide crossing on movers. The
##     first time it is a **tool**: the gust makes the platform hop easy.
##   * **Backdraft** -- Slipstream's geometry with the wind reversed. The pair is
##     the lesson: the same room is two rooms depending on a thing you do not
##     control, and the answer to the hard one is to leave during the lull.
##   * **Crosscut** -- two zones blowing at each other, half a cycle apart, with
##     the seam between them over the gap. The exam.
##   * **Kite** -- the last crossing, downwind, long. Slipstream said the gust
##     helps; this says it enough that the player has to *wait for it* rather
##     than notice it.
##
## Ten of the nineteen rooms carry no wind at all -- Landfall, Splice, Pontoon,
## Bilge, Sump, Return, Hub, Nacelle, Gate and Arena -- for the reason stage 4's
## Foot gives: a stage whose every room is the gimmick has no gimmick, only
## weather. `tests/test_turbine_row.gd` holds the stage to at most three gusting
## rooms in a row, and it caught the fourth on the first run.
##
## ### The rule the whole stage is built on: no gap needs the wind
##
## **Every crossing in this stage is makeable in a dead calm.** The wind is
## weaker than a walk and its lull outlasts a full jump (`WindZone`'s own
## fairness rules), so it *cannot* be load-bearing -- and a stage that leaned on
## it anyway would be a stage with jumps that are sometimes impossible, which is
## the worst failure a platformer has. So the gust never opens a route; it only
## changes what a route costs. `tests/test_turbine_row.gd` checks the arithmetic
## rather than trusting this paragraph.
##
## ### Two things this stage deliberately does not contain
##
## **No phase blocks.** Stage 4's whole gimmick is geometry that comes and goes
## on a timer, and so is a gust -- one takes the floor away and one takes your
## footing away. Putting both in a room asks the player to time two invisible
## clocks against each other, and neither would read.
##
## **No crushers.** Stage 3's press is a thing that takes a column of space away
## on a cycle. A wind zone is a thing that takes control of a column of space on
## a cycle. Same sentence, and a room with both is a room where the player cannot
## tell which cycle the tell belongs to.
extends AuthoredStage

const BACKGROUND := preload("res://scenes/stages/turbine_row/parallax_background.gd")
## TODO(art): swap to res://resources/tilesets/turbine_row.tres once generated.
## Greyboxed against stage 3's tiles so the layout and the pacing can be driven
## by the bot before any generation is paid for -- PLAN.md's own rule, layout
## first and art second. Stage 4 was built the same way.
const TILESET := preload("res://resources/tilesets/breakers.tres")
const GALE := preload("res://scenes/actors/bosses/gale.gd")
const WIND := preload("res://scenes/level/wind_zone.gd")
## Gale's art. By path rather than preloaded so the stage still opens if the
## sprite frames are mid-regeneration.
const BOSS_FRAMES_PATH := "res://resources/sprite_frames/gale.tres"

const WALKER := preload("res://scenes/actors/enemies/walker.gd")
const HOPPER := preload("res://scenes/actors/enemies/hopper.gd")
const TURRET := preload("res://scenes/actors/enemies/turret.gd")
const FLYER := preload("res://scenes/actors/enemies/flyer.gd")
const SPAWNER := preload("res://scenes/actors/enemies/spawner.gd")
const CRAWLER := preload("res://scenes/actors/enemies/wall_crawler.gd")

## The three bands: the nacelle at the top of the climb, the causeway out from
## shore, and the sea deck under it.
const BAND_NACELLE := 0
const BAND_CAUSEWAY := 1
const BAND_SEA := 2

## The farm's six, one per archetype.
##
## **TODO(art): these are stage 3's skins, not stage 5's.** The behaviour is the
## archetype and the art is the theme (docs/PLAN.md section 4), so a stage can be
## laid out and driven by the bot in somebody else's costumes -- and
## `tests/test_stage_authoring.gd` requires every named enemy to have art on
## disk, which means a stage cannot be greyboxed with names that do not exist
## yet. Borrowing a shipped set is the only honest way to author the rooms
## first.
##
## The six this stage wants, when they are generated: **Yaw** (the drive that
## turns a nacelle into the wind), **Guy** (a stay-cable anchor that hops the
## pontoons), **Anemo** (the cup anemometer on the mast head, which pivots and
## fires), **Kite** (a survey drone riding the updraft), **Hub** (the blade root
## that opens and releases inspection crawlers), and **Vane** (the crawler that
## walks a blade's leading edge).
const SKIN_WALKER := "cutter"
const SKIN_HOPPER := "jack"
const SKIN_TURRET := "rivetgun"
const SKIN_FLYER := "slag"
const SKIN_SPAWNER := "skip"
const SKIN_CRAWLER := "seam"

## Half a cycle, for a zone that runs out of step with its neighbour.
##
## **Derived from `WindZone`, not written as a number** -- the same rule stage
## 4's `HALF_BEAT` and stage 3's presses are held to. A room may offset a zone's
## phase and nothing else; writing `105` here would be a timing invented at the
## placement, and it would stop meaning "half a cycle" the moment the cycle was
## retuned.
const HALF_CYCLE := (WIND.DEFAULT_LULL_FRAMES + WIND.DEFAULT_TELL_FRAMES \
	+ WIND.DEFAULT_GUST_FRAMES) / 2

## Blowing with the player, and against them. Named because `-1` in a table is
## a direction nobody can read, and the whole design of six rooms turns on which
## one they are.
const DOWNWIND := 1
const UPWIND := -1


## One row per room, in the order the player meets them. The key reference is in
## AuthoredStage's docstring; `wind` is this stage's own:
##
##   {"dir": DOWNWIND|UPWIND, "from": cell, "to": cell, "phase": frames}
##
## `from`/`to` bound the zone in cells and default to the whole room. `phase` is
## the one timing number a room may supply -- everything else about the cycle
## comes from `WindZone`, so a room cannot author a gust that is longer than the
## lull or a lull a jump outlasts.
const ROOMS := [
	{
		"name": "Landfall", "col": 0, "band": BAND_CAUSEWAY,
		# The room with nothing in it that can kill you, which every stage owes
		# the player first -- and **no wind**, so the first thing the stage
		# teaches is its own controls in still air.
		"gaps": [[18, 20]], "blocks": [],
		"enemies": [
			[WALKER, SKIN_WALKER, &"walk", 13.0, 0.0],
			[WALKER, SKIN_WALKER, &"walk", 23.0, 0.0],
		],
		"checkpoint": 2.0,
	},
	{
		"name": "Mast Row", "col": 1, "band": BAND_CAUSEWAY,
		# **The wind, taught alone and taught free.** A zone across the whole
		# room, over solid deck, with nothing to fall into.
		#
		# A player who walks it feels nothing at all, which is the first fairness
		# rule arriving as an experience rather than as a constant: the wind
		# never touches a walking player. Then they jump the two-tile step at
		# cell 14 during a gust and get carried, and the rule has taught its own
		# exception. Free on first appearance is the house pattern -- stage 2's
		# Riser, stage 3's Ribs, stage 4's Pylons.
		"gaps": [], "blocks": [[14, 2, 4, 2]],
		"enemies": [
			[HOPPER, SKIN_HOPPER, &"hop", 6.0, 0.0],
		],
		"checkpoint": 2.0,
		"wind": [{"dir": DOWNWIND, "phase": 0}],
	},
	{
		"name": "Anemometer", "col": 2, "band": BAND_CAUSEWAY,
		# The first paid crossing, and the cheapest one available: a two-cell gap
		# is inside a flat-footed jump, so a gust costs a stumble rather than a
		# life. Blowing **against** travel, which is the harder of the two and is
		# survivable here precisely because the gap is short.
		#
		# No pit spikes. The room's job is to say "the wind moves you mid-air",
		# and a first lesson whose failure state is death is a first lesson
		# nobody experiments in.
		"gaps": [[12, 14]], "blocks": [],
		"enemies": [
			[TURRET, SKIN_TURRET, &"idle", 22.0, 2.0],
		],
		"checkpoint": 2.0,
		"wind": [{"dir": UPWIND, "phase": 0}],
	},
	{
		"name": "Splice", "col": 3, "band": BAND_CAUSEWAY,
		# No wind. Two gimmick rooms have just run back to back and the stage's
		# own rule -- stage 4 writes it on Foot -- is that a room of plain
		# platforming has to come between, or the gusts stop being an event and
		# become the weather.
		"gaps": [[7, 9], [17, 19]], "blocks": [[22, 2, 4, 2]],
		"enemies": [
			[FLYER, SKIN_FLYER, &"fly", 13.0, 4.0],
			[CRAWLER, SKIN_CRAWLER, &"crawl", 25.0, 0.0],
		],
		"pit_spikes": [[7, 3, 2], [17, 3, 2]],
		"checkpoint": 2.0,
	},
	{
		"name": "Pier Head", "col": 4, "band": BAND_CAUSEWAY,
		# The end of the causeway and the way down. **No gaps**: the sea deck is
		# under this column, and a hole here would open into the room below
		# (`tests/test_stage_authoring.gd` holds every stage to that).
		#
		# The zone is on the near half only, so the ladder is in still air. A
		# player being pushed while they reach for a ladder is a player who
		# misses it, and there is no version of that which reads as anything but
		# a bug.
		"gaps": [], "blocks": [[8, 2, 3, 2]],
		"enemies": [
			[WALKER, SKIN_WALKER, &"walk", 5.0, 0.0],
			[HOPPER, SKIN_HOPPER, &"hop", 15.0, 0.0],
		],
		"checkpoint": 2.0,
		"wind": [{"dir": DOWNWIND, "from": 0, "to": 18, "phase": 0}],
		"shaft": [22, 2],
	},
	{
		"name": "Pontoon", "col": 4, "band": BAND_SEA,
		# Arrival at sea level, and **still air**. The player has just changed
		# bands, the backdrop has changed with them, and a room that also blew
		# would be a room they read none of.
		#
		# It was authored downwind and the stage's own breath rule caught it:
		# Pier Head, here, Slipstream and Backdraft is four gusting rooms in a
		# row, and `tests/test_turbine_row.gd` allows three. Calming this one is
		# the right fix rather than a concession -- it is the room that had the
		# least to say with the wind on, and the descent now has a landing.
		#
		# One two-cell gap with the water under it, and nothing else.
		"gaps": [[16, 18]], "blocks": [],
		"enemies": [
			[WALKER, SKIN_WALKER, &"walk", 8.0, 0.0],
			[FLYER, SKIN_FLYER, &"fly", 22.0, 5.0],
		],
		"checkpoint": 2.0,
	},
	{
		"name": "Slipstream", "col": 5, "band": BAND_SEA,
		# **The first room where the wind is a tool.** A six-cell gap on a single
		# mover, with the gust behind the player.
		#
		# The crossing is a plain platform hop and works in dead calm -- that is
		# the stage's rule and it is not bent here. What the gust does is make
		# the *return* leg free: a player who mistimes the mover and lands short
		# on the near lip is blown back onto it. The wind helping is a thing this
		# room exists to establish, because the next room takes it away.
		"gaps": [[10, 16]], "blocks": [],
		"movers": [[10, 0, 6, 0, 90]],
		"enemies": [
			[TURRET, SKIN_TURRET, &"idle", 24.0, 2.0],
		],
		"pit_spikes": [[10, 3, 6]],
		"checkpoint": 2.0,
		"wind": [{"dir": DOWNWIND, "phase": 0}],
	},
	{
		"name": "Backdraft", "col": 6, "band": BAND_SEA,
		# **Slipstream's geometry with the wind reversed**, and the pair is the
		# lesson: the same room is two rooms depending on which way the air is
		# going, and the answer to the hard one is to leave during the lull
		# rather than to jump harder.
		#
		# Same gap, same mover, same period. Nothing else changes, deliberately
		# -- a second variable would make the comparison say nothing.
		"gaps": [[10, 16]], "blocks": [],
		"movers": [[10, 0, 6, 0, 90]],
		"enemies": [
			[FLYER, SKIN_FLYER, &"fly", 21.0, 5.0],
		],
		"pit_spikes": [[10, 3, 6]],
		"checkpoint": 2.0,
		"wind": [{"dir": UPWIND, "phase": 0}],
	},
	{
		"name": "Bilge", "col": 7, "band": BAND_SEA,
		# No wind, and the stage's one required slide. The second breath, placed
		# where stage 4 places Brine: after the pair, before the exam.
		#
		# The tunnel is two cells and hung with teeth, which is the wider kind of
		# tunnel -- see `AuthoredStage.SPIKED_CLEARANCE`. A one-row tunnel with
		# spikes in it is a tunnel nothing fits through, which stage 1 shipped
		# and stage 2's bot died in.
		"gaps": [[6, 8]], "blocks": [[21, 2, 4, 2]],
		"ceilings": [[14, SPIKED_CLEARANCE, 2, 3]],
		"ceiling_spikes": [[14, SPIKED_CLEARANCE, 2]],
		"enemies": [
			[HOPPER, SKIN_HOPPER, &"hop", 10.0, 0.0],
			[CRAWLER, SKIN_CRAWLER, &"crawl", 19.0, 0.0],
		],
		"pit_spikes": [[6, 3, 2]],
		"checkpoint": 2.0,
	},
	{
		"name": "Crosscut", "col": 8, "band": BAND_SEA,
		# **The exam: two zones blowing at each other, half a cycle apart.**
		#
		# The player cannot answer it by picking a direction; they have to notice
		# that the two halves are never gusting at once, which is what
		# `HALF_CYCLE` guarantees and what makes the room solvable at all.
		#
		# **The seam sits on solid ground at cell 11, not over the gap**, and it
		# used to sit over it -- a jump that left in a tailwind and landed in a
		# headwind. That was survivable while the wind only applied in the air,
		# and it stopped being survivable the moment the push reached a walking
		# player: the run-up is now in one wind and the flight is in two, over a
		# two-cell hole with spikes in it. The bot died six times and never once
		# reached the far lip.
		#
		# It is the third time this stage has taught the same lesson -- Kite's
		# relay and Gantry's hole were the other two: **a lethal gap under a
		# cyclic force is a crossing whose difficulty depends on when you arrive
		# at it.** The seam on solid ground keeps the room's whole idea (two
		# halves, never gusting together, and you have to read which) and makes
		# the jump happen in one wind. Walking through the seam and feeling the
		# direction flip is also a better tell than crossing it mid-air, where
		# the player has no way to attribute what just happened.
		#
		# Two cells wide, like Anemometer. This room is about reading, not about
		# reach, and a long gap would have made it about both.
		# **The gap is in the downwind half**, and that is the rule the stage now
		# runs on: a headwind may drag a walk, it may not blow across a hole. It
		# was at cell 13, inside the upwind half, and the bot died five and six
		# times there and never reached the far lip -- in a room that had zero
		# deaths before the wind reached the ground.
		#
		# Isolated rather than guessed: moving the seam off the gap changed
		# nothing, and pointing both zones downwind fixed it outright. The
		# arithmetic says why no retuning would have saved it. A full-gust
		# headwind costs `speed_pf * airtime` of reach, so for a two-cell gap to
		# keep the margin it has in still air the drift would have to be about
		# 0.015 px/frame -- a wind that does nothing. A headwind over a hole is
		# either invisible or unfair, with no setting in between.
		"gaps": [[6, 8]], "blocks": [],
		"enemies": [
			[WALKER, SKIN_WALKER, &"walk", 16.0, 0.0],
			[TURRET, SKIN_TURRET, &"idle", 24.0, 2.0],
		],
		"pit_spikes": [[6, 3, 2]],
		"checkpoint": 2.0,
		"wind": [
			{"dir": DOWNWIND, "from": 0, "to": 11, "phase": 0},
			{"dir": UPWIND, "from": 11, "to": 28, "phase": HALF_CYCLE},
		],
	},
	{
		"name": "Kite", "col": 9, "band": BAND_SEA,
		# The last crossing, and the longest: eight cells on one platform,
		# downwind.
		#
		# Slipstream said the gust helps. This says it long enough that a player
		# stops treating it as a bonus and starts **waiting for it** -- which is
		# the most the stage is allowed to ask, because waiting is optional. The
		# platform crosses it in still air; the gust only decides whether the
		# step off at the far end is comfortable or exact.
		#
		# **The zone starts past the middle of the gap**, so getting on happens
		# in still air and the wind belongs to the half of the ride the player
		# has already chosen to be on. A gust that pushed them off the boarding
		# step would be a gust they could not have read a tell for -- they are
		# still on solid ground when they commit to it.
		#
		# **The crossing is Dawn Boardwalk's The Cut, cell for cell**, and it is
		# a copy on purpose. Kite was drafted with the same eight-cell gap nine
		# cells into the room instead of six, which is the same crossing with a
		# longer walk up to it -- and the bot died at the near lip on every seed,
		# at the identical frame, with the wind on and with the wind off. The
		# difference is not the wind and it is not the platform: it is which
		# phase of the platform's 150-frame leg the player arrives at the lip on,
		# and a room that is only crossable from one arrival phase is a room that
		# is crossable by accident.
		#
		# The lesson is worth more than the room: **a mover's cycle is measured
		# from when the room is built, so where the gap sits decides what phase
		# the player meets it at.** Three shipped mover rooms all put the gap
		# six cells in, and until this one nobody knew whether that was a habit
		# or a requirement.
		#
		# **It was drafted as a two-platform relay and the bot could not do it.**
		# Two short movers out of phase, hand off in the middle: it reads as the
		# stage's most interesting crossing and it is a room with no solution,
		# because the two are only adjacent for a few frames a cycle and the
		# handoff is over eight cells of spikes. Six deaths a run, every run,
		# and the bot never once reached the far lip -- it does not fail rooms
		# it can pass, so a room it fails six times out of six is a room.
		#
		# One long platform is what every other mover room in the game is
		# (Deep Water, The Cut, Lower Trench) and it is the right shape here for
		# the same reason: a moving platform is the kit's answer to "this gap is
		# wider than the jump", and answering it twice in one gap asks a question
		# the kit does not have an answer to. The length is what makes the room
		# the longest crossing; the relay was only what made it the cleverest.
		"gaps": [[6, 14]], "blocks": [],
		"movers": [[6, 0, 8.0, 0.0, 150]],
		"enemies": [
			[FLYER, SKIN_FLYER, &"fly", 23.0, 5.0],
		],
		"pit_spikes": [[6, 3, 8]],
		"checkpoint": 2.0,
		"wind": [{"dir": DOWNWIND, "from": 11, "to": 28, "phase": 0}],
	},
	{
		"name": "Sump", "col": 10, "band": BAND_SEA,
		# The way back up, and **no wind**: the same argument Pier Head makes at
		# the other end of the descent. A ladder is the one place in the game
		# where the player's horizontal position is not theirs to spend.
		#
		# No gaps either, though this column would allow them -- the ladder is at
		# 23 and the landing rule reserves 23-27 in the room above, so the right
		# half of this room is a walk to the ladder and nothing else.
		"gaps": [], "blocks": [[7, 2, 4, 2]],
		"enemies": [
			[WALKER, SKIN_WALKER, &"walk", 14.0, 0.0],
			[SPAWNER, SKIN_SPAWNER, &"idle", 4.0, 3.0],
		],
		"checkpoint": 2.0,
		"shaft_up": [23, 2],
	},
	{
		"name": "Return", "col": 10, "band": BAND_CAUSEWAY,
		# Back on the causeway. **No gaps** -- the sea deck is under this column
		# -- and nothing at all in cells 23-27, which is where Sump's ladder
		# delivers. Building on a landing spawns the player inside terrain and
		# Godot shoves them out sideways; on stage 4 that shove walked the player
		# into the next room's door and spent it.
		"gaps": [], "blocks": [[6, 2, 4, 2], [14, 2, 3, 2]],
		"enemies": [
			[HOPPER, SKIN_HOPPER, &"hop", 11.0, 0.0],
			[FLYER, SKIN_FLYER, &"fly", 19.0, 4.0],
		],
		"checkpoint": 2.0,
	},
	{
		"name": "Gantry", "col": 11, "band": BAND_CAUSEWAY,
		# The service gantry at the tower's foot, and **the one thing the stage
		# has not yet shown the wind doing: making a climb harder.** A headwind
		# over a two-tile step is the same force in the same direction as
		# Anemometer's, and it asks for something different -- there is no lip to
		# fall short of, only a ledge to arrive at, and a gust that shortens the
		# arc turns a routine step-up into a scrape along the wall.
		#
		# **It was drafted with a two-cell hole instead and the bot died in it on
		# every run, at the same frame.** Not because of the wind's strength --
		# it died identically at 0.9 and at 0.35, which is what ruled the drift
		# out -- but because a fatal hole under a cyclic force is a crossing whose
		# difficulty depends on when you arrive at it, and the bot arrives at the
		# same moment every time. A human would arrive at a different one and get
		# a different room.
		#
		# So the hole went. Not because the room was too hard, but because "how
		# hard is it" had no single answer, and a room the level cannot answer
		# that about is a room that cannot be balanced. The wind stays: over a
		# step it costs a scrape, which is a thing the player can be charged for.
		#
		# The turret is well past the step. At cell 12 it stood three cells
		# beyond the landing at head height, firing at a player still recovering
		# -- the placement that cost stage 2's Dead Section a life and stage 4's
		# Aperture a rewrite.
		"gaps": [], "blocks": [[10, 2, 4, 2]],
		"enemies": [
			[TURRET, SKIN_TURRET, &"idle", 21.0, 2.0],
			[CRAWLER, SKIN_CRAWLER, &"crawl", 25.0, 0.0],
		],
		"checkpoint": 2.0,
		"wind": [{"dir": UPWIND, "phase": 0}],
	},
	{
		"name": "Tower Foot", "col": 12, "band": BAND_CAUSEWAY,
		# The base of Gale's turbine, and the second climb. Downwind on the near
		# half only, and still air from cell 18 on -- the ladder rule again.
		"gaps": [[6, 8]], "blocks": [],
		"enemies": [
			[WALKER, SKIN_WALKER, &"walk", 13.0, 0.0],
		],
		"pit_spikes": [[6, 3, 2]],
		"checkpoint": 2.0,
		"wind": [{"dir": DOWNWIND, "from": 0, "to": 18, "phase": 0}],
		"shaft_up": [23, 2],
	},
	{
		"name": "Hub", "col": 12, "band": BAND_NACELLE,
		# Inside the tower, above the weather. **No gaps** -- the causeway is
		# under this column -- and nothing in 23-27, which is Tower Foot's
		# landing.
		#
		# No wind, and that is the point of the band: the nacelle is where the
		# stage stops asking about air and starts asking about the boss. Gale
		# brings its own.
		"gaps": [], "blocks": [[5, 2, 4, 2], [13, 2, 3, 2]],
		"enemies": [
			[HOPPER, SKIN_HOPPER, &"hop", 10.0, 0.0],
			[TURRET, SKIN_TURRET, &"idle", 18.0, 2.0],
		],
		"checkpoint": 2.0,
	},
	{
		"name": "Nacelle", "col": 13, "band": BAND_NACELLE,
		# The last room with anything in it: the machine deck behind the rotor.
		# Two holes and a slide tunnel, no wind, no new ideas -- the room before
		# the run-up should be the stage's vocabulary spoken once more, not a
		# last surprise.
		#
		# **Two enemies, and neither of them stands near a hole.** It was drafted
		# with three -- a tracker on the deck at cell 4 and a flyer at 17 -- and
		# the bot died in the first pit every run: a walker three cells before a
		# two-cell gap is a thing that shoves you into it, and a flyer two cells
		# before one is the same thing from above. The authoring rules measure
		# geometry against a gap and say nothing about what is standing next to
		# it, which is a gap in them and is why this is written down here.
		#
		# The third enemy went rather than moved. Between the first hole and the
		# tunnel there are four cells, and an enemy pinned in four cells is not a
		# patrol, it is an obstacle in a corridor -- and this room already has
		# one of those.
		"gaps": [[7, 9], [19, 21]], "blocks": [],
		"ceilings": [[13, SLIDE_CLEARANCE, 3, 4]],
		"enemies": [
			[FLYER, SKIN_FLYER, &"fly", 4.0, 4.0],
			[CRAWLER, SKIN_CRAWLER, &"crawl", 25.0, 0.0],
		],
		"pit_spikes": [[7, 3, 2], [19, 3, 2]],
		"checkpoint": 2.0,
	},
	{
		"name": "Gate", "col": 14, "band": BAND_NACELLE,
		# Deliberately empty. The run-up to a boss is a breath, and
		# `tests/test_stage_authoring.gd` holds every stage to it: a gap or an
		# enemy in the room before the door turns the walk to a fight into a
		# thing you can arrive at on two health.
		"gaps": [], "blocks": [],
		"enemies": [],
		"checkpoint": 2.0,
	},
	{
		"name": "Arena", "col": 15, "band": BAND_NACELLE,
		# Flat, empty and no checkpoint. **No wind either**, and for the reason
		# Breakers keeps the press out of Rust's arena and Mirror Field keeps the
		# panels out of Prism's: Gale's Crosswind already writes the player's
		# drift every frame, and a room zone writing it as well would mean two
		# authorities on one number and a push the player cannot attribute to
		# anything.
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
	return GALE


func boss_frames_path() -> String:
	return BOSS_FRAMES_PATH


func boss_name() -> String:
	return "Gale"


## The wind zones. This stage's own key, placed here for the same reason stage
## 1's tide, stage 3's presses and stage 4's panels are: the shared kit should
## not grow a slot for every stage's one idea.
##
## **A zone is told where it is and which way it blows, and nothing else about
## time.** Everything that decides when it gusts comes from `WindZone`'s own
## constants, so a room cannot author a gust longer than the lull or a lull a
## jump outlasts -- the two inequalities the whole gimmick's fairness rests on.
## `phase` is the single exception and it only slides the cycle sideways.
func place_stage_elements(spec: Dictionary, _index: int, origin: int, deck: int,
		tile: float) -> void:
	for entry in spec.get("wind", []) as Array:
		var from := int(entry.get("from", 0))
		var to := int(entry.get("to", ROOM_WIDTH))
		var zone := WIND.new() as WindZone
		zone.name = "Wind_%d_%d" % [origin + from, deck]
		zone.direction = int(entry.get("dir", DOWNWIND))
		zone.phase_frames = int(entry.get("phase", 0))
		zone.width_tiles = float(to - from)
		zone.height_tiles = float(ROOM_HEIGHT)
		# The zone's origin is its top-left -- see `WindZone._ready`, which
		# anchors its box there rather than centring it. The room's top is
		# `ROOM_TOP` rows above the band's deck row.
		zone.position = Vector2(float(origin + from),
			float(deck) - float(DECK_ROW - ROOM_TOP)) * tile
		add_child(zone)


## Every wind zone in the stage, in placement order. For the playtest tools and
## for `tests/test_turbine_row.gd`, which checks the built nodes rather than only
## the table -- the shaft bug at M6i was a table that was right and a translation
## that was not.
func wind_zones() -> Array[WindZone]:
	var out: Array[WindZone] = []
	for child in get_children():
		if child is WindZone:
			out.append(child as WindZone)
	return out
