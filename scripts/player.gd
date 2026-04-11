extends CharacterBody3D

@export var speed: float = 15.0
@export var mouse_sensitivity: float = 0.002 # Note: 0.02 is usually very fast for Godot, 0.002 is a safer baseline

func _ready() -> void:
	# Hide the cursor and lock it to the center of the screen
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _input(event: InputEvent) -> void:
	# Handle Mouse Look
	if event is InputEventMouseMotion:
		# For a 6DOF spaceship, we rotate the ENTIRE ship relative to its own local space.
		# This allows you to pitch straight up into the sky and keep flying seamlessly.
		
		# Rotate the ship left and right (Yaw)
		rotate_object_local(Vector3.UP, -event.relative.x * mouse_sensitivity)
		
		# Rotate the ship up and down (Pitch)
		rotate_object_local(Vector3.RIGHT, -event.relative.y * mouse_sensitivity)
		
		# Notice we removed the camera clamp here. Spaceships don't break their necks;
		# they just do backflips!

func _physics_process(delta: float) -> void:
	# Press 'Escape' to free the mouse so you can close the game window
	if Input.is_action_just_pressed("ui_cancel"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		
	# Re-lock the mouse if you click back into the game
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	# Get WASD / Arrow Key input
	var input_dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	
	# === THE MAGIC LINE (UPDATED) ===
	# Instead of using the camera's basis, we now use the SHIP's global basis.
	# Because the camera is rigidly attached behind the ship, pushing "W" will 
	# always thrust the ship in the direction its nose is pointing.
	var direction := (global_transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	if direction:
		# Instant movement (If you want floaty space inertia, change this to a lerp or move_toward)
		velocity = direction * speed
	else:
		# Smoothly stop when you let go of the keys
		velocity = velocity.move_toward(Vector3.ZERO, speed * 5.0 * delta)

	move_and_slide()
