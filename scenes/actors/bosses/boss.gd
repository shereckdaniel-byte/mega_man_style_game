## Base class for a Robot Master.
##
## A boss is an Enemy -- same Health, same Hurtbox, same contact damage, same
## damage-table lookup -- with three things added: an entrance the arena drives,
## a pattern loop that always telegraphs, and a defeat that takes time instead of
## freeing the node on the frame the last point of damage lands.
##
## **Phases, not states.** The player has a StateMachine because its states are
## driven by input and can be entered in almost any order. A boss cannot: it is
## dormant, then entering, then fighting, then dying, and it never goes back.
## A five-value enum says that; a state machine would let an author write a
## transition from Dying to Fighting and nothing would object.
##
## Subclasses supply patterns in `build_patterns()` and implement `tell()` and
## `act()`. They do not decide when to attack, how long the windup is, or whether
## there is one -- BossPattern settles that.
class_name Boss
extends Enemy

## The entrance beam has touched down. The arena fills the energy bar next.
signal intro_landed()
## The defeat sequence is over. The arena awards the weapon on this.
signal defeated(boss: Boss)
## Emitted when a pattern begins its tell, for the tests and for audio.
signal pattern_started(pattern_id: StringName)
## A multi-form boss has finished one form and started the next. `index` is the
## form now being fought, counting from 0.
signal form_changed(index: int)

enum Phase {
	## Off, invisible, untouchable. How a boss waits before the player arrives.
	DORMANT,
	## The entrance beam, falling to the arena floor.
	ENTERING,
	## Landed, bar filling. Still immune, still not attacking.
	POSING,
	## The fight.
	FIGHTING,
	## Exploding. Damage is off and the patterns have stopped.
	DYING,
}

## Every boss has the same 28-tick bar as the player (ARCHITECTURE 5.3).
const BOSS_HP := 28
## Flash time after a hit lands. Long enough to read, short enough that a player
## standing in the right place still out-damages the boss.
const HIT_INVULNERABLE_FRAMES := 24
## Frames per on/off step of the hit flash.
##
## The player's flicker hides the sprite outright, which works because being
## invulnerable is the *player's* state to read. A boss blinking out of
## existence reads as a rendering fault, so this brightens instead: the hit is
## still unmistakable and the boss stays on screen to be aimed at.
const HIT_FLASH_PERIOD := 3
const HIT_FLASH_TINT := Color(2.4, 2.0, 2.0)
## How far above the arena floor the entrance beam starts, in NES px.
const ENTRY_HEIGHT_NES := 160.0
## Beam descent speed, in NES px/frame.
const ENTRY_SPEED_PF := 8.0
## Frames the boss holds still after landing, before the arena fills the bar.
const LAND_PAUSE_FRAMES := 20
## Length of the defeat explosion.
const DEATH_FRAMES := 90
## Frames between bursts during the defeat.
const DEATH_BURST_INTERVAL := 9

## Frames a multi-form boss holds between forms.
##
## Long enough to read as "that was not the end of it" and short enough that the
## player does not go looking for a door. The boss is immune and harmless
## throughout -- the pause is a beat, not a free hit either way.
const FORM_PAUSE_FRAMES := 72
## Frames per flash of the form change, so the hold reads as something happening
## rather than as the game stopping.
const FORM_FLASH_PERIOD := 6

## Which of the eight this is, for GameState's bitmask.
##
## **-1 means this fight records nothing**, which is what a fortress boss and a
## reprise want: they are beaten once per visit and they are not one of the
## eight, so setting a bit for them would either claim a master the player never
## fought or need a second bitmask to keep them out of the first.
@export var boss_index: int = 0
## Weapon awarded on defeat. Empty means this boss awards nothing.
@export var weapon_id: StringName = &""
@export var display_name: String = "Boss"

