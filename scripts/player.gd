extends CharacterBody3D

@export var move_speed: float = 8.0
@export var sprint_speed: float = 11.0
@export var acceleration: float = 26.0
@export var jump_velocity: float = 7.2
@export var mouse_sensitivity: float = 0.0025
@export var max_health: int = 140
@export var max_stamina: float = 100.0

@onready var camera_pivot: Node3D = $CameraPivot
@onready var style_label: Label3D = $StyleLabel
@onready var rig = $CharacterRig

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var world_ref
var enabled: bool = true
var health: int
var stamina: float
var attack_cooldown: float = 0.0
var combo_timer: float = 0.0
var combo_index: int = 0
var dash_timer: float = 0.0
var dash_cooldown: float = 0.0
var dash_direction: Vector3 = Vector3.ZERO
var invulnerable_timer: float = 0.0
var style_index: int = 0
var previous_keys := {
	"jump": false,
	"style": false,
	"light": false,
	"heavy": false,
	"dash": false,
}

var styles := [
	{
		"name": "Shadow",
		"light_damage": [16, 20, 28],
		"heavy_damage": 38,
		"range": 3.2,
		"cooldown": 0.22,
		"speed_bonus": 1.12,
		"stamina_cost": 8.0,
	},
	{
		"name": "Street",
		"light_damage": [18, 23, 31],
		"heavy_damage": 42,
		"range": 2.75,
		"cooldown": 0.30,
		"speed_bonus": 1.0,
		"stamina_cost": 10.0,
	},
	{
		"name": "Heavy",
		"light_damage": [24, 30, 38],
		"heavy_damage": 58,
		"range": 2.45,
		"cooldown": 0.42,
		"speed_bonus": 0.86,
		"stamina_cost": 15.0,
	},
]

func _ready() -> void:
	health = max_health
	stamina = max_stamina
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_update_style()
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

	attack_cooldown = max(attack_cooldown - delta, 0.0)
	combo_timer = max(combo_timer - delta, 0.0)
	dash_timer = max(dash_timer - delta, 0.0)
	dash_cooldown = max(dash_cooldown - delta, 0.0)
	invulnerable_timer = max(invulnerable_timer - delta, 0.0)
	stamina = min(max_stamina, stamina + 21.0 * delta)

	if combo_timer <= 0.0:
		combo_index = 0

	if not enabled:
		velocity = Vector3.ZERO
		move_and_slide()
		return

	if not is_on_floor():
		velocity.y -= gravity * delta

	var jump_now := Input.is_key_pressed(KEY_SPACE)
	var style_now := Input.is_key_pressed(KEY_Q) or Input.is_key_pressed(KEY_TAB)
	var light_now := Input.is_key_pressed(KEY_J) or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	var heavy_now := Input.is_key_pressed(KEY_K) or Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
	var dash_now := Input.is_key_pressed(KEY_X) or Input.is_key_pressed(KEY_CTRL)

	if _just_pressed("jump", jump_now) and is_on_floor():
		velocity.y = jump_velocity

	if _just_pressed("style", style_now) or _consume_ui("switch_style"):
		style_index = (style_index + 1) % styles.size()
		_update_style()
		_show_info("Dövüş stili: %s" % styles[style_index]["name"])

	var input_vector := _read_move_input()
	var direction := (transform.basis * Vector3(input_vector.x, 0.0, input_vector.y)).normalized()
	var style_speed: float = styles[style_index]["speed_bonus"]
	var speed := (sprint_speed if Input.is_key_pressed(KEY_SHIFT) else move_speed) * style_speed

	if (_just_pressed("dash", dash_now) or _consume_ui("dash")) and dash_cooldown <= 0.0 and stamina >= 22.0:
		_start_dash(direction)

	if dash_timer > 0.0:
		velocity.x = dash_direction.x * 22.0
		velocity.z = dash_direction.z * 22.0
	else:
		if direction != Vector3.ZERO:
			velocity.x = move_toward(velocity.x, direction.x * speed, acceleration * delta)
			velocity.z = move_toward(velocity.z, direction.z * speed, acceleration * delta)
		else:
			velocity.x = move_toward(velocity.x, 0.0, acceleration * delta)
			velocity.z = move_toward(velocity.z, 0.0, acceleration * delta)

	if attack_cooldown <= 0.0 and dash_timer <= 0.0:
		if _just_pressed("light", light_now) or _consume_ui("attack_light"):
			_try_light_combo()
		elif _just_pressed("heavy", heavy_now) or _consume_ui("attack_heavy"):
			_try_heavy_attack()

	move_and_slide()
	rig.set_locomotion(Vector2(velocity.x, velocity.z).length(), is_on_floor())
	_update_previous_keys(jump_now, style_now, light_now, heavy_now, dash_now)

