extends CharacterBody3D

@export var speed: float = 15.0
@export var mouse_sensitivity: float = 0.02 # Adjust this if the mouse moves too fast/slow

@onready var camera: Camera3D = $Camera3D

func _ready() -> void:
	# Hide the cursor and lock it to the center of the screen (FPS Style)
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _input(event: InputEvent) -> void:
	# Handle Mouse Look
	if event is InputEventMouseMotion:
		# Rotate the whole body left and right (Yaw)
		rotate_y(-event.relative.x * mouse_sensitivity)
		
		# Rotate only the camera up and down (Pitch)
		camera.rotate_x(-event.relative.y * mouse_sensitivity)
		
		# Clamp the camera's up/down rotation so you don't break your neck flipping over backward
		camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(-90), deg_to_rad(90))

func _physics_process(delta: float) -> void:
	# Press 'Escape' (ui_cancel) to free the mouse so you can close the game window
	if Input.is_action_just_pressed("ui_cancel"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		
	# Re-lock the mouse if you click back into the game
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	# Get WASD / Arrow Key input
	var input_dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	
	# === THE MAGIC LINE ===
	# Instead of the player's transform, we use the CAMERA'S global transform.
	# Because the camera tilts up and down, pressing "W" (ui_up) will push you 
	# in the exact 3D direction you are looking.
	var direction := (camera.global_transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	if direction:
		# Instant movement for tight FPS controls
		velocity = direction * speed
	else:
		# Smoothly stop when you let go of the keys
		velocity = velocity.move_toward(Vector3.ZERO, speed * 5.0 * delta)

	move_and_slide()