## How much faster this boss is than the version the numbers were written for.
##
## **It shortens recovery and nothing else.** That is the whole design of the
## knob and it is worth stating why, because the obvious implementation --
## scale every phase -- is wrong in a way that only shows up in play.
##
## `BossPattern` exists to make the telegraph part of the *shape* of an attack:
## tell, then act, then recover, in that order, always. Scaling the tell down
## would take the fight past the point where it can be dodged on sight and into
## the point where it has to be memorised, which is the exact failure that class
## was written to make unrepresentable. Scaling the act down changes what the
## attack *is* -- a faster sweep covers different ground.
##
## Recovery is the one phase that is purely the player's turn. Shortening it
## takes away shooting time and leaves every read the player has learned intact,
## so a reprise at 2.0 is the same fight with half the openings: harder in the
## way a second encounter should be, rather than a different fight wearing the
## first one's sprite.
##
## `MIN_RECOVER_FRAMES` is the floor, because a recovery of zero is a boss with
## no counterplay at all and there would then be no way to hurt it.
@export var aggression: float = 1.0:
	set(value):
		aggression = value
		# Applied on assignment as well as on ready, because the arena hands the
		# boss over *after* its `_ready` has run -- a fortress reprise sets this
		# on a boss that has already built its patterns.
		if not _patterns.is_empty():
			_apply_aggression()

## The shortest recovery any aggression may leave. Two tenths of a second: long
## enough to land a tapped pellet, which is the smallest useful turn.
const MIN_RECOVER_FRAMES := 12

var phase: Phase = Phase.DORMANT
## The player, handed over by the arena. Bosses aim at this rather than
## searching for it, so a boss in a test can be pointed at a stub.
var target: Node2D = null

var _patterns: Array[BossPattern] = []
## Which form is being fought, from 0. Meaningless for the eight, who have one.
var _form := 0
var _form_pause_left := 0
## Every pattern's recovery as its author wrote it, so `aggression` is always
## applied to the original rather than to whatever it was last set to.
var _base_recover := PackedInt32Array()
var _pattern_index := -1
var _phase_frames := 0
## 0 tell, 1 act, 2 recover.
var _step := 0
var _step_frames := 0
var _floor_y := 0.0
## Frames since the entrance beam touched down. Separate from `_phase_frames`,
## which counts from the start of the beam: the landing pause has to be measured
## from the landing, or an arena with a higher ceiling would pose for longer.
var _landed_frames := 0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	max_hp = BOSS_HP
	# A boss is never despawned by the spawn rule -- it is the reason the room
	# exists (ARCHITECTURE 5.5).
	persistent = true
	super()
	health.invulnerable_frames = HIT_INVULNERABLE_FRAMES
	health.immune = true
	_set_hazardous(false)
	visible = false
	_patterns = build_patterns()
	_apply_aggression()
	_rng.randomize()


## Builds the body collider.
##
## Enemy deliberately leaves this to the subclass, because the six archetypes
## want six different boxes -- but every boss wants the same one, its own
## `body_size()`, so it belongs here rather than in each of the eight.
##
## Getting this wrong is invisible until it is baffling. A CharacterBody2D with
## no shape does not fall *onto* the floor, it falls *through* it: the boss
## keeps running its patterns the whole way down, the fight looks live, and the
## only symptom is that its projectiles appear thousands of pixels below the
## room and nothing ever connects.
func setup() -> void:
	var shape := CollisionShape2D.new()
	shape.name = "Body"
	var rect := RectangleShape2D.new()
	rect.size = body_size()
	shape.shape = rect
	# Shapes are centred and an actor's origin is at its feet.
	shape.position.y = -rect.size.y * 0.5
	add_child(shape)


## Subclass hook. Return the patterns this boss can choose between.
##
## Called again on every form change, so a multi-form boss reads `form()` here
## and returns a different set -- which is what makes a second form a different
## fight rather than the same one with a refilled bar.
func build_patterns() -> Array[BossPattern]:
	return []


