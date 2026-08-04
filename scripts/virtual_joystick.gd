extends Control

var dragging := false
var center := Vector2.ZERO
var radius := 65.0
var knob_pos := Vector2.ZERO
var output_vector := Vector2.ZERO

func _ready() -> void:
	custom_minimum_size = Vector2(160, 160)
	center = size * 0.5
	knob_pos = center
	mouse_filter = Control.MOUSE_FILTER_STOP

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			dragging = true
			_update_knob(event.position)
		else:
			dragging = false
			output_vector = Vector2.ZERO
			knob_pos = center
			queue_redraw()

	elif event is InputEventMouseMotion and dragging:
		_update_knob(event.position)

	if event is InputEventScreenTouch:
		if event.pressed:
			dragging = true
			_update_knob(event.position)
		else:
			dragging = false
			output_vector = Vector2.ZERO
			knob_pos = center
			queue_redraw()

	elif event is InputEventScreenDrag and dragging:
		_update_knob(event.position)

func _update_knob(pos: Vector2) -> void:
	var local = pos
	var dir = local - center
	if dir.length() > radius:
		dir = dir.normalized() * radius
	knob_pos = center + dir
	output_vector = dir / radius
	queue_redraw()

func get_output() -> Vector2:
	return output_vector

func _draw() -> void:
	draw_circle(center, radius, Color(0, 0, 0, 0.22))
	draw_circle(center, radius - 8, Color(0.7, 0.7, 0.7, 0.18))
	draw_circle(knob_pos, 28, Color(0.95, 0.95, 0.95, 0.75))
