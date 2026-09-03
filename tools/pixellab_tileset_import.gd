## Command-line entry point for the PixelLab tileset importer.
##
##   godot --headless --script res://tools/pixellab_tileset_import.gd
##
## Exits non-zero if any tileset failed to import, so CI can gate on it.
extends SceneTree


func _init() -> void:
	quit(0 if PixelLabTilesetImporter.new().run() else 1)