## How many forms this boss has. One, unless a subclass says otherwise.
##
## **Multi-form lives on the base class rather than in the one boss that needs
## it**, because the alternative is `Bulwark` reaching into `_on_died`,
## `_dead`, `health.immune` and `phase` to fake a death it does not want -- and
## every one of those is bookkeeping this class already owns. What a subclass
## should have to say is "there are two of me", and it does.
func forms() -> int:
	return 1


## The form being fought, from 0.
func form() -> int:
	return _form


func is_changing_form() -> bool:
	return _form_pause_left > 0


## Subclass hook: the form is about to change. Swap art, damage tables, size --
## anything that is a property of *which* boss this now is. `form()` already
## reads as the new one.
func enter_form(_index: int) -> void:
	pass


## Applies `aggression` to the patterns the subclass just built.
##
## After `build_patterns()` rather than inside it, so the eight write their
## numbers once, at the speed they were designed at, and a reprise is a property
## on the node rather than a parameter threaded through every subclass.
##
## **Recomputed from the pattern's original recovery every time**, never from
## the current one. Setting aggression twice is a thing that happens -- the
## arena builds a boss and the stage then configures it -- and scaling in place
## would compound, so a reprise set to 2.0 and then to 2.0 again would come out
## at 4.0 and nothing would say so.
func _apply_aggression() -> void:
	if _base_recover.size() != _patterns.size():
		_base_recover.resize(_patterns.size())
		for i in _patterns.size():
			_base_recover[i] = _patterns[i].recover_frames
	# A nonsense factor is ignored rather than obeyed: the safe reading of "I do
	# not know how fast this should be" is the speed it was written at.
	var factor := aggression if aggression > 0.0 else 1.0
	for i in _patterns.size():
		var scaled := int(round(float(_base_recover[i]) / factor))
		# Never below the floor, and never *above* what the subclass wrote --
		# aggression is a knob for making a boss harder, and a value under 1.0
		# handing a boss a longer opening than its author gave it would be a
		# difficulty setting hiding in a reprise knob.
		_patterns[i].recover_frames = mini(_base_recover[i],
			maxi(scaled, MIN_RECOVER_FRAMES))


## Subclass hook: one frame of windup. `frame` counts from 0.
func tell(_pattern: BossPattern, _frame: int) -> void:
	pass


## Subclass hook: one frame of the attack. `frame` counts from 0.
func act(_pattern: BossPattern, _frame: int) -> void:
	pass


## Subclass hook: one frame of recovery.
func recover(_pattern: BossPattern, _frame: int) -> void:
	pass


## Subclass hook: movement that runs every fighting frame regardless of pattern.
func fight_move(_delta: float) -> void:
	pass


# --- The sequence the arena drives ---------------------------------------------

## Starts the entrance beam. `floor_position` is where the boss should land.
func begin_intro(floor_position: Vector2, p_target: Node2D = null) -> void:
	target = p_target
	_floor_y = floor_position.y
	global_position = Vector2(floor_position.x,
		floor_position.y - ENTRY_HEIGHT_NES * tuning.world_scale)
	visible = true
	phase = Phase.ENTERING
	_phase_frames = 0
	_landed_frames = 0
	velocity = Vector2.ZERO
	# Face the player before the beam is drawn, not when the fight starts.
	# Sprites are authored right-facing, so a boss that only turns in FIGHTING
	# spends its whole entrance and the entire bar fill with its back to a player
	# who -- in every arena in the game -- came in from the left. That is several
	# seconds of the boss's one entrance, looking away.
	_face_target()


## Called by the arena once the energy bar has finished filling.
func begin_fight() -> void:
	if phase == Phase.DYING:
		return
	phase = Phase.FIGHTING
	_phase_frames = 0
	health.immune = false
	_set_hazardous(true)
	_choose_pattern()


func is_fighting() -> bool:
	return phase == Phase.FIGHTING


func current_pattern() -> BossPattern:
	if _pattern_index < 0 or _pattern_index >= _patterns.size():
		return null
	return _patterns[_pattern_index]


func patterns() -> Array[BossPattern]:
	return _patterns


## Which of tell/act/recover the current pattern is in.
func pattern_step() -> int:
	return _step


