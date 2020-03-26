extends KinematicBody

var camera_angle = 0
var mouse_sensitivity = 0.3

# flying camera variables
const FLY_SPEED = 80
const FLY_ACCEL = 4
var direction = Vector3()
var velocity = Vector3()


func _ready():
	pass


func move(delta):
	# resets direction of player
	direction = Vector3()
	# get rotation of cam
	var aim = $CameraHead/FreeCamera.get_camera_transform().basis
	if Input.is_action_pressed("ui_up"):
		direction -= aim.z
	if Input.is_action_pressed("ui_down"):
		direction += aim.z
	if Input.is_action_pressed("ui_left"):
		direction -= aim.x
	if Input.is_action_pressed("ui_right"):
		direction += aim.x

	direction = direction.normalized()
	#where would the player go at max speed
	var target = direction * FLY_SPEED
	# calculate a portion of the distance to go
	velocity = velocity.linear_interpolate(target, FLY_ACCEL * delta)
	# move
	move_and_slide(velocity)


func look_around(camera_change):
	$CameraHead.rotate_y(deg2rad(-camera_change.x * mouse_sensitivity))
	var change = -camera_change.y * mouse_sensitivity
	if change + camera_angle < 90 and change + camera_angle > -90:
		$CameraHead/FreeCamera.rotate_x(deg2rad(change))
		camera_angle += change
