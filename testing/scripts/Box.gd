extends Area

func _ready():
	pass

func _process(delta):
	rotate(Vector3(0, -1, 0), deg2rad(60 * delta))

func _on_body_entered(body): ## doesnt work yet
	if body is KinematicBody:
		queue_free()
	else:
		print("test")
