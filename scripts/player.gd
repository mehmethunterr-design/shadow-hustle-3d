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
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_update_style_label()
	call_deferred("_resolve_world")

func _resolve_world() -> void:
	world_ref = get_tree().get_first_node_in_group("world_manager")

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
	if world_ref == null:
		_resolve_world()

	if attack_cooldown > 0.0:
		attack_cooldown -= delta

	if not enabled:
		velocity = Vector3.ZERO
		move_and_slide()
		return

	if not is_on_floor():
		velocity.y -= gravity * delta

	if _jump_pressed() and is_on_floor():
		velocity.y = jump_velocity

	if _style_pressed():
		style_index = (style_index + 1) % styles.size()
		_update_style_label()
		if world_ref:
			world_ref.show_info("Dövüş stili: %s" % styles[style_index]["name"])

	var input_vector := Vector2.ZERO
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		input_vector.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		input_vector.x += 1.0
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		input_vector.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		input_vector.y += 1.0
	if input_vector.length() > 1.0:
		input_vector = input_vector.normalized()

	if world_ref:
		var mobile_vec: Vector2 = world_ref.get_move_input()
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
		if _light_attack_pressed():
			_perform_attack(styles[style_index]["light_damage"], styles[style_index]["range"], false)
		elif _heavy_attack_pressed():
			_perform_attack(styles[style_index]["heavy_damage"], styles[style_index]["range"] + 0.3, true)

	move_and_slide()

func _jump_pressed() -> bool:
	if Input.is_key_pressed(KEY_SPACE):
		return true
	return world_ref != null and world_ref.consume_ui_action("jump")

func _style_pressed() -> bool:
	if Input.is_key_pressed(KEY_Q) or Input.is_key_pressed(KEY_TAB):
		return Input.is_action_just_pressed("switch_style")
	return world_ref != null and world_ref.consume_ui_action("switch_style")

func _light_attack_pressed() -> bool:
	if Input.is_key_pressed(KEY_J):
		return true
	return world_ref != null and world_ref.consume_ui_action("attack_light")

func _heavy_attack_pressed() -> bool:
	if Input.is_key_pressed(KEY_K):
		return true
	return world_ref != null and world_ref.consume_ui_action("attack_heavy")

func _perform_attack(damage: int, attack_range: float, heavy: bool) -> void:
	attack_cooldown = 0.55 if heavy else 0.28
	if world_ref:
		world_ref.show_info("%s saldırı!" % ("Güçlü" if heavy else "Hafif"))

	var forward := -global_transform.basis.z
	for node in get_tree().get_nodes_in_group("damageable"):
		if node == self or not node.has_method("take_damage"):
			continue
		var offset: Vector3 = node.global_position - global_position
		offset.y = 0.0
		if offset.length() > attack_range or offset.length() < 0.01:
			continue
		if forward.dot(offset.normalized()) > 0.1:
			node.take_damage(damage)

func _update_style_label() -> void:
	if style_label:
		style_label.text = styles[style_index]["name"]

func set_control_enabled(value: bool) -> void:
	enabled = value
	visible = value
