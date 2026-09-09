## A capsule an enemy left behind: health, weapon energy, a life, or an E-tank.
##
## Until now nothing in the game called `GameState.add_etank()`, so the E-TANK
## row in the pause menu could only ever read x0, and there was no way to recover
## a single hit point inside a stage. That made the game harder than the design
## intends in a way nobody chose -- ARCHITECTURE section 5.3 has specified "small
## health pickup 2, large 10" since M0 and section 5.5 says the respawn rule "is
## what makes farming health drops possible", which is a sentence about a feature
## that did not exist.
##
## ### It falls, and that is the whole reason it is a body
##
## A capsule spawns where the enemy died -- often in the air, because half the
## archetypes fly or hop -- and drops to the floor. A pickup that hung in the air
## where a Gullbot happened to be shot would be unreachable about as often as it
## was convenient. So this is a `CharacterBody2D` that falls, with
## `collision_layer = 0`: it collides *with* the world without anything colliding
## with it, so a capsule can never block a jump or a shot.
##
## The touch is a child `Area2D` on the `pickup` layer (ARCHITECTURE section 4,
## layer 10, reserved for exactly this and unused until now). Separating them is
## not ceremony: the body's shape is what lands on the floor and the area's shape
## is what the player has to reach, and the second wants to be more generous than
## the first.
##
## ### It expires, blinking first
##
## As in the original. Two reasons beyond fidelity: a room that accumulates every
## capsule ever dropped stops reading as a room, and an expiry is what stops
## "farm the same spawn marker" from being strictly better than playing. The
## blink is the fair-warning half -- a capsule that vanished without notice would
## read as a bug, which is the same argument `PhaseBlock` makes about its warn
## frames.
class_name Pickup
extends CharacterBody2D

enum Kind {
	HEALTH_SMALL,
	HEALTH_LARGE,
	AMMO_SMALL,
	AMMO_LARGE,
	ONE_UP,
	ETANK,
}

## What each kind restores. Health numbers are ARCHITECTURE section 5.3's;
## weapon energy mirrors them because a weapon bar is the same 28 ticks.
const SMALL_AMOUNT := 2
const LARGE_AMOUNT := 10

## Body size and the reach of the touch box, in NES px. The touch box is wider
## than the capsule so walking past one collects it, rather than requiring the
## player to stand on it.
const BODY_NES := Vector2(8.0, 8.0)
const TOUCH_NES := Vector2(16.0, 16.0)

## How long a capsule lasts, and how long it blinks before it goes.
const LIFETIME_FRAMES := 480
const BLINK_FRAMES := 120
## Frames per on/off step of the blink. Matches `Boss.HIT_FLASH_PERIOD`'s job:
## fast enough to read as a warning, slow enough to see.
const BLINK_PERIOD := 6

## Upward kick on spawn, in NES px/frame, so a capsule pops out of the enemy
## rather than appearing to be dropped through the floor it was standing on.
const POP_SPEED_PF := 1.6

const HEALTH_COLOUR := Color(0.42, 0.92, 0.52)
const AMMO_COLOUR := Color(1.0, 0.82, 0.36)
const ONE_UP_COLOUR := Color(0.55, 0.80, 1.0)
const ETANK_COLOUR := Color(1.0, 0.55, 0.62)
const SHELL_COLOUR := Color(0.10, 0.12, 0.18)

## Emitted when a player takes it. `kind` rather than the node, because by the
## time a listener runs the node is on its way out.
signal collected(kind: Kind)

@export var kind: Kind = Kind.HEALTH_SMALL

var _tuning: PlayerTuning
var _frames := 0
var _touch: Area2D
var _taken := false
var _spawn_position := Vector2.ZERO


## Spawns one into `parent` at `at`. The convenience `DeathExplosion.burst` has,
## for the same reason: the caller is a dying enemy and should not have to know
## how a capsule is assembled.
##
## **The add is deferred, and the reason is a log rather than a crash.** A
## capsule is dropped from `Enemy._on_died`, which runs inside a `Hitbox` area
## callback -- while the physics server is flushing its queries -- and `_ready`
## builds two collision shapes there. The server refuses to set each new shape's
## `disabled` and `one_way_collision` flags in that window and says so: **nine
## "Can't change this state while flushing queries" errors per capsule.**
##
## Measured rather than assumed, because the obvious conclusion is wrong: those
## flags default to what they were being set to, so the capsule is built
## correctly, falls, lands and is collected either way. Reverting this line and
## re-running the tests passes every one of them. What it costs is a console
## that prints nine errors every time an enemy dies, which is how a real error
## goes unnoticed. `DeathExplosion` is spawned from the same line and never
## tripped it, carrying no collider at all.
##
## Worth recording how it was found. Every test in `tests/test_pickups.gd`
## passed: they drop capsules from test code, which is not inside a physics
## callback. The playthrough bot killed one enemy.
static func drop(parent: Node, at: Vector2, of_kind: Kind) -> Pickup:
	if parent == null:
		return null
	var item := Pickup.new()
	item.kind = _usable_kind(of_kind, parent)
	# Carried rather than assigned, because a node outside the tree has no global
	# position to set. Same shape as `FacetMirror.plant` and `FocusSpot.sweep`.
	item._spawn_position = at
	parent.add_child.call_deferred(item)
	return item


