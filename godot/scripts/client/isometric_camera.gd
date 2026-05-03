extends Camera3D

@export var camera_position: Vector3 = Vector3(20, 20, 20)
@export var look_at_target: Vector3 = Vector3.ZERO
@export var orthographic_size: float = 30.0


func _ready() -> void:
	projection = Camera3D.PROJECTION_ORTHOGONAL
	size = orthographic_size
	far = 200.0
	current = true
	global_position = camera_position
	look_at(look_at_target, Vector3.UP)
