extends Node2D

const WORLD_SIZE := Vector2(2400.0, 1800.0)
const PLAYER_SPEED := 260.0

var player: CharacterBody2D
var camera: Camera2D
var npc: Area2D
var mission_label: Label
var info_label: Label
var money_label: Label
var money := 250
var mission_done := false

func _ready() -> void:
	_build_world()
	_build_player()
	_build_npc()
	_build_ui()
	queue_redraw()

func _physics_process(_delta: float) -> void:
	var input_vector := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	player.velocity = input_vector.normalized() * PLAYER_SPEED
	player.move_and_slide()
	player.position.x = clampf(player.position.x, 40.0, WORLD_SIZE.x - 40.0)
	player.position.y = clampf(player.position.y, 40.0, WORLD_SIZE.y - 40.0)

	if input_vector.length() > 0.1:
		player.rotation = input_vector.angle() + PI / 2.0

	if Input.is_action_just_pressed("interact"):
		_try_interact()

func _draw() -> void:
	# Zemin
	draw_rect(Rect2(Vector2.ZERO, WORLD_SIZE), Color("88c96b"))

	# Ana yollar
	draw_rect(Rect2(0, 760, WORLD_SIZE.x, 280), Color("4a4f58"))
	draw_rect(Rect2(1040, 0, 320, WORLD_SIZE.y), Color("4a4f58"))
	draw_rect(Rect2(0, 875, WORLD_SIZE.x, 10), Color("f6d447"))
	draw_rect(Rect2(1195, 0, 10, WORLD_SIZE.y), Color("f6d447"))

	# Su / göl
	draw_circle(Vector2(350, 1420), 240.0, Color("62b7df"))
	draw_circle(Vector2(350, 1420), 185.0, Color("75c9ef"))

	# Bölgeler
	_draw_building(Rect2(170, 180, 360, 260), Color("e4a45f"), "Tamirhane")
	_draw_building(Rect2(680, 190, 300, 230), Color("d97d88"), "Market")
	_draw_building(Rect2(1500, 170, 400, 300), Color("7da8df"), "Belediye")
	_draw_building(Rect2(1750, 1200, 420, 300), Color("b58add"), "Gece Kulübü")
	_draw_building(Rect2(700, 1260, 340, 250), Color("e6d066"), "Garaj")

	# Ağaçlar
	for x in range(90, 2300, 170):
		_draw_tree(Vector2(x, 610))
	for y in range(110, 1700, 180):
		_draw_tree(Vector2(2220, y))
	for i in range(18):
		var px := 80.0 + float((i * 137) % 850)
		var py := 1080.0 + float((i * 83) % 560)
		_draw_tree(Vector2(px, py))

func _draw_building(rect: Rect2, color: Color, title: String) -> void:
	draw_rect(rect.grow(12), Color(0.16, 0.18, 0.22, 0.32))
	draw_rect(rect, color)
	draw_rect(Rect2(rect.position + Vector2(20, 20), Vector2(rect.size.x - 40, 38)), color.lightened(0.22))
	draw_string(ThemeDB.fallback_font, rect.position + Vector2(24, 48), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color("20252d"))

func _draw_tree(position: Vector2) -> void:
	draw_rect(Rect2(position - Vector2(7, 5), Vector2(14, 28)), Color("754b2b"))
	draw_circle(position - Vector2(0, 22), 31.0, Color("2c7f45"))
	draw_circle(position - Vector2(18, 14), 22.0, Color("369c53"))
	draw_circle(position + Vector2(18, -14), 22.0, Color("369c53"))

func _build_world() -> void:
	var background := ColorRect.new()
	background.color = Color("88c96b")
	background.size = WORLD_SIZE
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.z_index = -10
	add_child(background)

	# Basit bina çarpışmaları
	_add_wall(Rect2(170, 180, 360, 260))
	_add_wall(Rect2(680, 190, 300, 230))
	_add_wall(Rect2(1500, 170, 400, 300))
	_add_wall(Rect2(1750, 1200, 420, 300))
	_add_wall(Rect2(700, 1260, 340, 250))

func _add_wall(rect: Rect2) -> void:
	var body := StaticBody2D.new()
	body.position = rect.get_center()
	var shape_node := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = rect.size
	shape_node.shape = shape
	body.add_child(shape_node)
	add_child(body)

