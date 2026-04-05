extends CharacterBody2D


func _ready():
	print("=== TEST MOVEMENT SCENE LOADED ===")
	print("WASD should move the blue square")


func _physics_process(_delta):
	var direction = Input.get_vector(
		InputManager.ACTION_MOVE_LEFT,
		InputManager.ACTION_MOVE_RIGHT,
		InputManager.ACTION_MOVE_UP,
		InputManager.ACTION_MOVE_DOWN
	)
	velocity = direction * 400.0
	move_and_slide()

	if velocity.length() > 0:
		print("TestPlayer MOVING - velocity: ", velocity)