func _read_move_input() -> Vector2:
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
	return input_vector

func _try_light_combo() -> void:
	var cost: float = styles[style_index]["stamina_cost"]
	if stamina < cost:
		_show_info("Yorgunsun: stamina yenileniyor.")
		return
	stamina -= cost
	combo_index = (combo_index % 3) + 1
	combo_timer = 0.72
	var damage_values: Array = styles[style_index]["light_damage"]
	var damage: int = damage_values[combo_index - 1]
	attack_cooldown = styles[style_index]["cooldown"]
	rig.play_attack(combo_index, false)
	_perform_attack(damage, styles[style_index]["range"], false)
	_show_info("%s combo %d  |  %d hasar" % [styles[style_index]["name"], combo_index, damage])

func _try_heavy_attack() -> void:
	var cost: float = styles[style_index]["stamina_cost"] * 1.8
	if stamina < cost:
		_show_info("Güçlü saldırı için stamina yetersiz.")
		return
	stamina -= cost
	combo_index = 0
	combo_timer = 0.0
	attack_cooldown = styles[style_index]["cooldown"] * 2.0
	var damage: int = styles[style_index]["heavy_damage"]
	rig.play_attack(1, true)
	_perform_attack(damage, styles[style_index]["range"] + 0.45, true)
	_show_info("%s güçlü saldırı  |  %d hasar" % [styles[style_index]["name"], damage])

func _start_dash(direction: Vector3) -> void:
	stamina -= 22.0
	dash_timer = 0.20
	dash_cooldown = 0.72
	invulnerable_timer = 0.26
	dash_direction = direction if direction != Vector3.ZERO else -global_transform.basis.z
	rig.play_dash()
	_show_info("Gölge sıçrayışı")

func _perform_attack(damage: int, attack_range: float, heavy: bool) -> void:
	var forward := -global_transform.basis.z
	for node in get_tree().get_nodes_in_group("damageable"):
		if node == self or not node.has_method("take_damage"):
			continue
		var offset: Vector3 = node.global_position - global_position
		offset.y = 0.0
		if offset.length() > attack_range or offset.length() < 0.01:
			continue
		if forward.dot(offset.normalized()) > (-0.05 if heavy else 0.2):
			node.take_damage(damage)

func take_damage(amount: int) -> void:
	if invulnerable_timer > 0.0:
		return
	health = max(health - amount, 0)
	invulnerable_timer = 0.42
	_show_info("Hasar aldın: %d / %d HP" % [health, max_health])
	if health <= 0:
		_respawn()

func _respawn() -> void:
	health = max_health
	stamina = max_stamina
	global_position = Vector3(0, 1.2, 10)
	velocity = Vector3.ZERO
	_show_info("Gölge savaşçısı yeniden doğdu.")

func _update_style() -> void:
	var name: String = styles[style_index]["name"]
	if style_label:
		style_label.text = "%s\nHP %d  ST %d" % [name, health, int(stamina)]
		style_label.modulate = [Color(1.0, 0.15, 0.18), Color(0.20, 0.70, 1.0), Color(1.0, 0.52, 0.10)][style_index]
	rig.set_style(name)

func _process(_delta: float) -> void:
	if style_label:
		style_label.text = "%s\nHP %d  ST %d" % [styles[style_index]["name"], health, int(stamina)]

func _show_info(text: String) -> void:
	if world_ref:
		world_ref.show_info(text)

func _consume_ui(action_name: String) -> bool:
	return world_ref != null and world_ref.consume_ui_action(action_name)

func _just_pressed(key_name: String, current: bool) -> bool:
	return current and not previous_keys[key_name]

func _update_previous_keys(jump_now: bool, style_now: bool, light_now: bool, heavy_now: bool, dash_now: bool) -> void:
	previous_keys["jump"] = jump_now
	previous_keys["style"] = style_now
	previous_keys["light"] = light_now
	previous_keys["heavy"] = heavy_now
	previous_keys["dash"] = dash_now

func set_control_enabled(value: bool) -> void:
	enabled = value
	visible = value
