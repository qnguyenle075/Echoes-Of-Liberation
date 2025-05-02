extends Node2D

@onready var bg1 := $bg1
@onready var bg2 := $bg2
@onready var bg3 := $bg3
@onready var bg4 := $bg4
@onready var bg5 := $bg5
@onready var bg6 := $bg6
const VERTICAL_OFFSET := -10

@onready var playButton := $UIAnchor/Menu
@onready var exitButton := $UIAnchor/ExitButton

var menu_options: Array[Button] = []
var selected_index: int = 0

var is_animating: bool = false
var current_tween: Tween

var center_pos: Vector2
var start_pos_offset: Vector2 = Vector2(0, 50)
var end_pos_offset: Vector2 = Vector2(0, -50)
var animation_duration: float = 0.3

func _ready():
	for bg in [bg1, bg2, bg3, bg4, bg5, bg6]:
		bg.centered = true
		bg.offset = Vector2(0, VERTICAL_OFFSET)

	menu_options = [playButton, exitButton]

	center_pos = playButton.position

	for i in range(menu_options.size()):
		var button = menu_options[i]

		if button == playButton:
			button.text = "Menu"
		elif button == exitButton:
			button.text = "Quit"

		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(_on_button_pressed.bind(i))

		if i == selected_index:
			button.position = center_pos
			button.modulate.a = 1.0
			button.visible = true
		else:
			button.position = center_pos + start_pos_offset
			button.modulate.a = 0.0
			button.visible = false

	set_process_unhandled_input(true)
	
	Music.play_music("res://assets/Sound/Pixelated Reflections(kết thúc game).mp3")

func _unhandled_input(event: InputEvent):
	if not is_inside_tree():
		return

	if is_animating:
		return

	var direction = 0
	if event.is_action_pressed("ui_down") or event.is_action_pressed("down_p1"):
		Music.play_sfx("res://assets/Sound/retro-select-236670.mp3")
		direction = 1
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_up") or event.is_action_pressed("up_p1"):
		Music.play_sfx("res://assets/Sound/retro-select-236670.mp3")
		direction = -1
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_accept") or event.is_action_pressed("boom_p1"):
		Music.play_sfx("res://assets/Sound/retro-select-236670.mp3")
		if selected_index >= 0 and selected_index < menu_options.size():
			# Đảo 2 dòng này: Đánh dấu xử lý TRƯỚC khi emit signal
			get_viewport().set_input_as_handled()
			menu_options[selected_index].emit_signal("pressed")
		return

	if direction != 0:
		var previous_index = selected_index
		selected_index = (selected_index + direction + menu_options.size()) % menu_options.size()

		if previous_index != selected_index:
			start_transition_animation(previous_index, selected_index)

func start_transition_animation(from_index: int, to_index: int):
	is_animating = true

	var button_out = menu_options[from_index]
	var button_in = menu_options[to_index]

	button_in.position = center_pos + start_pos_offset
	button_in.modulate.a = 0.0
	button_in.visible = true

	if current_tween and current_tween.is_valid():
		current_tween.kill()

	current_tween = create_tween()
	current_tween.set_parallel(true)
	current_tween.set_trans(Tween.TRANS_SINE)
	current_tween.set_ease(Tween.EASE_OUT)

	current_tween.tween_property(button_out, "position", center_pos + end_pos_offset, animation_duration)
	current_tween.tween_property(button_out, "modulate:a", 0.0, animation_duration * 0.8).set_delay(animation_duration * 0.1)

	current_tween.tween_property(button_in, "position", center_pos, animation_duration)
	current_tween.tween_property(button_in, "modulate:a", 1.0, animation_duration * 0.8).set_delay(animation_duration * 0.1)

	current_tween.finished.connect(_on_animation_finished.bind(button_out))

func _on_animation_finished(button_that_animated_out: Button):
	is_animating = false

	if button_that_animated_out and is_instance_valid(button_that_animated_out):
		button_that_animated_out.visible = false

	if selected_index >= 0 and selected_index < menu_options.size():
		var current_button = menu_options[selected_index]
		if is_instance_valid(current_button):
			current_button.position = center_pos
			current_button.modulate.a = 1.0
			current_button.visible = true

func _on_button_pressed(index_pressed: int):
	if is_animating or index_pressed != selected_index:
		return

	if index_pressed >= 0 and index_pressed < menu_options.size() and is_instance_valid(menu_options[index_pressed]):
		match index_pressed:
			0:
				_on_play_button_pressed()
			1:
				_on_exit_button_pressed()
			_:
				pass

func _on_play_button_pressed():
	is_animating = true
	get_tree().change_scene_to_file("res://scene/mainmenu/main.tscn")

func _on_exit_button_pressed():
	get_tree().quit()

func _process(delta):
	var center_vp = get_viewport_rect().size / 2
	var mouseOffset = get_global_mouse_position() - center_vp

	bg1.position = center_vp + mouseOffset * 0.005
	bg2.position = center_vp + mouseOffset * 0.008
	bg3.position = center_vp + mouseOffset * 0.011
	bg4.position = center_vp + mouseOffset * 0.014
	bg5.position = center_vp + mouseOffset * 0.01
	bg6.position = center_vp + mouseOffset * 0.01
