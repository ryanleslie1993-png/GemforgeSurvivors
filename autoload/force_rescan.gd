@tool
extends Node

# Runs in the editor when this node exists (e.g. as a temporary autoload). EditorInterface
# is not available during normal F5 game play, so we only call it when is_editor_hint is true.


func _ready() -> void:
	print("=== FORCING FILESYSTEM RESCAN ===")
	if Engine.is_editor_hint():
		var fs = EditorInterface.get_resource_filesystem()
		if fs and not fs.is_scanning():
			fs.scan()
			print("Rescan started! Wait 3 seconds then press F5 again.")
		else:
			print("Rescan already running or EditorInterface not available in play mode.")
	else:
		print("Rescan already running or EditorInterface not available in play mode.")
		print("Tip: Fully quit Godot and reopen the project, then press F5.")
