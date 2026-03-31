extends Node

# Temporary helper — you must run this script once so _ready() fires:
#   • Main scene: select the root node → attach this script in the Inspector, OR
#   • Project → Project Settings → Autoload → add this file (any Node Name), run F5.
# Then open Window → Output to read the instructions.

func _ready() -> void:
	print("=== AUTOLOAD SETUP INSTRUCTIONS ===")
	print("1. Go to Project (top menu) > Project Settings")
	print("2. In the left sidebar, click on 'Globals'")
	print("3. Then click on the 'Autoload' sub-tab (it may be under Globals)")
	print("4. At the bottom, click the folder icon")
	print("5. Navigate to res://autoload/game_manager.gd")
	print("6. Set Node Name to: GameManager")
	print("7. Click Add")
	print("8. Repeat for res://autoload/meta_progression.gd with Node Name: MetaProgression")
	print("===================================")
	print("After adding both, refresh FileSystem and press F5 again.")
	# These two .gd files should already exist in res://autoload/ (add them as autoloads in step 3–8).
	print("GameManager and MetaProgression files are present.")