func pattern_step_frames() -> int:
	return _step_frames


## Fixes the pattern order, for a test that needs the fight to be repeatable.
func seed_rng(seed_value: int) -> void:
	_rng.seed = seed_value


# --- Frame ---------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	_phase_frames += 1
	match phase:
		Phase.DORMANT:
			return
		Phase.ENTERING:
			_face_target()
			_process_entrance(delta)
		Phase.POSING:
			health.tick()
			# Kept up through the pose as well: the player is free to move while
			# the bar fills, and a boss frozen mid-turn reads as a bug rather
			# than as a boss holding still.
			_face_target()
			_apply_gravity(delta)
			move_and_slide()
		Phase.FIGHTING:
			health.tick()
			contact.tick()
			_face_target()
			if is_changing_form():
				# Still FIGHTING -- the room stays sealed and the bar stays up --
				# but nothing acts and nothing lands. Gravity keeps running so a
				# boss caught mid-leap comes down rather than hanging there.
				_process_form_change()
				_apply_gravity(delta)
				move_and_slide()
			else:
				fight_move(delta)
				_run_pattern()
				_apply_gravity(delta)
				move_and_slide()
				_update_hit_flash()
		Phase.DYING:
			_process_death()


## The entrance beam falls straight down and stops at the arena floor. It does
## not use gravity: a beam that accelerated would land at a different time
## depending on the arena's ceiling height, and the bar fill is timed off this.
func _process_entrance(delta: float) -> void:
	var step := tuning.px_s(ENTRY_SPEED_PF) * delta
	global_position.y = minf(global_position.y + step, _floor_y)
	if global_position.y < _floor_y:
		return
	global_position.y = _floor_y
	_landed_frames += 1
	if _landed_frames < LAND_PAUSE_FRAMES:
		return
	phase = Phase.POSING
	_phase_frames = 0
	intro_landed.emit()


func _process_death() -> void:
	if _phase_frames % DEATH_BURST_INTERVAL == 0:
		var level := get_parent()
		if level != null:
			var spread := body_size() * 0.6
			var at := global_position + Vector2(
				_rng.randf_range(-spread.x, spread.x),
				_rng.randf_range(-spread.y, -1.0))
			DeathExplosion.burst(level, at)
	if _phase_frames < DEATH_FRAMES:
		return
	phase = Phase.DORMANT
	visible = false
	defeated.emit(self)
	queue_free()


func _run_pattern() -> void:
	var pattern := current_pattern()
	if pattern == null:
		return
	_step_frames += 1
	match _step:
		0:
			tell(pattern, _step_frames - 1)
			if _step_frames >= pattern.tell_frames:
				_advance_step(1, pattern.act_anim)
		1:
			act(pattern, _step_frames - 1)
			if _step_frames >= pattern.act_frames:
				_advance_step(2, pattern.recover_anim)
		2:
			recover(pattern, _step_frames - 1)
			if _step_frames >= pattern.recover_frames:
				_choose_pattern()


func _advance_step(next_step: int, anim: StringName) -> void:
	_step = next_step
	_step_frames = 0
	_play(anim)


## Weighted pick, never the same pattern twice running when there is a choice.
## A repeat is not wrong, but back-to-back repeats are what make a fight read as
## broken rather than random.
func _choose_pattern() -> void:
	_step = 0
	_step_frames = 0
	if _patterns.is_empty():
		_pattern_index = -1
		return

	var total := 0.0
	for i in _patterns.size():
		if i != _pattern_index or _patterns.size() == 1:
			total += _patterns[i].weight
	if total <= 0.0:
		_pattern_index = (_pattern_index + 1) % _patterns.size()
	else:
		var roll := _rng.randf() * total
		for i in _patterns.size():
			if i == _pattern_index and _patterns.size() > 1:
				continue
			roll -= _patterns[i].weight
			if roll <= 0.0:
				_pattern_index = i
				break

	var pattern := current_pattern()
	if pattern != null:
		_play(pattern.tell_anim)
		pattern_started.emit(pattern.id)


