## Frost -- Cold Store's Robot Master, and the seventh of the eight.
##
## Eighteen answers are spent by boss seven. Cinder's three were the last of the
## genuinely new *verbs* -- baiting, refusing a constant, and reading a tell as
## an opening -- and pretending to find three more would produce three patterns
## with the same answer wearing different hats.
##
## So Frost escalates the **structure** instead, and it is the only boss in the
## roster that does: **its patterns compose.** Rime is a setup that is harmless
## on its own. Lock is a punishment that can only reach a player standing on
## what Rime left. Neither is dangerous alone and the pair is the fight.
##
##   * **Rime** freezes the arena floor outward from Frost in patches. Nothing
##     about it can hurt you. What it does is take away the part of the floor you
##     can stop precisely on, and the answer is **claiming the ground you want
##     before it is gone** -- the first pattern in the game answered by where you
##     go during it rather than by what you avoid.
##   * **Calving** throws a block of ice with a hurtbox on it. The answer is
##     **shooting the attack** -- the only pattern in the roster answered with
##     the fire button aimed at something other than the boss. Shot down it
##     bursts; allowed to land it shatters into two low shards running both
##     ways, so the price of ignoring it is paid at ankle height.
##   * **Lock** fires a bolt that coats the player's feet rather than damaging
##     them, and Frost **only throws it at a player standing on ice**. On bare
##     deck the pattern is a wasted turn, which makes the answer to Lock the
##     same as the answer to Rime, one pattern later. That is the composition,
##     and it is why the fight is more than its parts.
##
## ### It never takes the controls away
##
## A stun boss is the obvious place to freeze the player, and it is the one
## thing this game must not do. Every fairness rule in the roster exists so the
## player always has an answer available; a pattern that stops your inputs is a
## pattern that can kill you while you watch. `Player.slip` degrades grip
## instead -- every input still works, they all just arrive late -- which is the
## same idea charged as a cost rather than a confiscation.
##
## ### Frost is weak to Quarry Bore, which does not exist yet
##
## The position Arc, Rust, Prism and Cinder were each in until the next stage
## landed. The row is in `resources/damage_tables/frost.tres` because the table
## is the design, and the fight has to stand up buster-only until stage 8.
class_name Frost
extends Boss

const BLOCK := preload("res://scenes/actors/projectiles/ice_block.gd")
const BOLT := preload("res://scenes/actors/projectiles/enemy_shot.gd")
const SHEET := preload("res://scenes/level/ice_floor.gd")
const DAMAGE_TABLE := preload("res://resources/damage_tables/frost.tres")
const SPRITE_FRAMES := preload("res://resources/sprite_frames/frost.tres")

## Boss index 6 (docs/PLAN.md section 4).
const INDEX := 6

## Squat and broad, like the plant it lives in.
const BODY_NES := Vector2(24.0, 26.0)

# --- Rime -----------------------------------------------------------------------

## Sheets laid per Rime, and how wide each is in tiles.
const RIME_SHEETS := 3
const RIME_WIDTH_TILES := 5.0
## How long a sheet lasts. Long enough to still be there when Lock comes round,
## which is the whole of the composition; short enough that the arena is not
## permanently ice by the third cycle.
const RIME_FRAMES := 420
## Grip a rimed floor leaves. Slipperier than the stage's own sheets: this is the
## boss's version of the gimmick and it should read as worse than the level's.
const RIME_GRIP := 0.045

## The freeze front: a low wave that runs out from Frost each way as the sheets
## form, and the only thing in the fight that reaches a player who is not moving.
##
## **Frost was built without one and could not touch the bot at all.** Three
## patterns, thirty seconds, no damage: Rime is harmless by design, Calving is
## destructible by design, and Lock is a single slow bolt gated on the player
## standing where they need not stand. Every one of those is a good idea and
## together they are not a fight -- the telemetry showed the bot parked three
## tiles away shooting, and nothing Frost owned went that far.
##
## So the front is the floor of the fight: it costs nothing to read, it is
## **jumpable** (`WAVE_NES.y` is well under the jump apex, checked in
## `tests/test_frost.gd`), and it goes both ways so backing off is not free. It
## is the same job Cinder's Backdraft breath does and the same reason that fight
## works -- a boss needs one attack that arrives whether or not the player has
## decided to engage.
const WAVE_NES := Vector2(14.0, 11.0)
const WAVE_SPEED_PF := 3.0
const WAVE_DAMAGE := 3

# --- Calving --------------------------------------------------------------------

