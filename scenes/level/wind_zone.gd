## Turbine Row's gimmick: the wind that comes across the deck.
##
## A region that pushes an **airborne** player sideways on a repeating cycle.
## Grounded, it does nothing at all -- see `Player._apply_wind` for why -- so the
## whole gimmick lives in the arc of a jump, which is where a platformer keeps
## its decisions.
##
## ### The three rules that keep it fair
##
## The same shape `DarkRoom` and `RisingTide` are held to, because a force that
## moves the player is the easiest way in this kit to build something that cannot
## be crossed:
##
##   1. **It never stops a walking player, and it never moves a standing one.**
##      This rule used to read "it never touches a walking player" -- the push
##      applied only in the air. Playtested, that is a wind nobody can feel: you
##      spend most of a room on the ground, so the stage read as still air with
##      occasional odd jumps. Now a headwind drags and a tailwind carries, which
##      is the thing that makes the weather exist, and the guarantee moves to
##      the two ends that actually matter -- you always make headway into it
##      (rule 2), and standing still in a gust never slides you into a pit,
##      because the push scales movement rather than creating it.
##   2. **It is weaker than the player.** `speed_pf` is below
##      `PlayerTuning.walk_speed_pf`, and by enough that a headwind leaves over
##      half the walk speed -- so walking into the teeth of it is slow and never
##      impossible, and the difference is the headway you keep rather than
##      whether you have any. **This is now load-bearing rather than decorative:**
##      with the push on the ground, a wind at or above the walk speed would hold
##      a player still or walk them backwards. `tests/test_wind_zone.gd` asserts
##      it against the real tuning rather than against this comment.
##   3. **It gusts, and the lull outlasts a jump.** A constant wind is a changed
##      constant, learned once and then irrelevant; a gust is a thing to time.
##      The lull is longer than the player is airborne for a full jump
##      (`PlayerTuning.jump_airtime_frames`), so **every crossing in the stage
##      can be made in still air** by someone who waits. The gust is then a tax
##      on impatience rather than a wall.
##
## Rule three is what makes the level authorable at all: a gap is designed
## against the ordinary jump, and the wind decides how long you stand at the lip
## deciding, not whether the jump exists.
##
## ### The tell is the point of the tell
##
## `TELL_FRAMES` of visibly rising streaks before the push starts, for the reason
## `CrusherPress` has a tell and `PhaseBlock` has warn frames: the player is being
## asked to time something, and a thing that cannot be timed until it has already
## happened is not a timing test. The streaks run the way the wind will blow.
class_name WindZone
extends Area2D

enum Phase {
	## Still air. Long enough to cross anything the stage authors.
	LULL,
	## Rising: the streaks speed up and nothing pushes yet.
	TELL,
	## The push.
	GUST,
}

## Which way it blows: +1 for right, -1 for left.
@export var direction: int = 1
## Drift added to an airborne player, in NES px/frame.
##
## **The bound is not "under the walk speed", and that mistake shipped.** It was
## 0.9 -- comfortably under the player's 1.375 -- and rule two was written and
## tested against exactly that comparison. The arithmetic it does not do:
##
##   still air     1.375 px/frame over a 40-frame jump   = 55 px = 3.4 tiles
##   full headwind (1.375 - 0.9) over the same jump      = 19 px = 1.2 tiles
##   the widest gap a stage may author                   =        2.0 tiles
##
## So a headwind gust made every two-cell gap in the game uncrossable, and the
## only reason four stages did not notice is that none of them has wind. Turbine
## Row's bot found it in Gantry: a plain two-cell hole the bot had walked over on
## three previous runs, failed the moment it arrived on a gusting phase.
##
## The real rule is **a full-gust jump still clears the widest authored gap**,
## with headroom rather than to the pixel, and `tests/test_wind_zone.gd` checks
## that against `PlayerTuning` and `AuthoredStage.MAX_GAP_TILES` rather than
## against this number. 0.35 leaves about 2.5 tiles of reach against a 2-tile
## gap, and still pushes an airborne player nearly a whole tile, which is what
## the gust has to be visible enough to do.
@export var speed_pf: float = 0.35