## Brightens the boss while its i-frames run.
##
## Without this the energy bar is the only thing that says a hit landed, and the
## bar is in the corner while the player is looking at the boss. A fight where
## you cannot tell your shots are connecting reads as a broken hitbox -- which,
## twice in this project, is exactly what it was.
## A boss taking a hit, over the top of `Enemy`'s. The fight is long and the
## difference between "that landed" and "that did not" is most of what the
## player is reading.
func _on_damaged(info: DamageInfo, taken: int) -> void:
	super(info, taken)
	Sfx.play(&"boss_hit", -3.0)


func _update_hit_flash() -> void:
	if sprite == null:
		return
	var left := health.invulnerable_frames_left()
	if left <= 0:
		if sprite.modulate != Color.WHITE:
			sprite.modulate = Color.WHITE
		return
	var on := (left / HIT_FLASH_PERIOD) % 2 == 0
	sprite.modulate = HIT_FLASH_TINT if on else Color.WHITE


func _face_target() -> void:
	if target == null or not is_instance_valid(target):
		return
	var wanted := 1 if target.global_position.x >= global_position.x else -1
	if sprite != null:
		sprite.flip_h = wanted < 0


## Which way the boss is facing, as +1 or -1. Read from the sprite so there is
## one answer rather than a field that can drift out of step with the art.
func facing() -> int:
	if sprite != null and sprite.flip_h:
		return -1
	return 1


## --- The arena floor ------------------------------------------------------------
##
## Where the fight happens, handed over by `BossArena` through `set_arena_span`.
## It lives here rather than in each boss because all three of the first three
## wanted it and two of them had written it out: Tide needed a centre so Spout
## knew which way to leap, Arc needed a span so Rail knew where to stop and
## Curtain knew what to divide, and Rust needs one to place its patches. Three
## copies of a fact is the same argument `StageRoster` was extracted on.

var arena_left := 0.0
var arena_right := 0.0


## Called by the arena, by name -- see BossArena. Ordered rather than trusted,
## so a stage that hands over its edges the other way round still gets a span.
func set_arena_span(left: float, right: float) -> void:
	arena_left = minf(left, right)
	arena_right = maxf(left, right)


## The floor span, or a span around the boss when there is no arena -- which is
## what a bare test has, and returning a zero-width span there would put every
## column of a pattern on the same pixel.
func arena_span() -> Vector2:
	if is_equal_approx(arena_left, arena_right):
		var half := 12.0 * tuning.tile_size()
		return Vector2(global_position.x - half, global_position.x + half)
	return Vector2(arena_left, arena_right)


func arena_centre() -> float:
	var span := arena_span()
	return (span.x + span.y) * 0.5


## The y the arena's floor sits at -- where the entrance beam stopped.
##
## Public because a boss that leaves the ground needs it and cannot use its own
## position for it. The first four never did: Tide leaps and comes back down
## under gravity, and the other three keep their feet on the floor, so
## `global_position.y` *was* the floor line and nothing had to say so. Gale
## hovers, and for a hovering boss that identity is quietly false -- its
## patterns would place a floor slab at whatever height the boss happened to be.
func arena_floor_y() -> float:
	return _floor_y


## Keeps the boss in the room, whatever a pattern asks for.
##
## **A bound, not a tuned number, and that distinction is the lesson from M5.**
## Tide left the arena through the ceiling because its leap velocity was chosen
## to look right rather than derived, and the fix was a smaller number -- which
## works until the next pattern, on the next boss, picks the wrong one again.
## Arc's Curtain did the same thing sideways: 56 frames of act phase at a walking
## speed nobody thought of as travel, and Arc was 900 px outside the arena still
## fighting.
##
## So the constraint lives where it can be stated once, for every boss: whatever
## a pattern does with `velocity`, the boss is inside the span at the end of the
## frame. A pattern is then free to be wrong about its own arithmetic without
## taking the fight off the screen.
func hold_inside_arena() -> void:
	var span := arena_span()
	var margin := body_size().x * 0.5
	var low := span.x + margin
	var high := span.y - margin
	if low >= high:
		return
	if global_position.x < low:
		global_position.x = low
		velocity.x = maxf(velocity.x, 0.0)
	elif global_position.x > high:
		global_position.x = high
		velocity.x = minf(velocity.x, 0.0)


