extends CharacterBody2D


func _ready():
	print("=== TEST MOVEMENT SCENE LOADED ===")
	print("WASD should move the blue square")


func _physics_process(_delta):
	var direction = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	velocity = direction * 400.0
	move_and_slide()

	if velocity.length() > 0:
		print("TestPlayer MOVING - velocity: ", velocity)