## Where a block is thrown from, above Frost's feet, in NES px.
const CALVE_HEIGHT_NES := 30.0
## Upward kick and how far ahead it is aimed, so the arc is watchable.
const CALVE_RISE_PF := 3.6
## Blocks per Calving, and the act frames they leave on.
##
## **Two, and the second one is what pays for the Lock gate.** A player who
## correctly refuses to stand on ice turns Lock into a wasted turn, which is the
## design working -- and it also removes a third of the fight's threat. Calving
## carries that cost, because it is the pattern whose answer (shoot it) the
## player has already chosen to spend their attention on.
##
## Spaced so the first block is landing or bursting as the second leaves: two
## simultaneous blocks would be one wide obstacle, and two far apart would be
## two easy ones.
const CALVE_BLOCKS := [0, 22]

# --- Lock -----------------------------------------------------------------------

const LOCK_SPEED_PF := 3.4
## Damage a bolt does. Small: the punishment is the ice, not the hit.
const LOCK_DAMAGE := 2
## Frames the player's feet stay coated, and the grip left them.
##
## **Grip, not control.** See the note in the class docstring -- a boss that can
## stop your inputs is the one thing the roster's fairness rules forbid.
const LOCK_SLIP_FRAMES := 150
const LOCK_SLIP_GRIP := 0.05

## Sheets this Rime laid, for the tests and for Lock to ask about.
var _sheets: Array[IceFloor] = []


func _ready() -> void:
	boss_index = INDEX
	weapon_id = &"frost_lock"
	display_name = "Frost"
	contact_damage = 4
	anim_name = &"idle"
	if damage_table == null:
		damage_table = DAMAGE_TABLE
	if sprite_frames == null:
		sprite_frames = SPRITE_FRAMES
	super()


func body_size() -> Vector2:
	return BODY_NES * tuning.world_scale


func build_patterns() -> Array[BossPattern]:
	var out: Array[BossPattern] = []
	# Rime first and most often: it is the setup, and a fight whose setup is
	# rare is a fight whose payoff never lands.
	out.append(BossPattern.new(&"rime", 34, 16, 44, 1.3)
		.with_anims(&"attack", &"attack", &"idle"))
	out.append(BossPattern.new(&"calving", 40, 30, 42, 1.1)
		.with_anims(&"jump", &"attack", &"idle"))
	out.append(BossPattern.new(&"lock", 38, 14, 44, 0.9)
		.with_anims(&"attack", &"attack", &"idle"))
	return out


func fight_move(_delta: float) -> void:
	# Frost holds its ground. It is a refrigeration plant, not a chaser, and the
	# fight is about what the floor becomes rather than about closing distance.
	velocity.x = 0.0
	hold_inside_arena()


func tell(_pattern: BossPattern, _frame: int) -> void:
	velocity.x = 0.0


func act(pattern: BossPattern, frame: int) -> void:
	if pattern.id == &"calving":
		if CALVE_BLOCKS.has(frame):
			_calve()
		return
	if frame != 0:
		return
	match pattern.id:
		&"rime":
			_lay_rime()
			_send_front()
		&"calving":
			_calve()
		&"lock":
			# **The composition, and it has to be here rather than in the
			# docstring.** The first version described this gate in prose and
			# fired unconditionally, which made Lock a third independent pattern
			# and the fight the sum of three easy ones -- the bot beat Frost
			# without taking a hit.
			if target_is_on_ice():
				_fire_lock()


func recover(_pattern: BossPattern, _frame: int) -> void:
	velocity.x = 0.0


# --- Patterns -------------------------------------------------------------------

## Sheets of ice laid **where the player is standing**, and either side of them.
##
## Centred on the player rather than spread across the arena, and that is the
## whole difference between a pattern and a decoration. The first version
## scattered three sheets evenly down the span on the argument that an even
## spread is predictable and therefore claimable -- which is true, and useless:
## a player holding one spot is simply never iced. The playthrough bot fought
## the whole of Frost from one position and took **no damage at all**, because
## ice never reached it and Lock is gated on ice.
##
## Aimed at the player is also the fair version, for the same reason Arc's
## Curtain, Rust's Bloom and Prism's Sweep are: the ask is to leave a place you
## can see, not to guess which part of the room is about to be bad.
##
## The bound survives the change and is what keeps it fair: `RIME_SHEETS` sheets
## of `RIME_WIDTH_TILES` cannot tile the arena, so there is always floor left to
## claim -- the same guarantee Rust's alternate columns and Prism's facet span
## are built on.
func _lay_rime() -> void:
	var span := arena_span()
	var tile := tuning.tile_size()
	var width := RIME_WIDTH_TILES * tile
	var centre := _target_x()
	for i in RIME_SHEETS:
		# One under the player and the rest either side, spaced by a sheet and a
		# half so the set has gaps in it rather than being one wide rink.
		var offset := float(i - RIME_SHEETS / 2) * width * 1.5
		var left := clampf(centre + offset - width * 0.5, span.x, span.y - width)
		var sheet := SHEET.new() as IceFloor
		sheet.grip = RIME_GRIP
		sheet.width_tiles = RIME_WIDTH_TILES
		sheet.position = Vector2(left, arena_floor_y())
		_spawn(sheet)
		_sheets.append(sheet)
		# Sheets are temporary, so a long fight does not end on a solid rink.
		var timer := get_tree().create_timer(float(RIME_FRAMES) / 60.0)
		timer.timeout.connect(func() -> void:
			if is_instance_valid(sheet):
				sheet.queue_free())


