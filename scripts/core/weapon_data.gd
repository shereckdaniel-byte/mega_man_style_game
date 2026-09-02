## One weapon: what it costs, how many it allows on screen, and what it fires.
##
## One resource per weapon in `resources/weapons/`, so adding a weapon is a
## `.tres` and a projectile script rather than a branch in the player.
##
## **This holds a `Script`, not the `PackedScene`** that ARCHITECTURE section 5.6
## sketched. Every projectile in this project is a bare script instantiated with
## `.new()` -- there is no `.tscn` for a buster pellet, because a pellet is one
## Area2D with a rectangle and building that in code is shorter than a scene
## file. A `PackedScene` field would mean authoring eight scenes whose only
## content is a node the script creates anyway.
class_name WeaponData
extends Resource

## Matches the key used in every DamageTable and in WeaponManager's ammo book.
@export var id: StringName = &""
@export var display_name: String = ""

## Instantiated with `.new()` and expected to extend WeaponShot.
@export var projectile_script: Script

## Ammo is a 28-tick bar like health, so one tick is one shot at cost 1.
@export var ammo_max: int = 28
@export var ammo_cost: int = 1

## Live projectiles allowed at once. The buster's 3 is what caps its damage over
## time, since this game has no charge shot to cap instead.
@export var max_on_screen: int = 3
## Frames the player must wait between shots. 0 means the on-screen cap is the
## only limiter, which is how the buster behaves.
@export var fire_cooldown_frames: int = 0

## Damage before the target's DamageTable gets a say. A weakness is a bigger
## number in that table, not a multiplier here (see DamageTable).
@export var damage: int = 1
@export var flags: int = DamageInfo.NONE

## The weapon's own colours: [body, highlight]. The player's hue-rotation shader
## measures its shift from the buster's first entry to this weapon's, so this
## says what colour the weapon *is* and nothing has to also say what colour it
## is relative to (SPRITES.md section 3).
##
## Author it in a `.tres` as `Array[Color]([Color(...), ...])`. A
## `PackedColorArray` there looks right, saves without complaint, and loads as an
## **empty** array -- the shipped weapons all had one, every palette was silently
## empty, and the only symptom was a character who never changed colour.
@export var palette: Array[Color] = []
@export var icon: Texture2D

## Free-form per-weapon numbers, read by that weapon's projectile script.
## Keeps speed/turn-rate/arc constants in the resource with the rest of the
## weapon rather than hard-coded in the script, without giving WeaponData a
## field for every weapon's private business.
@export var tuning: Dictionary = {}


func get_number(key: StringName, fallback: float) -> float:
	return float(tuning.get(key, fallback))
