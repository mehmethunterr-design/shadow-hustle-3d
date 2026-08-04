extends CharacterBody3D

@export var drive_power: float = 29.0
@export var max_speed: float = 23.0
@export var turn_speed: float = 2.35

@onready var drive_camera: Camera3D = $CameraPivot/SpringArm3D/Camera3D

var world_ref
var active: bool = false
var current_speed: float = 0.0
var lean: float = 0.0

func _ready() -> void:
	world_ref = get_tree().get_first_node_in_group("world_manager")

func _physics_process(delta: float) -> void:
	if not active:
		current_speed = move_toward(current_speed, 0.0, 18.0 * delta)
		velocity = Vector3.ZERO
		move_and_slide()
		return

	var input_vector: Vector2 = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	if world_ref:
		var mobile_vec = world_ref.get_move_input()
		if mobile_vec.length() > input_vector.length():
			input_vector = mobile_vec

	current_speed = clamp(current_speed + (-input_vector.y) * drive_power * delta, -5.0, max_speed)
	current_speed = move_toward(current_speed, 0.0, 7.0 * delta)

	lean = move_toward(lean, input_vector.x * 0.35, 1.9 * delta)
	rotate_y(-input_vector.x * turn_speed * delta * clamp(abs(current_speed) / 6.0, 0.45, 1.8))
	rotation.z = lean

	var forward := -global_transform.basis.z
	velocity = forward * current_speed
	move_and_slide()

func set_active(value: bool) -> void:
	active = value
	drive_camera.current = value
