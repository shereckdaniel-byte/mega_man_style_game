## Holds the live PlayerTuning resource.
##
## Kept as an autoload so a dev build can hot-reload constants without reloading
## the scene, and so tests can construct a throwaway instance without a player.
extends Node

const DEFAULT_PATH := "res://resources/player_tuning.tres"

var player: PlayerTuning


func _ready() -> void:
	player = load(DEFAULT_PATH) as PlayerTuning if ResourceLoader.exists(DEFAULT_PATH) else null
	if player == null:
		# No .tres authored yet: the script defaults are the source of truth.
		player = PlayerTuning.new()


## Re-reads the tuning resource from disk. Bound to a debug key in dev builds.
func reload() -> void:
	if not ResourceLoader.exists(DEFAULT_PATH):
		return
	var fresh := ResourceLoader.load(DEFAULT_PATH, "PlayerTuning", ResourceLoader.CACHE_MODE_IGNORE)
	if fresh is PlayerTuning:
		player = fresh
