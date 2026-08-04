extends CharacterBody3D

@export var move_speed: float = 8.0
@export var sprint_speed: float = 11.0
@export var acceleration: float = 26.0
@export var jump_velocity: float = 7.2
@export var mouse_sensitivity: float = 0.0025

@onready var camera_pivot: Node3D = $CameraPivot
@onready var style_label: Label3D = $StyleLabel

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var world_ref
var enabled: bool = true
var attack_cooldown: float = 0.0
var style_index: int = 0
var styles := [
	{"name": "Ninja", "light_damage": 18, "heavy_damage": 34, "range": 3.2},
	{"name": "Street", "light_damage": 13, "heavy_damage": 24, "range": 2.7},
	{"name": "Heavy", "light_damage": 24, "heavy_damage": 42, "range": 2.3},
]

func _ready() -> void:
	world_ref = get_tree().get_first_node_in_group("world_manager")
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_update_style_label()

func _unhandled_input(event: InputEvent) -> void:
	if not enabled:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * mouse_sensitivity)
		camera_pivot.rotate_x(-event.relative.y * mouse_sensitivity)
		camera_pivot.rotation.x = clamp(camera_pivot.rotation.x, deg_to_rad(-50.0), deg_to_rad(30.0))

	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	if event is InputEventMouseButton and event.pressed:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _physics_process(delta: float) -> void:
	if attack_cooldown > 0.0:
		attack_cooldown -= delta

	if not enabled:
		velocity = Vector3.ZERO
		move_and_slide()
		return

	if not is_on_floor():
		velocity.y -= gravity * delta

	if _consume_action("jump") and is_on_floor():
		velocity.y = jump_velocity

	if _consume_action("switch_style"):
		style_index = (style_index + 1) % styles.size()
		_update_style_label()
		if world_ref:
			world_ref.show_info("Dövüş stili: %s" % styles[style_index]["name"])

	var input_vector: Vector2 = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	if world_ref:
		var mobile_vec = world_ref.get_move_input()
		if mobile_vec.length() > input_vector.length():
			input_vector = mobile_vec

	var direction := (transform.basis * Vector3(input_vector.x, 0.0, input_vector.y)).normalized()
	var speed := sprint_speed if Input.is_key_pressed(KEY_SHIFT) else move_speed

	if direction != Vector3.ZERO:
		velocity.x = move_toward(velocity.x, direction.x * speed, acceleration * delta)
		velocity.z = move_toward(velocity.z, direction.z * speed, acceleration * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, acceleration * delta)
		velocity.z = move_toward(velocity.z, 0.0, acceleration * delta)

	if attack_cooldown <= 0.0:
		if _consume_action("attack_light"):
			_perform_attack(styles[style_index]["light_damage"], styles[style_index]["range"], false)
		elif _consume_action("attack_heavy"):
			_perform_attack(styles[style_index]["heavy_damage"], styles[style_index]["range"] + 0.3, true)

	move_and_slide()

func _perform_attack(damage: int, attack_range: float, heavy: bool) -> void:
	attack_cooldown = 0.55 if heavy else 0.28
	if world_ref:
		world_ref.show_info("%s saldırı!" % ("Güçlü" if heavy else "Hafif"))

	var forward := -global_transform.basis.z
	for node in get_tree().get_nodes_in_group("damageable"):
		if node == self:
			continue
		if not node.has_method("take_damage"):
			continue
		var offset: Vector3 = node.global_position - global_position
		offset.y = 0.0
		if offset.length() > attack_range or offset.length() < 0.01:
			continue
		var facing := forward.dot(offset.normalized())
		if facing > 0.1:
			node.take_damage(damage)

func _consume_action(action_name: String) -> bool:
	if Input.is_action_just_pressed(action_name):
		return true
	if world_ref and world_ref.consume_ui_action(action_name):
		return true
	return false

func _update_style_label() -> void:
	if style_label:
		style_label.text = styles[style_index]["name"]

func set_control_enabled(value: bool) -> void:
	enabled = value
	visible = value
