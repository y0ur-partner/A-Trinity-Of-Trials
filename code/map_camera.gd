extends Camera2D

#This script allows the user to click and drag to scroll horizontally through the map, without moving the camera past the horizontal borders

var dragging = false

func _ready() -> void:
	limit_right = 2880 - get_viewport_rect().size.x

func _unhandled_input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			dragging = event.pressed
	elif event is InputEventMouseMotion and dragging:
		position.x -= event.relative.x * zoom.x
		position.x = clamp(position.x, limit_left, limit_right)
