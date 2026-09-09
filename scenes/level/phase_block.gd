## Mirror Field's gimmick: a panel that is there on its beat and not otherwise.
##
## **A block is solid for exactly two beats, and a beat is one jump.** That one
## line is the whole grammar, and both halves are derived rather than chosen:
## a jump is airborne `2 * jump_velocity_pf / gravity_pf` = 39.5 frames
## (`PlayerTuning`), and `BEAT_FRAMES` is that plus reaction slack. The
## consequence is the design -- at any instant a path shows the player the block
## they are standing on and the next one, and nothing else. You cannot stand
## still, you cannot go back, and you never have to guess where to go.
##
## ### The beat is a fact about the block; a room may only offset the phase
##
## Exactly the rule `CrusherPress` settled, and for the same reason: stage 2
## shipped a 130-frame mover leg that walked a late rider off a lip, and the fix
## was to stop inventing timings per placement. A room says *where* the panels
## are and *in what order*; it does not get to say how long a beat is. A set that
## wants to run out of step with its neighbour offsets `phase_frames`.
##
## ### The order is the list, so an incoherent set cannot be written down
##
## A block's beat is its **index in its path**, handed to it by the stage, and a
## path is authored as a list of positions in the order they are crossed. There
## is nowhere to write "beat 3 has two panels in it" or "beat 2 is empty",
## because the beats are the indices of a list. `path_length` is that list's
## size, so the cycle is `path_length * BEAT_FRAMES` and the phases of a set
## always tile it exactly.
##
## Three blocks is the minimum, and it is structural: with two, `SOLID_FRAMES`
## covers the whole cycle and both panels are permanently solid, which is a
## staircase rather than a gimmick. `tests/test_mirror_field.gd` holds every
## authored path to it.
##
## ### The mount is always drawn, and that is the fairness bound
##
## The same job Rust's alternate columns do: a gimmick that removes information
## can always be made unfair, and the unfair version is the easy one to build.
## A panel that is gone still draws its **empty steel mount**, so the whole route
## is legible from across the room and before it is committed to. The player is
## asked to time a path they can see, never to discover one by dying.
##
## It is also a *shape* difference rather than a colour one, which is a
## down-payment on the colourblind palette PLAN.md M8 names for exactly this
## gimmick.
##
## ### What it inherits, and why
##
## `CrumblingBlock`'s three phases map with nothing left over -- solid, a tell,
## gone -- and the only thing that differs is what starts the countdown. So this
## overrides the two hooks that class grew (`triggers_on_contact`, `_tick_solid`)
## and inherits the shape, the collision, the restore and the whole `AnimatableBody2D`
## arrangement rather than copying them. That is what PLAN.md section 4 meant by
## calling the crumbling block "the basis for Mirror Field's disappearing blocks".
class_name PhaseBlock
extends CrumblingBlock

## One beat, in frames.
##
## **Derived from the jump, not picked.** A jump is airborne
## `2 * jump_velocity_pf / gravity_pf` = 2 * 4.9375 / 0.25 = 39.5 -> 40 frames,
## and 12 frames on top of that is about a fifth of a second of reaction. So one
## beat is one hop with time to decide to make it, which is what lets a path be
## *run* rather than picked across one stalled jump at a time.
##
## `tests/test_mirror_field.gd` checks it against `PlayerTuning`'s real numbers
## rather than against this comment, because the comment is the thing that goes
## stale when the jump is retuned.
const BEAT_FRAMES := 52

## Beats a block stays solid. Two, and the number is the design:
##
##   * fewer than two and consecutive panels never overlap, so crossing is
##     jumping into a space and trusting the next one to arrive -- memorisation,
##     which is the version of this gimmick everyone remembers hating;
##   * more than two and three panels are up at once, which is a staircase that
##     occasionally blinks.
##
## Two means the player always sees exactly where they are and exactly where they
## are going.
const SOLID_BEATS := 2
const SOLID_FRAMES := SOLID_BEATS * BEAT_FRAMES

## The tell, in frames: the tail of the solid window, spent flickering.
##
## Same rule `BossPattern` imposes on every boss attack and `CrusherPress` on the
## press -- nothing in this game may become dangerous without first saying so.
## 18 frames is a little under a third of a second, which is long enough to read
## from the corner of the eye while looking at where you are going next.
const WARN_FRAMES := 18

## The mount: always drawn, in every phase. See the docstring.
const MOUNT := Color(0.24, 0.26, 0.31)
const MOUNT_EDGE := Color(0.14, 0.15, 0.19)
## The panel: pale glass with a cold highlight, so it reads against a bright
## stage rather than only against a dark one.
const GLASS := Color(0.63, 0.80, 0.90)
const GLASS_LIT := Color(0.88, 0.95, 1.0)
const GLASS_EDGE := Color(0.30, 0.42, 0.52)

## Which beat of its path this block occupies. Set by the stage from the block's
## index in the authored list -- never authored directly, because the list order
## is what makes a set coherent.
@export var beat_index: int = 0
## How many blocks the path has. The cycle is this many beats.
@export var path_length: int = 3
## Offsets the whole set, so two paths in a room can run out of step. The only
## timing number a room is allowed to supply.
@export var phase_frames: int = 0


func cycle_frames() -> int:
	return maxi(path_length, 1) * BEAT_FRAMES


## Where in this block's own cycle it is at a given frame, with 0 meaning "has
## just turned solid".
##
## Static and pure so a test can walk a whole cycle without stepping physics for
## four seconds -- the same reason `CrusherPress.extension_at` is written this
## way.
static func local_frame(frame: int, index: int, length: int) -> int:
	var cycle := maxi(length, 1) * BEAT_FRAMES
	return posmod(frame - index * BEAT_FRAMES, cycle)


