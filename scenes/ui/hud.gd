## In-game HUD: the player's energy, the selected weapon's ammo, and the boss
## bar during a fight.
##
## A CanvasLayer so it does not scroll with the room, and so a stage only has to
## add it and hand it the player.
##
## Three bars in a row from the left, in the original's order: player, weapon,
## boss. The weapon bar is hidden while the buster is selected, because the
## buster has no ammo and a permanently full bar next to a draining one is
## noise. The boss bar is hidden outside a fight for the same reason.
class_name Hud
extends CanvasLayer

## Inset from the top-left corner, in NES pixels.
const MARGIN_NES := Vector2(12.0, 12.0)
## Gap between bars, in NES pixels.
const BAR_GAP_NES := 10.0

const WEAPON_FILL := Color(1.0, 0.82, 0.36)
const BOSS_FILL := Color(1.0, 0.45, 0.42)

var energy: EnergyBar
var weapon: EnergyBar
var boss: EnergyBar

var _scale := 4.5
var _weapons: Node = null
var _boss_health: Health = null


func _ready() -> void:
	layer = 10
	var autoload := get_node_or_null(^"/root/Tuning")
	if autoload != null:
		_scale = autoload.player.world_scale

	energy = _add_bar("PlayerEnergy", 0)
	weapon = _add_bar("WeaponAmmo", 1)
	weapon.fill_colour = WEAPON_FILL
	weapon.visible = false
	boss = _add_bar("BossEnergy", 2)
	boss.fill_colour = BOSS_FILL
	boss.visible = false

	_weapons = get_node_or_null(^"/root/WeaponManager")
	if _weapons != null:
		_weapons.weapon_changed.connect(_on_weapon_changed)
		_weapons.ammo_changed.connect(_on_ammo_changed)
		_on_weapon_changed(_weapons.current)


## Points the HUD at a player. Kept separate from _ready so a stage can build
## the HUD before or after the player exists.
func track(player: Player) -> void:
	energy.track(player.health)
	# A respawn refills the bar off-screen; animating it back up would run the
	# refill while the player is already standing there.
	player.respawned.connect(func() -> void: energy.snap_to(player.health.current))


## Shows the boss bar and fills it from empty, which is the intro beat.
func show_boss_bar(health: Health) -> void:
	_boss_health = health
	boss.visible = true
	boss.track(health, true)


func hide_boss_bar() -> void:
	if _boss_health != null:
		boss.untrack(_boss_health)
		_boss_health = null
	boss.visible = false


func _add_bar(bar_name: String, column: int) -> EnergyBar:
	var bar := EnergyBar.new()
	bar.name = bar_name
	var step := EnergyBar.SEGMENT_NES.x + EnergyBar.BORDER_NES * 2.0 + BAR_GAP_NES
	bar.position = (MARGIN_NES + Vector2(float(column) * step, 0.0)) * _scale
	add_child(bar)
	return bar


func _on_weapon_changed(weapon_id: StringName) -> void:
	if _weapons == null:
		return
	# The buster has no ammo, so it gets no bar. Everything else does.
	if weapon_id == _weapons.BUSTER:
		weapon.visible = false
		return
	weapon.visible = true
	weapon.ticks = _weapons.max_ammo(weapon_id)
	weapon.snap_to(_weapons.get_ammo(weapon_id))


func _on_ammo_changed(weapon_id: StringName, amount: int) -> void:
	if _weapons == null or weapon_id != _weapons.current:
		return
	weapon.set_value(amount)
