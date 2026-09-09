## Stage 4, "Mirror Field" -- the solar array, and Prism's stage.
##
## Nineteen rooms in an **L**. Stage 1 is a W, stage 2 a long J, stage 3 a
## staircase that climbs all the way; this one runs flat across the field for
## **fourteen rooms** and then turns straight up into the receiver tower and
## stays there.
##
##   col 0    1     2     3    4     5    6   7     8     9    10   11  12   13    14    15    16   17
##  band 0                                                              Landing-Focus-Apertr-Gate-Arena
##                                                                         ^
##  band 1 Array-Pylons-Trough-Salt-Brine-Helio-Duct-Crust-Walk-Trap-Coll-Pan-Anneal-Foot
##
## **Fourteen flat rooms and one turn is the most extreme shape in the game, and
## it is the right one for a plain of mirrors.** The other three stages get their
## variety from terrain; this one has none to get it from, so all of its variety
## has to come from the panels -- which means it needs more room to vary them in,
## not less.
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
##   * **Heliostat Row** -- a path that *climbs* and hands you off onto a block at
##     its top. Until here every crossing returned the player to the deck it
##     started on; this one is a way up, which turns a toll into a route.
##   * **Sun Trap** -- two paths at different phases with solid ground between
##     them: Focus's shape with four cells of rest instead of three, so the exam
##     has something to be an exam of.
##   * **Pan** -- six panels over twelve cells, the longest crossing in the game.
##     Salt says "you cannot stop" in five; this says it long enough that the
##     player has to trust it rather than remember it. Eight was tried and is too
##     many: a set's beat count is its panel count, so two of eight are solid at
##     a time and every one of eight hops has to be right.
##   * **Anneal** -- the field's last crossing, four flush panels: Trough one
##     panel longer. Drafted at the thinnest the rules allow -- three panels
##     three cells apart -- and reverted, because a crossing with every number at
##     its limit is one nobody can make. Focus is the exam; this is the last
##     word, and they are not the same job.
##   * **Focus** -- the exam: two paths half a beat out of step, over two gaps,
##     with three cells of deck between them to re-read the rhythm on.
##
## Five rooms carry no panels at all -- Brine, Duct, Crust, Mirror Walk and
## Collector -- for the reason Foot already gives: a stage whose every room is
## the gimmick has no gimmick, only a floor. `tests/test_mirror_field.gd` checks
## that the panel rooms are not all adjacent.
##
## **Every path begins level with the deck it leaves.** Crust was drafted as a
## path starting two rows up, and that is a crossing whose first move is a jump
## up and across onto a block that is only there half the time, taken from the
## lip of a ten-cell pit. A crossing may ask the player to commit; it may not ask
## them to commit before they are on it.
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
		"name": "Brine", "col": 4, "band": BAND_FIELD,
		# No panels. Trough and Salt asked for the gimmick twice running, and the
		# stage's own rule -- written on Foot -- is that a room of plain
		# platforming has to come between, or the panels stop being an event and
		# become the floor. This is that room, moved earlier now the field is
		# long enough to need two of them.
		"gaps": [[8, 10], [16, 18]], "blocks": [[22, 2, 4, 2]],
		"enemies": [
			[WALKER, SKIN_WALKER, &"walk", 5.0, 0.0],
			[FLYER, SKIN_FLYER, &"fly", 13.0, 4.0],
			[TURRET, SKIN_TURRET, &"idle", 20.0, 2.0],
		],
		"pit_spikes": [[8, 3, 2], [16, 3, 2]],
		"checkpoint": 2.0,
	},
	{
		"name": "Heliostat Row", "col": 5, "band": BAND_FIELD,
		# **A path that climbs, and puts you somewhere new.** Every crossing so
		# far has started and ended on the deck -- Salt arcs up and comes back
		# down to it. This one steps 0-1-2-2 and hands the player off onto a
		# block at the same height, so the panels are not just floor that comes
		# and goes, they are a way *up*.
		#
		# That matters for what the gimmick means. A disappearing staircase that
		# always returns you to where you started is a toll; one that leaves you
		# on higher ground is a route.
		"gaps": [[8, 16]], "blocks": [[16, 2, 4, 2]],
		"enemies": [
			[FLYER, SKIN_FLYER, &"fly", 22.0, 5.0],
			[CRAWLER, SKIN_CRAWLER, &"crawl", 25.0, 0.0],
		],
		"pit_spikes": [[8, 3, 8]],
		"checkpoint": 2.0,
		"mirrors": [
			{"path": [[8, 0], [10, 1], [12, 2], [14, 2]], "phase": 0},
		],
	},
	{
		"name": "Duct", "col": 6, "band": BAND_FIELD,
		# The cooling duct under the array, and the stage's one required slide.
		# No panels: the kit is what keeps a stage from being a gimmick with
		# scenery, and a stage whose every hard moment is the same object has
		# only one idea however many rooms it has.
		"gaps": [[6, 8]], "blocks": [[21, 2, 4, 2]],
		"ceilings": [[14, SLIDE_CLEARANCE, 3, 4]],
		"enemies": [
			[HOPPER, SKIN_HOPPER, &"hop", 10.0, 0.0],
			[CRAWLER, SKIN_CRAWLER, &"crawl", 19.0, 0.0],
			[TURRET, SKIN_TURRET, &"idle", 25.0, 2.0],
		],
		"pit_spikes": [[6, 3, 2]],
		"checkpoint": 2.0,
	},
	{
		"name": "Crust", "col": 7, "band": BAND_FIELD,
		# No panels and no holes: the ridges of dried salt, climbed.
		#
		# It was drafted as Heliostat Row reversed -- a path that **starts** two
		# rows up and steps down into the pan. That reads well and is a bad
		# entry: the first panel is a jump up *and* across, onto a block that is
		# only there half the time, taken from the lip of a ten-cell pit. Get it
		# wrong and there is nowhere to have been. The bot stood on that lip for
		# nine hundred frames and never tried it, which is the honest response.
		#
		# A crossing may ask the player to commit; it may not ask them to commit
		# before they are on it. Every path in this stage now begins level with
		# the deck it leaves, and climbs afterwards if it climbs at all.
		#
		# What the room is instead: the only vertical terrain in fourteen flat
		# ones. A stage with no landscape still needs somewhere to stand above
		# itself once.
		"gaps": [], "blocks": [[5, 2, 3, 2], [11, 4, 3, 2], [17, 2, 4, 2]],
		"enemies": [
			[WALKER, SKIN_WALKER, &"walk", 8.0, 2.0],
			[TURRET, SKIN_TURRET, &"idle", 13.0, 4.0],
			[FLYER, SKIN_FLYER, &"fly", 21.0, 5.0],
			[CRAWLER, SKIN_CRAWLER, &"crawl", 25.0, 0.0],
		],
		"checkpoint": 2.0,
	},
	{
		"name": "Mirror Walk", "col": 8, "band": BAND_FIELD,
		# The service walk between two rows, and the stage's second breath.
		#
		# It was drafted with a ferry and crumbling planks in it, on the argument
		# that "the field is not a stage about panels, it is a stage that has
		# panels in it". `tests/test_mirror_field.gd` refused both, and it is
		# right: a mover and a panel path are two answers to "this gap is wider
		# than the jump", and a stage offering both makes neither mean anything;
		# a crumbling block is what a panel looks like under a different rule,
		# and one stage may not contain both or the player cannot tell by looking
		# which rule governs which block. So a breath here is jumps and
		# platforms, and the crossings stay panels.
		# Both holes moved eight cells further in, and the reason is worth
		# recording because two guesses came first. The room shipped its first
		# gap at cell 6, and the bot walked into it at the same frame on every
		# seed. The first guess was the hopper on the island; the second was the
		# crawler on the approach. Removing both changed nothing at all -- the 2
		# HP lost on the way down was the pit's own spikes, not an enemy -- and
		# an identical death frame across seeds is what geometry looks like when
		# you have been blaming choreography.
		#
		# Stage 2's Dead Section is the same finding from the same afternoon: a
		# hole a few cells inside a door is one the player is walking at before
		# they are looking at it.
		"gaps": [[10, 12], [16, 18]], "blocks": [],
		"one_ways": [[21, 3, 5]],
		# The hopper is out on the long deck, not on the four-cell island between
		# the two holes. A hopper travels on a fixed arc and does not care where
		# it is; a player who lands on that island and is bumped has one cell of
		# room and a pit either side, and the bot found it twice.
		#
		# Deliberately **not** generalised into a rule. Enemies sit within a
		# couple of cells of a landing all over this game -- more than thirty
		# placements across four stages -- and almost none of them cost anything.
		# What is wrong here is a *moving* enemy on a short island, which is not
		# the same claim and is not one a table can check.
		# **Nothing on the approach to the first hole.** The room shipped a crawler
		# at cell 4 against a gap at 6: the player comes through the door, meets
		# it at five, is knocked two cells, and the two cells are the gap. The bot
		# died there on every seed at the identical frame, which is what a
		# geometry problem looks like as opposed to an unlucky one -- and moving
		# the *hopper*, which was the first guess, changed nothing at all.
		#
		# The gaps are this room's content, so they get clear ground in front of
		# them and the enemies live in the second half.
		"enemies": [
			[FLYER, SKIN_FLYER, &"fly", 14.0, 5.0],
			[HOPPER, SKIN_HOPPER, &"hop", 20.0, 0.0],
			[CRAWLER, SKIN_CRAWLER, &"crawl", 25.0, 0.0],
		],
		"pit_spikes": [[10, 3, 2], [16, 3, 2]],
		"checkpoint": 2.0,
	},
	{
		"name": "Sun Trap", "col": 9, "band": BAND_FIELD,
		# Two paths at different phases, with solid ground between them -- which
		# is Focus's shape, taught here with four cells of rest instead of three
		# and flush panels instead of an arc. Introduce, then examine.
		#
		# **It was drafted as two rows stacked over one pit, half a beat apart,
		# and that was a worse idea than it sounded.** Crossing by going up and
		# back down as each row takes its turn reads beautifully in a table and is
		# illegible on screen: two sets of mounts overlapping the same hole, and
		# the thing this stage most needs to communicate from across the room is
		# which mounts are full. The backdrop is built around that one signal.
		# The bot stood at the lip for nine hundred frames rather than pick a row.
		# **Four panels a path, not three, and the difference is the cycle rather
		# than the length.** A set's beat count is its panel count, so a
		# three-panel path turns over faster than a four -- two of three solid
		# against two of four. Drafted at three, the last hop of the second
		# crossing came due just as its panel went, and the bot fell off the end
		# of a route it had crossed correctly.
		#
		# Four flush panels with four cells of deck between the crossings, where
		# Focus has rises and three: this is the introduction and that is the
		# exam, and they should not be the same room.
		"gaps": [[5, 13], [17, 25]], "blocks": [],
		"enemies": [
			[CRAWLER, SKIN_CRAWLER, &"crawl", 15.0, 0.0],
			[TURRET, SKIN_TURRET, &"idle", 26.0, 2.0],
		],
		"pit_spikes": [[5, 3, 8], [17, 3, 8]],
		"checkpoint": 2.0,
		"mirrors": [
			{"path": [[5, 0], [7, 0], [9, 0], [11, 0]], "phase": 0},
			{"path": [[17, 0], [19, 0], [21, 0], [23, 0]], "phase": HALF_BEAT},
		],
	},
	{
		"name": "Collector", "col": 10, "band": BAND_FIELD,
		# The collector head, and the last plain room before the field's longest
		# crossing. A rack over the middle of it, so the climb is made with
		# something arriving.
		"gaps": [[9, 11]], "blocks": [],
		"one_ways": [[15, 2, 4], [21, 4, 4]],
		"enemies": [
			[WALKER, SKIN_WALKER, &"walk", 5.0, 0.0],
			[SPAWNER, SKIN_SPAWNER, &"idle", 13.0, 4.0],
			[FLYER, SKIN_FLYER, &"fly", 19.0, 6.0],
		],
		"pit_spikes": [[9, 3, 2]],
		"checkpoint": 2.0,
	},
	{
		"name": "Pan", "col": 11, "band": BAND_FIELD,
		# The evaporation pan proper: **six panels over twelve cells**, the longest
		# crossing in the game against Salt's five. Salt makes the point that you
		# cannot stop; this says it for long enough that the player has to trust
		# it rather than remember it.
		#
		# **It was drafted at eight and eight was too many, for a reason that is
		# about the cycle rather than the distance.** A set's beat count is its
		# panel count, so two of eight are solid at a time where two of five are
		# in Salt -- the tolerance per hop is unchanged, but there are eight of
		# them and every one has to be right. The bot crossed seven and fell off
		# the last, twice, on both seeds. A crossing that punishes the eighth
		# correct decision is not asking for skill, it is asking again.
		#
		# An arc rather than a flat run, for Salt's reason: identical hops read
		# as one obstacle repeated, and a shape reads as a route.
		"gaps": [[7, 19]], "blocks": [],
		"enemies": [
			[FLYER, SKIN_FLYER, &"fly", 24.0, 4.0],
		],
		"pit_spikes": [[7, 3, 12]],
		"checkpoint": 2.0,
		"mirrors": [
			{"path": [[7, 0], [9, 1], [11, 1], [13, 2], [15, 1], [17, 0]],
				"phase": 0},
		],
	},
	{
		"name": "Anneal", "col": 12, "band": BAND_FIELD,
		# The field's last crossing: four flush panels over eight cells, which is
		# Trough's shape one panel longer.
		#
		# **It was drafted as the thinnest thing the rules allow -- three panels
		# three cells apart -- and that was a worse idea than it sounded.** Three
		# is the shortest a path may be and three cells the furthest the jump
		# covers, so every number was at its limit at once, and the bot fell in
		# the middle of it on both seeds. "The known thing with the slack taken
		# out" is a nice sentence about a crossing nobody can make.
		#
		# The hardest panel room in the stage is Focus, which is the exam and has
		# a room of deck to read the rhythm on first. The field's job is to have
		# taught it by then, and a last word does not have to be a last stand.
		"gaps": [[9, 17]], "blocks": [],
		"enemies": [
			[FLYER, SKIN_FLYER, &"fly", 22.0, 4.0],
			[WALKER, SKIN_WALKER, &"walk", 25.0, 0.0],
		],
		"pit_spikes": [[9, 3, 8]],
		"checkpoint": 2.0,
		"mirrors": [
			{"path": [[9, 0], [11, 0], [13, 0], [15, 0]], "phase": 0},
		],
	},
	{
		"name": "Foot", "col": 13, "band": BAND_FIELD,
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
		"name": "Landing", "col": 13, "band": BAND_TOWER,
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
		"name": "Focus", "col": 14, "band": BAND_TOWER,
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
		"name": "Aperture", "col": 15, "band": BAND_TOWER,
		# Inside the receiver tower, above the field. No panels: the tower is
		# where the stage stops asking about timing and starts asking about the
		# boss, and Gate is one room away.
		"gaps": [[8, 10], [18, 20]], "blocks": [[22, 2, 4, 2]],
		# The turret is past both holes. At cell 13 it stood three cells beyond
		# the first landing at head height, firing horizontally at a player still
		# recovering from the jump -- the same placement that cost stage 2's Dead
		# Section a life. A turret is a thing to shoot past, not a thing to be
		# shot by while landing.
		"enemies": [
			[WALKER, SKIN_WALKER, &"walk", 5.0, 0.0],
			[FLYER, SKIN_FLYER, &"fly", 15.0, 4.0],
			[TURRET, SKIN_TURRET, &"idle", 24.0, 2.0],
		],
		"pit_spikes": [[8, 3, 2], [18, 3, 2]],
		"checkpoint": 2.0,
	},
	{
		"name": "Gate", "col": 16, "band": BAND_TOWER,
		# Deliberately empty. The run-up to a boss is a breath, and
		# `tests/test_stage_authoring.gd` holds every stage to it: a gap or an
		# enemy in the room before the door turns the walk to a fight into a
		# thing you can arrive at on two health.
		"gaps": [], "blocks": [],
		"enemies": [],
		"checkpoint": 2.0,
	},
	{
		"name": "Arena", "col": 17, "band": BAND_TOWER,
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