func _build_player() -> void:
	player = CharacterBody2D.new()
	player.name = "Player"
	player.position = Vector2(1200, 1120)
	player.z_index = 10

	var collision := CollisionShape2D.new()
	var capsule := CapsuleShape2D.new()
	capsule.radius = 18.0
	capsule.height = 46.0
	collision.shape = capsule
	player.add_child(collision)

	var body := Polygon2D.new()
	body.polygon = PackedVector2Array([
		Vector2(-19, 21), Vector2(-24, -8), Vector2(-14, -28),
		Vector2(0, -39), Vector2(14, -28), Vector2(24, -8), Vector2(19, 21)
	])
	body.color = Color("26313d")
	player.add_child(body)

	var face := Polygon2D.new()
	face.polygon = PackedVector2Array([Vector2(-12,-19), Vector2(12,-19), Vector2(10,2), Vector2(-10,2)])
	face.color = Color("dca27b")
	player.add_child(face)

	var scarf := Polygon2D.new()
	scarf.polygon = PackedVector2Array([Vector2(-20,5), Vector2(20,5), Vector2(15,16), Vector2(-15,16)])
	scarf.color = Color("bb3038")
	player.add_child(scarf)

	camera = Camera2D.new()
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 7.0
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = int(WORLD_SIZE.x)
	camera.limit_bottom = int(WORLD_SIZE.y)
	camera.zoom = Vector2(0.9, 0.9)
	player.add_child(camera)
	add_child(player)

func _build_npc() -> void:
	npc = Area2D.new()
	npc.name = "KasifArda"
	npc.position = Vector2(1370, 1120)
	npc.z_index = 8

	var collision := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 26.0
	collision.shape = circle
	npc.add_child(collision)

	var marker := Polygon2D.new()
	marker.polygon = PackedVector2Array([
		Vector2(-19, 26), Vector2(-22, -5), Vector2(-12, -26),
		Vector2(0, -34), Vector2(12, -26), Vector2(22, -5), Vector2(19, 26)
	])
	marker.color = Color("f0a941")
	npc.add_child(marker)

	var name_label := Label.new()
	name_label.text = "Kaşif Arda\n[E] Konuş"
	name_label.position = Vector2(-58, -72)
	name_label.size = Vector2(116, 42)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 18)
	npc.add_child(name_label)
	add_child(npc)

func _build_ui() -> void:
	var canvas := CanvasLayer.new()
	add_child(canvas)

	var top_panel := ColorRect.new()
	top_panel.position = Vector2(22, 22)
	top_panel.size = Vector2(420, 118)
	top_panel.color = Color(0.05, 0.07, 0.10, 0.88)
	canvas.add_child(top_panel)

	mission_label = Label.new()
	mission_label.position = Vector2(42, 38)
	mission_label.size = Vector2(380, 60)
	mission_label.text = "GÖREV\nKaşif Arda ile konuş."
	mission_label.add_theme_font_size_override("font_size", 23)
	canvas.add_child(mission_label)

	money_label = Label.new()
	money_label.position = Vector2(42, 104)
	money_label.text = "Para: %d ₺" % money
	money_label.add_theme_font_size_override("font_size", 20)
	canvas.add_child(money_label)

	info_label = Label.new()
	info_label.anchor_left = 0.5
	info_label.anchor_right = 0.5
	info_label.offset_left = -260
	info_label.offset_right = 260
	info_label.offset_top = 24
	info_label.offset_bottom = 70
	info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info_label.text = "WASD ile dolaş • E ile etkileşim"
	info_label.add_theme_font_size_override("font_size", 22)
	canvas.add_child(info_label)

	var mobile_hint := Label.new()
	mobile_hint.anchor_left = 1.0
	mobile_hint.anchor_top = 1.0
	mobile_hint.anchor_right = 1.0
	mobile_hint.anchor_bottom = 1.0
	mobile_hint.offset_left = -330
	mobile_hint.offset_top = -70
	mobile_hint.offset_right = -20
	mobile_hint.offset_bottom = -20
	mobile_hint.text = "2D prototip • Mobil kontroller sıradaki adım"
	mobile_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	mobile_hint.add_theme_font_size_override("font_size", 17)
	canvas.add_child(mobile_hint)

func _try_interact() -> void:
	if player.global_position.distance_to(npc.global_position) > 105.0:
		info_label.text = "Etkileşim için Kaşif Arda'ya yaklaş."
		return
	if mission_done:
		info_label.text = "Arda: Şehri keşfetmeye devam et."
		return
	mission_done = true
	money += 150
	money_label.text = "Para: %d ₺" % money
	mission_label.text = "GÖREV TAMAMLANDI\nŞehri ve tamirhaneyi keşfet."
	info_label.text = "Arda: Hoş geldin! İlk ödülün +150 ₺"
