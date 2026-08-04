extends CanvasLayer

var overlay: ColorRect
var panel: PanelContainer
var resume_button: Button
var restart_button: Button
var menu_button: Button
var quit_button: Button

func _ready() -> void:
	layer = 1000
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	visible = false

func _unhandled_input(event: InputEvent) -> void:
	if get_tree().current_scene == null:
		return
	if get_tree().current_scene.scene_file_path == "res://menu.tscn":
		return
	if event.is_action_pressed("ui_cancel"):
		_toggle_pause()
		get_viewport().set_input_as_handled()

func _toggle_pause() -> void:
	var next_state := not get_tree().paused
	get_tree().paused = next_state
	visible = next_state
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if next_state else Input.MOUSE_MODE_CAPTURED
	if next_state:
		resume_button.grab_focus()

func _resume() -> void:
	if get_tree().paused:
		_toggle_pause()

func _restart() -> void:
	get_tree().paused = false
	visible = false
	get_tree().reload_current_scene()

func _main_menu() -> void:
	get_tree().paused = false
	visible = false
	get_tree().change_scene_to_file("res://menu.tscn")

func _quit() -> void:
	get_tree().quit()

func _build_ui() -> void:
	overlay = ColorRect.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0.01, 0.015, 0.03, 0.82)
	add_child(overlay)

	panel = PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-230, -230)
	panel.size = Vector2(460, 460)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.055, 0.067, 0.11, 0.98)
	panel_style.border_width_left = 2
	panel_style.border_width_top = 2
	panel_style.border_width_right = 2
	panel_style.border_width_bottom = 2
	panel_style.border_color = Color(0.72, 0.07, 0.11, 1)
	panel_style.corner_radius_top_left = 20
	panel_style.corner_radius_top_right = 20
	panel_style.corner_radius_bottom_right = 20
	panel_style.corner_radius_bottom_left = 20
	panel.add_theme_stylebox_override("panel", panel_style)
	add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 32)
	margin.add_theme_constant_override("margin_top", 28)
	margin.add_theme_constant_override("margin_right", 32)
	margin.add_theme_constant_override("margin_bottom", 28)
	panel.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	margin.add_child(box)

	var eyebrow := Label.new()
	eyebrow.text = "SHADOW HUSTLE"
	eyebrow.add_theme_color_override("font_color", Color(0.95, 0.18, 0.22))
	eyebrow.add_theme_font_size_override("font_size", 16)
	box.add_child(eyebrow)

	var title := Label.new()
	title.text = "OYUN DURAKLATILDI"
	title.add_theme_font_size_override("font_size", 30)
	box.add_child(title)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(1, 18)
	box.add_child(spacer)

	resume_button = _make_button("DEVAM ET")
	restart_button = _make_button("BÖLÜMÜ YENİDEN BAŞLAT")
	menu_button = _make_button("ANA MENÜ")
	quit_button = _make_button("OYUNDAN ÇIK")

	box.add_child(resume_button)
	box.add_child(restart_button)
	box.add_child(menu_button)
	box.add_child(quit_button)

	resume_button.pressed.connect(_resume)
	restart_button.pressed.connect(_restart)
	menu_button.pressed.connect(_main_menu)
	quit_button.pressed.connect(_quit)

func _make_button(text_value: String) -> Button:
	var button := Button.new()
	button.text = text_value
	button.custom_minimum_size = Vector2(390, 54)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.add_theme_font_size_override("font_size", 17)

	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.11, 0.13, 0.19, 1)
	normal.corner_radius_top_left = 11
	normal.corner_radius_top_right = 11
	normal.corner_radius_bottom_left = 11
	normal.corner_radius_bottom_right = 11
	normal.content_margin_left = 20

	var hover := normal.duplicate()
	hover.bg_color = Color(0.52, 0.055, 0.085, 1)
	hover.border_width_left = 2
	hover.border_width_top = 2
	hover.border_width_right = 2
	hover.border_width_bottom = 2
	hover.border_color = Color(1, 0.28, 0.32, 1)

	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)
	button.add_theme_stylebox_override("focus", hover)
	return button
