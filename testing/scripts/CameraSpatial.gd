extends Spatial

var camera_angle = 0
var mouse_sensitivity = 0.3

func _ready():
	pass

func _input(event):
	if event is InputEventMouseMotion:
		$Camera.rotate_y(deg2rad(-event.relative.x * mouse_sensitivity))
		var change = -event.relative.y * mouse_sensitivity
		if change + camera_angle < 90 and change + camera_angle > -90:
			$Camera.rotate_x(deg2rad(change))
			camera_angle += change