## The freeze front: one low wave each way, along the floor, from Frost's feet.
##
## Both directions, so retreating is not an answer on its own -- the same
## argument Prism's Sweep and Cinder's Flue are built on. Low enough to jump and
## slow enough to see coming, which is what makes it the fight's floor rather
## than its ceiling.
func _send_front() -> void:
	for way in [-1.0, 1.0]:
		var wave := BOLT.new() as EnemyShot
		wave.size_nes = WAVE_NES
		wave.launch(Vector2(global_position.x, arena_floor_y() - WAVE_NES.y * 0.5 * tuning.world_scale),
			Vector2(way, 0.0), WAVE_SPEED_PF, WAVE_DAMAGE, tuning)
		_spawn(wave)


## The block, thrown on an arc toward the player.
func _calve() -> void:
	var floor_y := arena_floor_y()
	var from := global_position + Vector2(
		float(facing()) * BODY_NES.x * 0.5 * tuning.world_scale,
		-CALVE_HEIGHT_NES * tuning.world_scale)
	var rise := tuning.px_s(CALVE_RISE_PF)
	# Time of flight solved from the rise and the fall, so the block lands where
	# it was aimed rather than wherever the arithmetic put it.
	var flight := 2.0 * rise / tuning.px_s2(tuning.gravity_pf)
	var across := (_target_x() - from.x) / maxf(flight, 0.001)
	var block := BLOCK.new() as IceBlock
	block.calve(from, Vector2(across, -rise), floor_y, tuning)
	_spawn(block)


## The bolt. Fired level, at the player's height, and only worth firing at a
## player standing on ice -- which is the composition and is checked by
## `tests/test_frost.gd` rather than left to the comment.
func _fire_lock() -> void:
	var bolt := BOLT.new() as EnemyShot
	bolt.size_nes = Vector2(9.0, 9.0)
	var at := global_position + Vector2(
		float(facing()) * BODY_NES.x * 0.6 * tuning.world_scale,
		-BODY_NES.y * 0.5 * tuning.world_scale)
	bolt.launch(at, Vector2(float(facing()), 0.0), LOCK_SPEED_PF, LOCK_DAMAGE,
		tuning)
	bolt.hit.connect(_on_lock_hit)
	_spawn(bolt)


## A bolt that connects coats the player rather than freezing them.
func _on_lock_hit(hurtbox: Hurtbox, _taken: int) -> void:
	var body := hurtbox.get_parent()
	if body is Player:
		(body as Player).slip(LOCK_SLIP_FRAMES, LOCK_SLIP_GRIP)


# --- Helpers --------------------------------------------------------------------

## Whether the player is standing on ice this boss laid. Lock is a wasted turn
## when this is false, and that is the fight's whole structure.
func target_is_on_ice() -> bool:
	if target == null or not is_instance_valid(target):
		return false
	var tile := tuning.tile_size()
	for sheet in _sheets:
		if not is_instance_valid(sheet):
			continue
		var left := sheet.global_position.x
		var right := left + sheet.width_tiles * tile
		if target.global_position.x >= left and target.global_position.x <= right:
			return true
	return false


## The sheets still standing, for the tests.
func sheets() -> Array[IceFloor]:
	var out: Array[IceFloor] = []
	for sheet in _sheets:
		if is_instance_valid(sheet):
			out.append(sheet)
	return out


func _target_x() -> float:
	if target == null or not is_instance_valid(target):
		return arena_centre()
	return target.global_position.x


## Projectiles and sheets are parented to the level, not to the boss: they must
## outlive its death, and a sheet must not travel with it.
func _spawn(node: Node2D) -> void:
	var level := get_parent()
	if level == null:
		node.free()
		return
	level.add_child(node)
