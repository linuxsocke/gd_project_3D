extends Spatial

# camera vars
var camera_body
var camera_change = Vector2()


func _ready():
	$Panel.hide()
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	# Set default camera
	$CameraBody/CameraHead/FreeCamera.current = true  # may set by user
	camera_body = $CameraBody
	


func _process(delta):
	if (Input.is_action_just_pressed("ui_cancel")):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		get_tree().quit()
	
	if Input.is_key_pressed(KEY_ENTER):
		get_tree().reload_current_scene()

	if Input.is_action_just_pressed("switch_cam"):
		if $CameraBody/CameraHead/FreeCamera.current:
			$CameraBody/CameraHead/FreeCamera.clear_current(true)
			camera_body = $Player
		else:
			$Player/Head/Camera.clear_current(true)
			camera_body = $CameraBody
	if camera_change.x != 0 or camera_change.y != 0:
		camera_body.look_around(camera_change)
		camera_change = Vector2()   
			


func _input(event):
	if event is InputEventMouseMotion:
		camera_change = event.relative


func _physics_process(delta):
	camera_body.move(delta)


func _on_Area_body_entered(body):
	if body is RigidBody:
		$Panel.show()

