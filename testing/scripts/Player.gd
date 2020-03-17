extends KinematicBody

var camera_angle = 0
var mouse_sensitivity = 0.3

# flying camera variables
const FLY_SPEED = 20
const FLY_ACCEL = 4
var direction = Vector3()
var velocity = Vector3()
var can_fly = false


# walk variables
var gravity = -9.8 * 3
const MAX_SPEED = 15
const MAX_RUNNING_SPEED = 40
const ACCEL = 2 
const DEACCEL = 5
var jump_height = 15
var has_contact = false
const MAX_SLOPE_ANGLE = 45

# Called when the node enters the scene tree for the first time.
func _ready():
	#pass # Replace with function body.
	var calculate = Calculator.new()

	var sum = calculate.add(20, 10)
	print(sum)


func move(delta):
	if can_fly:
		fly(delta)
	else:
		walk(delta)


func walk(delta):  # fixed coords to gravity in y dir
	# resets direction of player
	direction = Vector3()
	# get rotation of cam
	var aim = $Head/Camera.get_camera_transform().basis
	if Input.is_action_pressed("ui_up"):
		direction -= aim.z
	if Input.is_action_pressed("ui_down"):
		direction += aim.z
	if Input.is_action_pressed("ui_left"):
		direction -= aim.x
	if Input.is_action_pressed("ui_right"):
		direction += aim.x

	direction = direction.normalized()
	
	# neccessarie? Because on steep slopes we lose contact to floor
	if (is_on_floor()):
		has_contact = true
		var n = $Tail.get_collision_normal()
		var floor_angle = rad2deg(acos(n.dot(Vector3(0, 1, 0))))
		if floor_angle < MAX_SLOPE_ANGLE:
			velocity.y += gravity * delta
	else:
		if !$Tail.is_colliding():
			has_contact = false
		velocity.y += gravity * delta
	if (has_contact and !is_on_floor()):
		move_and_collide(Vector3(0, -1, 0))
	
	# standard gravity and walk setup
	#velocity.y += gravity * delta
	
	var temp_velocity = velocity
	temp_velocity.y = 0
	
	var speed
	if Input.is_action_pressed("move_sprint"):
		speed = MAX_RUNNING_SPEED
	else:
		speed = MAX_SPEED
	
	#where would the player go at max speed
	var target = direction * speed
	
	var acceleration
	if direction.dot(temp_velocity) > 0:
		acceleration = ACCEL
	else: 
		acceleration = DEACCEL
	
	# calculate a portion of the distance to go
	temp_velocity = temp_velocity.linear_interpolate(target, acceleration * delta)
	
	velocity.x = temp_velocity.x
	velocity.z = temp_velocity.z
	
	if has_contact and Input.is_action_just_pressed("jump"):
		velocity.y += jump_height
		has_contact = false
	
	# move
	velocity = move_and_slide(velocity, Vector3(0, 1, 0))



func fly(delta):
	# resets direction of player
	direction = Vector3()
	# get rotation of cam
	var aim = $Head/Camera.get_camera_transform().basis
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
	var aim = $Head/Camera.get_camera_transform().basis
	$Head.rotate_y(deg2rad(-camera_change.x * mouse_sensitivity))
	var change = -camera_change.y * mouse_sensitivity
	if change + camera_angle < 90 and change + camera_angle > -90:
		$Head/Camera.rotate_x(deg2rad(change))
		camera_angle += change


func _on_Area_body_shape_entered(body_id, body, body_shape, area_shape):
	if body.name == "Player":
		can_fly = true


func _on_Area_body_shape_exited(body_id, body, body_shape, area_shape):
	if body.name == "Player":
		can_fly = false
