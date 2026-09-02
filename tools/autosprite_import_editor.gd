@tool
## Editor entry point for the AutoSprite importer: File > Run with this script
## open. Identical to running tools/autosprite_import.gd from the command line.
extends EditorScript


func _run() -> void:
	AutoSpriteImporter.new().run()
