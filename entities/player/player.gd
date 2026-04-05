extends CharacterBody2D

@export var speed: float = 400.0
var health: int = 120


func _ready():
	print("=== PLAYER LOADED AND READY ===")
	var cls = GameManager.current_class
	# ClassData uses character_class_name (class_name is reserved in GDScript).
	print("Current class: ", cls.character_class_name if cls else "None")
	print("Use WASD to move")


func _physics_process(_delta: float):
	var direction = Input.get_vector(
		InputManager.ACTION_MOVE_LEFT,
		InputManager.ACTION_MOVE_RIGHT,
		InputManager.ACTION_MOVE_UP,
		InputManager.ACTION_MOVE_DOWN
	)
	velocity = direction * speed
	move_and_slide()

	if velocity.length() > 0:
		print("MOVING - velocity: ", velocity)


func take_damage(amount: int):
	health -= amount
	print("Player took ", amount, " damage. Health left: ", health)
	if health <= 0:
		print("Player died!")
