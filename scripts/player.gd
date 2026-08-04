extends CharacterBody3D

const RIG_SCENE := preload("res://scenes/player/character_rig.tscn")

@export var move_speed := 8.0
@export var sprint_speed := 11.0
@export var acceleration := 26.0
@export var jump_velocity := 7.2
@export var mouse_sensitivity := 0.0025
@export var max_health := 140
@export var max_stamina := 100.0

@onready var camera_pivot: Node3D = $CameraPivot
@onready var style_label: Label3D = $StyleLabel

var rig: Node3D
var world_ref
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var enabled := true
var health := 140
var stamina := 100.0
var style_index := 0
var combo_index := 0
var combo_timer := 0.0
var attack_cooldown := 0.0
var dash_timer := 0.0
var dash_cooldown := 0.0
var invulnerable_timer := 0.0
var dash_direction := Vector3.ZERO
var previous := {"jump": false, "style": false, "light": false, "heavy": false, "dash": false}

var styles := [
	{"name":"Shadow", "light":[16,20,28], "heavy":38, "range":3.2, "cooldown":0.22, "speed":1.12, "cost":8.0},
	{"name":"Street", "light":[18,23,31], "heavy":42, "range":2.75, "cooldown":0.30, "speed":1.0, "cost":10.0},
	{"name":"Heavy", "light":[24,30,38], "heavy":58, "range":2.45, "cooldown":0.42, "speed":0.86, "cost":15.0},
]

func _ready() -> void:
	health = max_health
	stamina = max_stamina
	rig = RIG_SCENE.instantiate()
	rig.name = "CharacterRig"
	add_child(rig)
	for old_visual in ["Body", "Head", "Mask"]:
		var node := get_node_or_null(old_visual)
		if node is VisualInstance3D:
			node.visible = false
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

	if _just("jump", jump_now) and is_on_floor():
		velocity.y = jump_velocity
	if _just("style", style_now) or _consume_ui("switch_style"):
		style_index = (style_index + 1) % styles.size()
		_update_style()
		_show("Dövüş stili: %s" % styles[style_index]["name"])

	var input_vector := _move_input()
	var direction := (transform.basis * Vector3(input_vector.x, 0.0, input_vector.y)).normalized()
	var speed: float = (sprint_speed if Input.is_key_pressed(KEY_SHIFT) else move_speed) * styles[style_index]["speed"]
	if (_just("dash", dash_now) or _consume_ui("dash")) and dash_cooldown <= 0.0 and stamina >= 22.0:
		_start_dash(direction)

	if dash_timer > 0.0:
		velocity.x = dash_direction.x * 22.0
		velocity.z = dash_direction.z * 22.0
	elif direction != Vector3.ZERO:
		velocity.x = move_toward(velocity.x, direction.x * speed, acceleration * delta)
		velocity.z = move_toward(velocity.z, direction.z * speed, acceleration * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, acceleration * delta)
		velocity.z = move_toward(velocity.z, 0.0, acceleration * delta)

	if attack_cooldown <= 0.0 and dash_timer <= 0.0:
		if _just("light", light_now) or _consume_ui("attack_light"):
			_light_attack()
		elif _just("heavy", heavy_now) or _consume_ui("attack_heavy"):
			_heavy_attack()

	move_and_slide()
	if rig and rig.has_method("set_locomotion"):
		rig.set_locomotion(Vector2(velocity.x, velocity.z).length(), is_on_floor())
	previous = {"jump": jump_now, "style": style_now, "light": light_now, "heavy": heavy_now, "dash": dash_now}

func _move_input() -> Vector2:
	var v := Vector2.ZERO
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT): v.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT): v.x += 1.0
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP): v.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN): v.y += 1.0
	if v.length() > 1.0: v = v.normalized()
	if world_ref:
		var mobile: Vector2 = world_ref.get_move_input()
		if mobile.length() > v.length(): v = mobile
	return v

func _light_attack() -> void:
	var cost: float = styles[style_index]["cost"]
	if stamina < cost:
		_show("Stamina yenileniyor.")
		return
	stamina -= cost
	combo_index = combo_index % 3 + 1
	combo_timer = 0.72
	var damage: int = styles[style_index]["light"][combo_index - 1]
	attack_cooldown = styles[style_index]["cooldown"]
	if rig: rig.play_attack(combo_index, false)
	_hit_targets(damage, styles[style_index]["range"], false)
	_show("%s combo %d | %d hasar" % [styles[style_index]["name"], combo_index, damage])

func _heavy_attack() -> void:
	var cost: float = styles[style_index]["cost"] * 1.8
	if stamina < cost:
		_show("Güçlü saldırı için stamina yetersiz.")
		return
	stamina -= cost
	combo_index = 0
	attack_cooldown = styles[style_index]["cooldown"] * 2.0
	var damage: int = styles[style_index]["heavy"]
	if rig: rig.play_attack(1, true)
	_hit_targets(damage, styles[style_index]["range"] + 0.45, true)
	_show("%s güçlü saldırı | %d hasar" % [styles[style_index]["name"], damage])

func _start_dash(direction: Vector3) -> void:
	stamina -= 22.0
	dash_timer = 0.20
	dash_cooldown = 0.72
	invulnerable_timer = 0.26
	dash_direction = direction if direction != Vector3.ZERO else -global_transform.basis.z
	if rig: rig.play_dash()
	_show("Gölge sıçrayışı")

func _hit_targets(damage: int, attack_range: float, heavy: bool) -> void:
	var forward := -global_transform.basis.z
	for node in get_tree().get_nodes_in_group("damageable"):
		if node == self or not node.has_method("take_damage"): continue
		var offset: Vector3 = node.global_position - global_position
		offset.y = 0.0
		if offset.length() > attack_range or offset.length() < 0.01: continue
		if forward.dot(offset.normalized()) > (-0.05 if heavy else 0.2): node.take_damage(damage)

func take_damage(amount: int) -> void:
	if invulnerable_timer > 0.0: return
	health = max(health - amount, 0)
	invulnerable_timer = 0.42
	_show("Hasar aldın: %d / %d HP" % [health, max_health])
	if health <= 0: _respawn()

func _respawn() -> void:
	health = max_health
	stamina = max_stamina
	global_position = Vector3(0, 1.2, 10)
	velocity = Vector3.ZERO
	_show("Gölge savaşçısı yeniden doğdu.")

func _update_style() -> void:
	var name: String = styles[style_index]["name"]
	if style_label:
		style_label.modulate = [Color(1.0,0.15,0.18), Color(0.2,0.7,1.0), Color(1.0,0.52,0.1)][style_index]
	if rig and rig.has_method("set_style"): rig.set_style(name)

func _process(_delta: float) -> void:
	if style_label:
		style_label.text = "%s\nHP %d  ST %d" % [styles[style_index]["name"], health, int(stamina)]

func _show(text: String) -> void:
	if world_ref: world_ref.show_info(text)

func _consume_ui(action_name: String) -> bool:
	return world_ref != null and world_ref.consume_ui_action(action_name)

func _just(key_name: String, current: bool) -> bool:
	return current and not previous[key_name]

func set_control_enabled(value: bool) -> void:
	enabled = value
	visible = value
