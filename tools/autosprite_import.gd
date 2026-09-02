## Command-line entry point for the AutoSprite importer.
##
##   godot --headless --script res://tools/autosprite_import.gd
##
## Exits non-zero if any character failed to import, so CI can gate on it.
extends SceneTree


func _init() -> void:
	quit(0 if AutoSpriteImporter.new().run() else 1)