func _play(anim: StringName) -> void:
	if anim == &"" or sprite == null or sprite.sprite_frames == null:
		return
	if not sprite.sprite_frames.has_animation(anim):
		return
	if sprite.animation == anim:
		return
	sprite.animation = anim
	sprite.play(anim)


func _apply_gravity(delta: float) -> void:
	if not affected_by_gravity:
		return
	velocity.y = minf(
		velocity.y + tuning.px_s2(tuning.gravity_pf) * delta,
		tuning.px_s(tuning.terminal_velocity_pf))


## Turns the contact hitbox on and off. A boss that is not fighting must not
## hurt a player who walks into it during the entrance -- the player is frozen
## through that and could not avoid it.
func _set_hazardous(value: bool) -> void:
	if contact == null:
		return
	contact.monitoring = value
	if not value:
		contact.rearm()


## Ends one form and begins the next: refill the bar, rebuild the patterns, hold
## for a beat.
##
## The bar refilling is the whole trick and it is free -- `Health.refill` emits
## `changed`, which is what the HUD's boss bar already listens to, so the second
## form fills the same bar the first one emptied with nothing wired specially.
func _advance_form() -> void:
	_form += 1
	_form_pause_left = FORM_PAUSE_FRAMES
	velocity = Vector2.ZERO
	# The bar, which is the whole trick and was missing from the first version
	# of this method while its own docstring described it. `refill` emits
	# `changed`, which the HUD's boss bar already listens to, so the second form
	# fills the bar the first one emptied with nothing wired specially.
	health.refill()
	health.immune = true
	_set_hazardous(false)
	enter_form(_form)
	# Rebuilt rather than reused: `build_patterns` reads `form()`, so this is
	# where a second form becomes a different fight. The recovery cache goes with
	# them, or the new patterns would be scaled against the old ones' numbers.
	_patterns = build_patterns()
	_base_recover.clear()
	_apply_aggression()
	_pattern_index = -1
	_step = 0
	_step_frames = 0
	Sfx.play(&"boss_form")
	form_changed.emit(_form)


## One frame of the hold between forms.
func _process_form_change() -> void:
	_form_pause_left -= 1
	if sprite != null:
		# Flashing rather than invisible: a boss that blinks out reads as a
		# rendering fault, which is the same call `HIT_FLASH_TINT` makes.
		var lit := (_form_pause_left / FORM_FLASH_PERIOD) % 2 == 0
		sprite.modulate = HIT_FLASH_TINT if lit else Color.WHITE
	if _form_pause_left > 0:
		return
	if sprite != null:
		sprite.modulate = Color.WHITE
	health.immune = false
	_set_hazardous(true)
	_choose_pattern()


## The long defeat, replacing Enemy's free-on-death. Overriding rather than
## reaching into Enemy: the base connects `_on_died` to Health, and virtual
## dispatch means this runs instead without the base needing to know bosses
## exist.
## The last point of damage. For a boss with another form in it, this is not a
## death -- it is the end of a round.
func _on_died(_info: DamageInfo) -> void:
	if phase == Phase.DYING:
		return
	Sfx.play(&"boss_die")
	if _form + 1 < forms():
		_advance_form()
		return
	phase = Phase.DYING
	_phase_frames = 0
	if sprite != null:
		sprite.modulate = Color.WHITE
	# Enemy's own flag, so `is_dead()` tells the truth from the frame the last
	# point of damage lands rather than from the end of the explosion.
	_dead = true
	health.immune = true
	_set_hazardous(false)
	velocity = Vector2.ZERO
	died.emit(self)
