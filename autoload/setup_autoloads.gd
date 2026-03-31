extends Node

# =============================================================================
# TEMPORARY SETUP HELPER — delete this script (and its scene if any) after autoloads work.
# =============================================================================
#
# What is an autoload?
#   A script that Godot loads once when the game starts and keeps alive everywhere.
#   You can access it from any scene by its singleton name (e.g. GameManager).
#
# How to add GameManager and MetaProgression manually:
#   1. In the Godot editor menu: Project → Project Settings…
#   2. Open the "Autoload" tab (left sidebar).
#   3. Next to "Path", click the folder icon and pick:
#        res://autoload/game_manager.gd
#   4. Set "Node Name" to: GameManager  (must match exactly; this is how you type GameManager in code)
#   5. Click "Add".
#   6. Repeat for MetaProgression with path: res://autoload/meta_progression.gd
#   7. Click "Close". Save the project if prompted.
#
# Tip: After adding, run the game (F5). You should see the print lines from each script’s _ready().
# =============================================================================

# This is just a temporary helper. Delete it after we add the real autoloads.


func _ready() -> void:
	print("Setup script loaded. Now add GameManager and MetaProgression as autoloads manually.")