## A weapon capsule dropped before the player owns a weapon, turned into health.
##
## **A capsule nobody can use is not a capsule, it is litter that looks like a
## reward.** Weapon energy is 16% of the drop table and there is nothing at all
## for it to fill until the first boss falls -- so for the whole of a player's
## first stage, one drop in six was a thing that could be walked over and never
## picked up. `_refill` fixes the case where a weapon exists and a different one
## is equipped; this fixes the case where none exists yet.
##
## Health rather than nothing, and the small/large size is kept: the roll said
## "this kill was worth something", and the fix should not quietly make the
## early game stingier than the drop table says it is.
static func _usable_kind(of_kind: Kind, parent: Node) -> Kind:
	if of_kind != Kind.AMMO_SMALL and of_kind != Kind.AMMO_LARGE:
		return of_kind
	var weapons := parent.get_node_or_null(^"/root/WeaponManager")
	if weapons == null:
		return of_kind
	for id: StringName in weapons.unlocked():
		if id != weapons.BUSTER:
			return of_kind
	return Kind.HEALTH_SMALL if of_kind == Kind.AMMO_SMALL else Kind.HEALTH_LARGE


func _ready() -> void:
	var autoload := get_node_or_null(^"/root/Tuning")
	_tuning = autoload.player if autoload != null else PlayerTuning.new()

	# Layer 0: it falls through nothing and nothing falls over it.
	collision_layer = 0
	collision_mask = Layers.mask([Layers.WORLD, Layers.PLATFORM])
	motion_mode = CharacterBody2D.MOTION_MODE_GROUNDED

	var body := CollisionShape2D.new()
	var body_rect := RectangleShape2D.new()
	body_rect.size = BODY_NES * _tuning.world_scale
	body.shape = body_rect
	add_child(body)

	_touch = Area2D.new()
	_touch.name = "Touch"
	_touch.collision_layer = Layers.bit(Layers.PICKUP)
	_touch.collision_mask = Layers.bit(Layers.PLAYER_BODY)
	var touch_shape := CollisionShape2D.new()
	var touch_rect := RectangleShape2D.new()
	touch_rect.size = TOUCH_NES * _tuning.world_scale
	touch_shape.shape = touch_rect
	_touch.add_child(touch_shape)
	_touch.body_entered.connect(_on_body_entered)
	add_child(_touch)

	global_position = _spawn_position
	velocity = Vector2(0.0, -_tuning.px_s(POP_SPEED_PF))
	z_index = 20
	queue_redraw()


func frames_left() -> int:
	return maxi(LIFETIME_FRAMES - _frames, 0)


func is_blinking() -> bool:
	return frames_left() <= BLINK_FRAMES


func _physics_process(delta: float) -> void:
	_frames += 1
	if _frames >= LIFETIME_FRAMES:
		queue_free()
		return
	if is_on_floor():
		velocity.y = 0.0
	else:
		# The same fall an enemy has, terminal velocity included, so a capsule
		# dropped from the top of a shaft does not outrun the player chasing it.
		velocity.y = minf(
			velocity.y + _tuning.px_s2(_tuning.gravity_pf) * delta,
			_tuning.px_s(_tuning.terminal_velocity_pf))
	move_and_slide()
	if is_blinking():
		queue_redraw()


func _on_body_entered(body: Node2D) -> void:
	if _taken or not (body is Player):
		return
	if not _apply(body as Player):
		# Refused rather than wasted. A capsule the player cannot use stays on
		# the floor for when they can -- the same decision `PauseMenu.use_etank`
		# makes about spending an E-tank at full health, and for the same reason:
		# consuming it here is a mistake the game should not let them make.
		return
	_taken = true
	collected.emit(kind)
	queue_free()


## Applies this capsule's effect. False means it was not used and the capsule
## should stay where it is.
func _apply(player: Player) -> bool:
	match kind:
		Kind.HEALTH_SMALL:
			return player.health.heal(SMALL_AMOUNT) > 0
		Kind.HEALTH_LARGE:
			return player.health.heal(LARGE_AMOUNT) > 0
		Kind.AMMO_SMALL:
			return _refill(SMALL_AMOUNT)
		Kind.AMMO_LARGE:
			return _refill(LARGE_AMOUNT)
		Kind.ONE_UP:
			var state := _game_state()
			if state == null:
				return false
			state.lives += 1
			state.lives_changed.emit(state.lives)
			return true
		Kind.ETANK:
			var tanks := _game_state()
			# An E-tank is banked, not spent, so unlike health it is taken at
			# full health -- it is only refused when the bank is full.
			return tanks != null and tanks.add_etank()
	return false


