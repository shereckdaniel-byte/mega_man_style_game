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

## Which of the eight this is, for GameState's bitmask.
@export var boss_index: int = 0
## Weapon awarded on defeat. Empty means this boss awards nothing.
@export var weapon_id: StringName = &""
@export var display_name: String = "Boss"

var phase: Phase = Phase.DORMANT
## The player, handed over by the arena. Bosses aim at this rather than
## searching for it, so a boss in a test can be pointed at a stub.
var target: Node2D = null

var _patterns: Array[BossPattern] = []
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
func build_patterns() -> Array[BossPattern]:
	return []


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
			_process_entrance(delta)
		Phase.POSING:
			health.tick()
			_apply_gravity(delta)
			move_and_slide()
		Phase.FIGHTING:
			health.tick()
			contact.tick()
			_face_target()
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


## The long defeat, replacing Enemy's free-on-death. Overriding rather than
## reaching into Enemy: the base connects `_on_died` to Health, and virtual
## dispatch means this runs instead without the base needing to know bosses
## exist.
func _on_died(_info: DamageInfo) -> void:
	if phase == Phase.DYING:
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