## The cycle, as named constants with the exports defaulting to them.
##
## They are constants as well as exports so a **stage** can derive a timing from
## them rather than write one down: Turbine Row's Crosscut needs two zones half a
## cycle apart, and `HALF_CYCLE` computed from these three stays half a cycle
## when the cycle is retuned, where a `105` in a room table silently stops being
## half of anything. Same argument `CrusherPress` and `PhaseBlock` are built on
## -- a room may offset a phase and may not invent a period.
const DEFAULT_LULL_FRAMES := 96
const DEFAULT_TELL_FRAMES := 30
const DEFAULT_GUST_FRAMES := 84

@export var lull_frames: int = DEFAULT_LULL_FRAMES
@export var tell_frames: int = DEFAULT_TELL_FRAMES
@export var gust_frames: int = DEFAULT_GUST_FRAMES

## Where in the cycle this zone starts, in frames. A stage offsets neighbouring
## zones so a room does not breathe in unison, which is `CrusherPress`'s phase
## argument one element along.
@export var phase_frames: int = 0

@export var width_tiles: float = 28.0
@export var height_tiles: float = 15.0

const STREAK_COUNT := 14
const STREAK_COLOUR := Color(0.82, 0.92, 1.0)

var _frames := 0
var _player: Player = null
var _tuning: PlayerTuning


func _ready() -> void:
	var autoload := get_node_or_null(^"/root/Tuning")
	_tuning = autoload.player if autoload != null else PlayerTuning.new()

	# The zone looks; the player is looked for. Nothing masks its own layer.
	collision_layer = 0
	collision_mask = Layers.bit(Layers.PLAYER_BODY)
	monitoring = true

	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	var tile := _tuning.tile_size()
	rect.size = Vector2(width_tiles, height_tiles) * tile
	shape.shape = rect
	# Anchored at the zone's own origin, which the stage places at the room's
	# top-left, so the box fills the room rather than being centred on a corner.
	shape.position = rect.size * 0.5
	add_child(shape)

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	z_index = -20
	queue_redraw()


## Frames into the cycle, which is `phase_frames` ahead of this zone's own age.
func cycle_frame() -> int:
	var period := cycle_frames()
	if period <= 0:
		return 0
	return (_frames + phase_frames) % period


func cycle_frames() -> int:
	return maxi(lull_frames + tell_frames + gust_frames, 1)


func phase() -> Phase:
	var at := cycle_frame()
	if at < lull_frames:
		return Phase.LULL
	if at < lull_frames + tell_frames:
		return Phase.TELL
	return Phase.GUST


func is_blowing() -> bool:
	return phase() == Phase.GUST


## What this zone pushes with right now, in NES px/frame. Zero outside a gust.
func drift_pf() -> float:
	return float(direction) * speed_pf if is_blowing() else 0.0


func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		_player = body as Player


func _on_body_exited(body: Node2D) -> void:
	if body == _player:
		_player = null


func _physics_process(_delta: float) -> void:
	_frames += 1
	# Written every frame rather than toggled on entry: see Player.wind_drift_pf
	# for why the push is a thing the world says continuously.
	if _player != null and is_instance_valid(_player):
		_player.wind_drift_pf = drift_pf()
	queue_redraw()


## Streaks running the way the wind will blow, faster and brighter as the gust
## approaches. Drawn behind everything (`z_index` -20) so it reads as weather
## rather than as geometry.
func _draw() -> void:
	var tile := _tuning.tile_size()
	var size := Vector2(width_tiles, height_tiles) * tile
	var at := phase()
	var speed := 0.35
	var alpha := 0.10
	if at == Phase.TELL:
		speed = 0.9
		alpha = 0.22
	elif at == Phase.GUST:
		speed = 2.2
		alpha = 0.34

	var travel := float(_frames) * speed * tile * 0.25
	for i in STREAK_COUNT:
		var row := (float(i) + 0.5) / float(STREAK_COUNT) * size.y
		var length := tile * (1.4 + float(i % 3) * 0.8)
		# Each streak starts at its own offset so they do not march in a column.
		var span := size.x + length
		var offset := fposmod(travel + float(i) * span / float(STREAK_COUNT), span)
		var x := offset - length
		if direction < 0:
			x = size.x - offset
		draw_line(Vector2(x, row), Vector2(x + length * float(direction), row),
			Color(STREAK_COLOUR, alpha), maxf(tile * 0.05, 1.5))