## The phase a block of this set is in at a given frame. Pure, for the same
## reason as `local_frame`.
static func phase_at(frame: int, index: int, length: int) -> Phase:
	var at := local_frame(frame, index, length)
	if at < SOLID_FRAMES - WARN_FRAMES:
		return Phase.SOLID
	if at < SOLID_FRAMES:
		return Phase.WARNING
	return Phase.GONE


## Whether a block of this set can be stood on at a given frame. Warning counts:
## a panel that is about to go is still a panel, and the tell would be pointless
## if it were not.
static func is_solid_at(frame: int, index: int, length: int) -> bool:
	return phase_at(frame, index, length) != Phase.GONE


## Frames this panel has left before it goes, counting the flicker.
##
## For anything deciding whether to *commit* to a panel rather than whether it is
## standing right now -- `tools/playthrough.gd` asks it before every hop, because
## landing on a panel with four frames left is the same as landing on nothing.
## A player reads the flicker; a bot needs the number.
func solid_frames_left() -> int:
	match phase:
		Phase.SOLID:
			return maxi(SOLID_FRAMES - _frames, 0)
		Phase.WARNING:
			return maxi(warn_frames - _frames, 0)
		_:
			return 0


func _ready() -> void:
	# The inherited timers, restated from the constants above so the three
	# durations sum to exactly one cycle by construction. That is what stops a
	# set drifting out of step over a long run: there is no rounding anywhere to
	# accumulate.
	warn_frames = WARN_FRAMES
	respawn_frames = cycle_frames() - SOLID_FRAMES
	# No shake. `CrumblingBlock` wobbles its warning because a wooden plank
	# gives; a mounted glass panel does not, and moving it would move the thing
	# the player is standing on during the one moment they are reading it.
	shake_px = 0.0
	super()
	_align_to_phase()


## A clock, not a lid. See `CrumblingBlock.triggers_on_contact`.
func triggers_on_contact() -> bool:
	return false


## And a clock the room does not get to interrupt. A crumbling plank is reset
## when the player leaves or dies, because a room of broken planks is a room
## with no floor; a panel set has no such failure -- every panel comes back on
## its own beat -- and resetting one on a door transition would put every panel
## of a path back on beat 0 together, which is exactly what `_align_to_phase`
## exists to prevent.
func resets_on_room_change() -> bool:
	return false


## The beat. `_frames` is counting up through the solid window; the tell begins
## when the untriggered part of it is spent, and `trigger()` does the rest
## through the inherited machinery.
func _tick_solid() -> void:
	if _frames >= SOLID_FRAMES - WARN_FRAMES:
		trigger()


## Puts the block into the phase its beat says it should already be in.
##
## **Without this every panel in a set starts solid together** and the sequence
## only separates out over the first cycle, so the first path the player meets is
## the one that behaves differently from all the others. The offset is applied
## once, here, and the durations above keep it forever.
func _align_to_phase() -> void:
	var at := local_frame(phase_frames, beat_index, maxi(path_length, 1))
	if at < SOLID_FRAMES - WARN_FRAMES:
		phase = Phase.SOLID
		_frames = at
	elif at < SOLID_FRAMES:
		phase = Phase.WARNING
		_frames = at - (SOLID_FRAMES - WARN_FRAMES)
	else:
		phase = Phase.GONE
		_frames = at - SOLID_FRAMES
	_set_collision(phase != Phase.GONE)
	visible = true  # the mount is drawn in every phase
	queue_redraw()


## Gone is invisible in the parent and merely empty here, so visibility is never
## the thing that says whether a panel is standing. `is_solid()` is.
func _fall() -> void:
	super()
	visible = true
	queue_redraw()


func _draw() -> void:
	var size := world_size()
	var edge := maxf(size.y * 0.05, 2.0)

	# The mount, in every phase: a bracket at each end and a rail between them.
	# This is the promise that the route is visible before it is walked.
	var post := maxf(size.x * 0.12, 3.0)
	var rail := Rect2(Vector2(0.0, size.y - post), Vector2(size.x, post))
	draw_rect(rail, MOUNT)
	draw_rect(rail, MOUNT_EDGE, false, maxf(edge * 0.5, 1.0))
	for at in [0.0, size.x - post]:
		var bracket := Rect2(Vector2(at, size.y * 0.55), Vector2(post, size.y * 0.45))
		draw_rect(bracket, MOUNT)
		draw_rect(bracket, MOUNT_EDGE, false, maxf(edge * 0.5, 1.0))

	if phase == Phase.GONE:
		return

	# The panel. During the tell it flickers -- alternating frames rather than a
	# fade, because a fade at this size reads as a lighting change and a flicker
	# reads as a fault, which is what it is.
	var alpha := 1.0
	if phase == Phase.WARNING:
		alpha = 0.85 if _frames % 8 < 4 else 0.30
	var glass := Rect2(Vector2.ZERO, Vector2(size.x, size.y - post * 0.5))
	draw_rect(glass, Color(GLASS, alpha))
	# A diagonal catch of light, so a panel reads as glass rather than as a
	# coloured slab -- and so the flicker has something to flicker.
	draw_colored_polygon(PackedVector2Array([
		Vector2(size.x * 0.08, glass.size.y * 0.92),
		Vector2(size.x * 0.44, glass.size.y * 0.08),
		Vector2(size.x * 0.66, glass.size.y * 0.08),
		Vector2(size.x * 0.30, glass.size.y * 0.92),
	]), Color(GLASS_LIT, alpha * 0.9))
	draw_rect(glass, Color(GLASS_EDGE, alpha), false, edge)


## The panel blinking out. Quiet and short: a room can hold six of these on one
## beat, and six of anything loud is a fault.
func trigger() -> void:
	super()
	Sfx.play(&"panel", -14.0)