## Tops up the weapon that needs it most.
##
## **It used to top up only the *equipped* weapon, and that was a bug that made
## a sixth of all drops uncollectable.** The buster has no ammo and never runs
## dry, so a capsule touched while the buster is equipped was refused -- and the
## buster is what the player is holding for most of the game, and all of it
## before the first weapon-get. A player walked over yellow capsules and nothing
## happened, forever, with no way to tell why.
##
## The old behaviour had an argument -- the capsule waits for you to switch to
## the weapon that needs it, so *which* weapon it feeds is a choice you make.
## That is a real choice and it is not worth the cost: the player has to already
## know the rule to see the choice, and if they do not, the game looks broken.
## So the capsule feeds whichever unlocked weapon has the least energy, which is
## what a player switching deliberately would almost always have picked anyway.
##
## Ties go to the earliest in `unlocked()` order, which is boss order, so the
## result is stable rather than dependent on dictionary iteration.
func _refill(amount: int) -> bool:
	var weapons := get_node_or_null(^"/root/WeaponManager")
	if weapons == null:
		return false
	var wanted := _neediest_weapon(weapons)
	if wanted == &"":
		return false
	weapons.refill(wanted, amount)
	return true


## The unlocked weapon furthest from full, or `&""` when every weapon is full
## and there is nothing for a capsule to do.
##
## The buster is skipped because it has no bar to fill. It is in `unlocked()` --
## it is a weapon the player has -- so this is a real exclusion rather than an
## accident of the list.
func _neediest_weapon(weapons: Node) -> StringName:
	var best: StringName = &""
	var lowest := 0
	for id: StringName in weapons.unlocked():
		if id == weapons.BUSTER:
			continue
		var room: int = weapons.max_ammo(id) - weapons.get_ammo(id)
		if room > lowest:
			lowest = room
			best = id
	return best


func _game_state() -> Node:
	return get_node_or_null(^"/root/GameState")


func colour() -> Color:
	match kind:
		Kind.HEALTH_SMALL, Kind.HEALTH_LARGE:
			return HEALTH_COLOUR
		Kind.AMMO_SMALL, Kind.AMMO_LARGE:
			return AMMO_COLOUR
		Kind.ONE_UP:
			return ONE_UP_COLOUR
		Kind.ETANK:
			return ETANK_COLOUR
	return HEALTH_COLOUR


## **Four silhouettes, not four colours.** Size says small or large and shape
## says which kind: health is a square, weapon energy a wide flat bar, a life a
## disc, an E-tank a tall canister. Colour agrees with the shape and carries
## nothing on its own.
##
## That is the rule `PhaseBlock` set for the disappearing blocks -- "a shape
## difference rather than a colour one, which is a down-payment on the
## colourblind palette M8 names" -- and six capsules told apart only by hue
## would have been the same mistake one system later. It costs four lines here
## and nothing at M8.
func _draw() -> void:
	if is_blinking() and (_frames / BLINK_PERIOD) % 2 == 1:
		return
	var scale := _tuning.world_scale
	var unit := BODY_NES.x * scale
	var large := kind in [Kind.HEALTH_LARGE, Kind.AMMO_LARGE, Kind.ONE_UP, Kind.ETANK]
	var body := unit * (1.0 if large else 0.66)
	var tint := colour()
	var edge := maxf(body * 0.16, 1.5)

	match kind:
		Kind.ONE_UP:
			# A disc: the one that is neither health nor ammo, and the only
			# round thing on screen.
			draw_circle(Vector2.ZERO, body * 0.5, SHELL_COLOUR)
			draw_circle(Vector2.ZERO, body * 0.5 - edge, tint)
		Kind.ETANK:
			# Tall and narrow, like the canister it is.
			_capsule(Vector2(body * 0.62, body * 1.15), tint, edge)
		Kind.AMMO_SMALL, Kind.AMMO_LARGE:
			# Wide and flat, so it is not a health square seen in bad light.
			_capsule(Vector2(body * 1.25, body * 0.55), tint, edge)
		_:
			_capsule(Vector2(body, body), tint, edge)


func _capsule(size: Vector2, tint: Color, edge: float) -> void:
	var rect := Rect2(-size * 0.5, size)
	draw_rect(rect, SHELL_COLOUR)
	draw_rect(rect.grow(-edge), tint)
