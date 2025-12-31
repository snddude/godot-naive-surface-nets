class_name Freecam
extends Camera3D

const MIN_POS_ROT_X: float = -90.0
const MAX_POS_ROT_X: float = 90.0

@export var mouse_sensitivity: float
@export var speed: float

var _wireframe: bool = false
var _fullscreen: bool = false


func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		rotation_degrees.y -= deg_to_rad(event.screen_relative.x * mouse_sensitivity)
		rotation_degrees.x -= deg_to_rad(event.screen_relative.y * mouse_sensitivity)
		rotation_degrees.x = clamp(rotation_degrees.x, MIN_POS_ROT_X, MAX_POS_ROT_X)

	if event.is_action_pressed("ui_cancel"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	if event is InputEventMouseButton:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	if event.is_action_pressed("toggle_wireframe"):
		_wireframe = not _wireframe

		if _wireframe:
			get_tree().root.set_debug_draw(Viewport.DEBUG_DRAW_WIREFRAME)
		else:
			get_tree().root.set_debug_draw(Viewport.DEBUG_DRAW_DISABLED)
	
	if event.is_action_pressed("toggle_fullscreen"):
		_fullscreen = not _fullscreen

		if _fullscreen:
			get_window().set_mode(Window.MODE_EXCLUSIVE_FULLSCREEN)
		else:
			get_window().set_mode(Window.MODE_WINDOWED)


func _process(delta: float) -> void:
	var input: Vector2 = Input.get_vector("left", "right", "forward", "back")
	var wish_dir: Vector3 = global_basis * Vector3(input.x, Input.get_axis("down", "up"), input.y)

	global_position += wish_dir.normalized() * speed * delta
