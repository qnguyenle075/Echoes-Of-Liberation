extends Node2D

@onready var bg1 := $bg1
@onready var bg2 := $bg2
@onready var bg3 := $bg3
@onready var bg4 := $bg4
@onready var bg5 := $bg5
@onready var bg6 := $bg6
const VERTICAL_OFFSET := -10

@onready var playButton := $UIAnchor/PlayButton
@onready var exitButton := $UIAnchor/ExitButton
@onready var vsPlayerButton := $UIAnchor/VsPlayerButton
@onready var vsAIButton := $UIAnchor/VsAIButton

enum MenuState { MAIN, MODE_SELECT }
var current_menu_state = MenuState.MAIN

var main_menu_options: Array[Button] = []
var mode_select_options: Array[Button] = []
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

	main_menu_options = [playButton, exitButton]
	mode_select_options = [vsPlayerButton, vsAIButton]

	center_pos = playButton.position

	var all_buttons = main_menu_options + mode_select_options
	for i in range(all_buttons.size()):
		var button = all_buttons[i]

		if button == playButton: button.text = "Play"
		elif button == exitButton: button.text = "Quit"
		elif button == vsPlayerButton: button.text = " 2P"
		elif button == vsAIButton: button.text = " AI"

		button.focus_mode = Control.FOCUS_NONE
		button.position = center_pos + start_pos_offset
		button.modulate.a = 0.0
		button.visible = false

		var already_connected = false
		if button.is_connected("pressed", Callable(self, "_on_play_button_pressed")) or \
			button.is_connected("pressed", Callable(self, "_on_exit_button_pressed")) or \
			button.is_connected("pressed", Callable(self, "_on_vs_player_pressed")) or \
			button.is_connected("pressed", Callable(self, "_on_vs_ai_pressed")):
			already_connected = true

		if not already_connected:
			if button == playButton: button.pressed.connect(_on_play_button_pressed)
			elif button == exitButton: button.pressed.connect(_on_exit_button_pressed)
			elif button == vsPlayerButton: button.pressed.connect(_on_vs_player_pressed)
			elif button == vsAIButton: button.pressed.connect(_on_vs_ai_pressed)

	selected_index = 0
	var initial_button = main_menu_options[selected_index]
	if is_instance_valid(initial_button):
		initial_button.position = center_pos
		initial_button.modulate.a = 1.0
		initial_button.visible = true

	set_process_unhandled_input(true)


func get_current_options() -> Array[Button]:
	if current_menu_state == MenuState.MAIN:
		return main_menu_options
	elif current_menu_state == MenuState.MODE_SELECT:
		return mode_select_options
	else:
		return []

func _unhandled_input(event: InputEvent):
	if not is_inside_tree(): return
	if is_animating: return

	var current_options = get_current_options()
	if current_options.is_empty(): return

	var direction = 0
	if event.is_action_pressed("ui_down"): direction = 1
	elif event.is_action_pressed("ui_up"): direction = -1
	elif event.is_action_pressed("ui_accept"):
		if selected_index >= 0 and selected_index < current_options.size():
			get_viewport().set_input_as_handled()
			current_options[selected_index].emit_signal("pressed")
		return

	if direction != 0:
		get_viewport().set_input_as_handled()
		var previous_index = selected_index
		selected_index = (selected_index + direction + current_options.size()) % current_options.size()

		if previous_index != selected_index:
			start_transition_animation(previous_index, selected_index, current_options)


func start_transition_animation(from_index: int, to_index: int, options: Array[Button]):
	if from_index < 0 or from_index >= options.size() or to_index < 0 or to_index >= options.size():
		printerr("Invalid indices for start_transition_animation")
		return

	is_animating = true

	var button_out = options[from_index]
	var button_in = options[to_index]

	button_in.position = center_pos + start_pos_offset
	button_in.modulate.a = 0.0
	button_in.visible = true

	if current_tween and current_tween.is_valid(): current_tween.kill()
	current_tween = create_tween()
	current_tween.set_parallel(true)
	current_tween.set_trans(Tween.TRANS_SINE)
	current_tween.set_ease(Tween.EASE_OUT)

	current_tween.tween_property(button_out, "position", center_pos + end_pos_offset, animation_duration)
	current_tween.tween_property(button_out, "modulate:a", 0.0, animation_duration * 0.8).set_delay(animation_duration * 0.1)
	current_tween.tween_property(button_in, "position", center_pos, animation_duration)
	current_tween.tween_property(button_in, "modulate:a", 1.0, animation_duration * 0.8).set_delay(animation_duration * 0.1)

	current_tween.finished.connect(_on_animation_finished.bind(button_out))


func transition_to_menu(target_state: MenuState):
	if is_animating: return

	var options_out = get_current_options()
	if options_out.is_empty(): return

	is_animating = true
	var button_out = options_out[selected_index]

	current_menu_state = target_state
	selected_index = 0
	var options_in = get_current_options()
	if options_in.is_empty():
		is_animating = false
		printerr("Target menu has no options!")
		return
	var button_in = options_in[selected_index]

	button_in.position = center_pos + start_pos_offset
	button_in.modulate.a = 0.0
	button_in.visible = true

	if current_tween and current_tween.is_valid(): current_tween.kill()
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

	# Nút đi ra (ví dụ: Play) sẽ bị ẩn ở đây sau khi animation hoàn thành
	if button_that_animated_out and is_instance_valid(button_that_animated_out):
		button_that_animated_out.visible = false

	var current_options = get_current_options()
	if selected_index >= 0 and selected_index < current_options.size():
		var current_button = current_options[selected_index]
		if is_instance_valid(current_button):
			current_button.position = center_pos
			current_button.modulate.a = 1.0
			current_button.visible = true


func _on_play_button_pressed():
	# Hàm này bắt đầu animation, và animation sẽ tự ẩn nút "Play" khi hoàn thành
	transition_to_menu(MenuState.MODE_SELECT)

func _on_exit_button_pressed():
	# Ẩn nút Quit trước khi gọi lệnh thoát
	if is_instance_valid(exitButton):
		exitButton.visible = false
	get_tree().quit()

func _on_vs_player_pressed():
	is_animating = true
	# !!! THAY ĐỔI ĐƯỜNG DẪN NÀY !!!
	get_tree().change_scene_to_file("res://scene/map/map1/map.tscn") # Ví dụ

func _on_vs_ai_pressed():
	is_animating = true
	# !!! THAY ĐỔI ĐƯỜNG DẪN NÀY !!!
	get_tree().change_scene_to_file("res://scene/map/map1/map.tscn") # Ví dụ


func _process(delta):
	var center_vp = get_viewport_rect().size / 2
	var mouseOffset = get_global_mouse_position() - center_vp

	bg1.position = center_vp + mouseOffset * 0.005
	bg2.position = center_vp + mouseOffset * 0.008
	bg3.position = center_vp + mouseOffset * 0.011
	bg4.position = center_vp + mouseOffset * 0.014
	bg5.position = center_vp + mouseOffset * 0.01
	bg6.position = center_vp + mouseOffset * 0.01
