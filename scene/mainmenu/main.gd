extends Node2D

@onready var bg1 := $bg1
@onready var bg2 := $bg2
@onready var bg3 := $bg3
@onready var bg4 := $bg4
@onready var bg5 := $bg5
@onready var bg6 := $bg6
const VERTICAL_OFFSET := -10

# --- UI Elements ---
# Đảm bảo các đường dẫn này khớp với Scene Tree của bạn
@onready var logo := $Logo
@onready var uiAnchor := $UIAnchor

@onready var playButton := $UIAnchor/PlayButton
@onready var exitButton := $UIAnchor/ExitButton
@onready var vsPlayerButton := $UIAnchor/VsPlayerButton
@onready var vsAIButton := $UIAnchor/VsAIButton
@onready var easyButton := $UIAnchor/EasyButton   # Nút bạn vừa thêm
@onready var hardButton := $UIAnchor/HardButton   # Nút bạn vừa thêm

# Các trạng thái menu có thể có
enum MenuState { MAIN, MODE_SELECT, DIFFICULTY_SELECT } # Bao gồm chọn độ khó
var current_menu_state = MenuState.MAIN

# Mảng chứa các elements cho từng menu (Dùng Control vì Button là con của Control)
var main_menu_options: Array[Control] = []
var mode_select_options: Array[Control] = []
var difficulty_select_options: Array[Control] = [] # Mảng cho độ khó
var selected_index: int = 0

# --- Biến Animation ---
var is_animating: bool = false
var current_tween: Tween
var center_pos_buttons: Vector2 # Vị trí cho các nút bấm

var start_pos_offset: Vector2 = Vector2(0, 50) # Chỉ dùng cho nút bấm
var end_pos_offset: Vector2 = Vector2(0, -50)   # Chỉ dùng cho nút bấm
var animation_duration: float = 0.3

func _ready():
	# --- Kiểm tra node (tùy chọn gỡ bỏ sau khi chắc chắn) ---
	if not is_instance_valid(logo): printerr("Logo node missing!")
	if not is_instance_valid(playButton): printerr("PlayButton missing!")
	if not is_instance_valid(exitButton): printerr("ExitButton missing!")
	if not is_instance_valid(vsPlayerButton): printerr("VsPlayerButton missing!")
	if not is_instance_valid(vsAIButton): printerr("VsAIButton missing!")
	if not is_instance_valid(easyButton): printerr("EasyButton missing! Check path $UIAnchor/EasyButton")
	if not is_instance_valid(hardButton): printerr("HardButton missing! Check path $UIAnchor/HardButton")

	# --- Thiết lập hình nền ---
	for bg in [bg1, bg2, bg3, bg4, bg5, bg6]:
		if is_instance_valid(bg):
			bg.centered = true
			bg.offset = Vector2(0, VERTICAL_OFFSET)

	# --- Khởi tạo mảng options ---
	if is_instance_valid(playButton): main_menu_options.append(playButton)
	if is_instance_valid(exitButton): main_menu_options.append(exitButton)
	if is_instance_valid(vsPlayerButton): mode_select_options.append(vsPlayerButton)
	if is_instance_valid(vsAIButton): mode_select_options.append(vsAIButton)
	if is_instance_valid(easyButton): difficulty_select_options.append(easyButton)
	if is_instance_valid(hardButton): difficulty_select_options.append(hardButton)

	# Xác định vị trí trung tâm cho các nút bấm
	if is_instance_valid(playButton): center_pos_buttons = playButton.position
	else: center_pos_buttons = Vector2.ZERO; printerr("PlayButton invalid!")

	# --- Thiết lập trạng thái ban đầu cho tất cả nút bấm ---
	var all_buttons = main_menu_options + mode_select_options + difficulty_select_options
	for button_control in all_buttons:
		if not is_instance_valid(button_control) or not button_control is Button: continue
		var button = button_control as Button

		if button == playButton: button.text = "Play"
		elif button == exitButton: button.text = "Quit"
		elif button == vsPlayerButton: button.text = "2P"
		elif button == vsAIButton: button.text = "AI"
		elif button == easyButton: button.text = "Easy" # Đặt text cho nút mới
		elif button == hardButton: button.text = "Hard" # Đặt text cho nút mới

		button.focus_mode = Control.FOCUS_NONE
		button.position = center_pos_buttons + start_pos_offset
		button.modulate.a = 0.0
		# Sẽ bị ẩn đi ở cuối _ready bởi _hide_all_menu_elements

		# Kết nối signal
		var already_connected = false
		if button.is_connected("pressed", Callable(self, "_on_play_button_pressed")) or \
			button.is_connected("pressed", Callable(self, "_on_exit_button_pressed")) or \
			button.is_connected("pressed", Callable(self, "_on_vs_player_pressed")) or \
			button.is_connected("pressed", Callable(self, "_on_vs_ai_pressed")) or \
			button.is_connected("pressed", Callable(self, "_on_easy_pressed")) or \
			button.is_connected("pressed", Callable(self, "_on_hard_pressed")):
			already_connected = true
		if 	not already_connected:
			if button == playButton: button.pressed.connect(_on_play_button_pressed)
			elif button == exitButton: button.pressed.connect(_on_exit_button_pressed)
			elif button == vsPlayerButton: button.pressed.connect(_on_vs_player_pressed)
			elif button == vsAIButton: button.pressed.connect(_on_vs_ai_pressed)
			elif button == easyButton: button.pressed.connect(_on_easy_pressed) # Kết nối nút mới
			elif button == hardButton: button.pressed.connect(_on_hard_pressed) # Kết nối nút mới

	# --- Hoàn tất thiết lập ban đầu ---
	_hide_all_menu_elements() # Ẩn tất cả nút

	selected_index = 0 # Hiển thị menu chính
	if not main_menu_options.is_empty():
		var initial_button = main_menu_options[selected_index]
		if is_instance_valid(initial_button):
			initial_button.position = center_pos_buttons
			initial_button.modulate.a = 1.0
			initial_button.visible = true # Hiện nút Play
	else:
		printerr("Main menu has no valid options!")

	if is_instance_valid(logo): logo.visible = true # Hiện logo
	set_process_unhandled_input(true)

# Cập nhật hàm này để bao gồm trạng thái mới
func get_current_options() -> Array[Control]:
	if current_menu_state == MenuState.MAIN: return main_menu_options
	elif current_menu_state == MenuState.MODE_SELECT: return mode_select_options
	elif current_menu_state == MenuState.DIFFICULTY_SELECT: return difficulty_select_options # Thêm case mới
	else: return []


func _unhandled_input(event: InputEvent):
	if not is_inside_tree(): return
	if is_animating: return

	var current_options = get_current_options()
	if current_options.is_empty(): return

	var direction = 0
	var accept_pressed = false

	# Chỉ xử lý Lên/Xuống cho các menu nút bấm này
	if event.is_action_pressed("ui_down") or event.is_action_pressed("down_p1"):
		direction = 1
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_up") or event.is_action_pressed("up_p1"):
		direction = -1
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_accept") or event.is_action_pressed("boom_p1"):
		accept_pressed = true
		get_viewport().set_input_as_handled()

	if accept_pressed:
		if selected_index >= 0 and selected_index < current_options.size():
			var selected_element = current_options[selected_index]
			if selected_element is Button: # Chỉ emit nếu là Button
				selected_element.emit_signal("pressed")
		return

	if direction != 0:
		var previous_index = selected_index
		selected_index = (selected_index + direction + current_options.size()) % current_options.size()
		if previous_index != selected_index:
			# Luôn dùng animation dọc cho các menu này
			start_transition_animation(previous_index, selected_index, current_options)


func start_transition_animation(from_index: int, to_index: int, options: Array[Control]):
	if options.is_empty() or from_index < 0 or from_index >= options.size() or \
	   to_index < 0 or to_index >= options.size():
		printerr("Invalid indices/options for start_transition_animation")
		return
	var button_out_control = options[from_index]
	var button_in_control = options[to_index]
	if not is_instance_valid(button_out_control) or not is_instance_valid(button_in_control) or \
	   not button_out_control is Button or not button_in_control is Button:
		printerr("Invalid button instance in start_transition_animation")
		return
	var button_out = button_out_control as Button
	var button_in = button_in_control as Button

	is_animating = true
	button_in.position = center_pos_buttons + start_pos_offset
	button_in.modulate.a = 0.0
	button_in.visible = true

	if current_tween and current_tween.is_valid(): current_tween.kill()
	current_tween = create_tween()
	current_tween.set_parallel(true)
	current_tween.set_trans(Tween.TRANS_SINE)
	current_tween.set_ease(Tween.EASE_OUT)

	current_tween.tween_property(button_out, "position", center_pos_buttons + end_pos_offset, animation_duration)
	current_tween.tween_property(button_out, "modulate:a", 0.0, animation_duration * 0.8).set_delay(animation_duration * 0.1)
	current_tween.tween_property(button_in, "position", center_pos_buttons, animation_duration)
	current_tween.tween_property(button_in, "modulate:a", 1.0, animation_duration * 0.8).set_delay(animation_duration * 0.1)

	# Khi animation kết thúc, gọi hàm xử lý chung
	current_tween.finished.connect(_on_transition_animation_finished.bind(button_out, false)) # false = không phải chuyển menu


func transition_to_menu(target_state: MenuState):
	if is_animating: return
	var options_out = get_current_options()
	if options_out.is_empty() or selected_index < 0 or selected_index >= options_out.size(): return
	var element_out = options_out[selected_index]
	if not is_instance_valid(element_out): return

	is_animating = true

	if current_tween and current_tween.is_valid(): current_tween.kill()
	current_tween = create_tween()
	# Chỉ cần animation ẩn element cũ
	var element_out_end_pos = center_pos_buttons + end_pos_offset + (element_out.pivot_offset if element_out is TextureRect else Vector2.ZERO) # Mặc dù không có TextureRect nữa, để an toàn
	current_tween.tween_property(element_out, "position", element_out_end_pos, animation_duration)
	current_tween.tween_property(element_out, "modulate:a", 0.0, animation_duration * 0.8).set_delay(animation_duration * 0.1)

	# Sau khi animation ẩn kết thúc, gọi hàm xử lý để hiện menu mới
	current_tween.finished.connect(_on_transition_animation_finished.bind(element_out, true, target_state))


func _on_transition_animation_finished(element_that_animated_out: Control, is_menu_transition: bool, target_state: MenuState = MenuState.MAIN):
	is_animating = false

	if element_that_animated_out and is_instance_valid(element_that_animated_out):
		element_that_animated_out.visible = false # Ẩn element cũ

	if is_menu_transition: # Chỉ thực hiện khi chuyển menu
		current_menu_state = target_state
		selected_index = 0
		var options_in = get_current_options()
		if options_in.is_empty(): return

		_hide_all_menu_elements() # Ẩn mọi thứ

		# Luôn hiện logo cho các menu này
		if is_instance_valid(logo): logo.visible = true

		# Hiện nút đầu tiên của menu mới
		if not options_in.is_empty() and selected_index < options_in.size():
			var element_in = options_in[selected_index]
			if is_instance_valid(element_in):
				element_in.position = center_pos_buttons # Đặt lại vị trí tâm
				element_in.modulate = Color(1, 1, 1, 1)
				element_in.visible = true
	else: # Kết thúc animation chuyển nút trong cùng menu
		var current_options = get_current_options()
		if selected_index >= 0 and selected_index < current_options.size():
			var current_element = current_options[selected_index]
			if is_instance_valid(current_element):
				current_element.position = center_pos_buttons
				current_element.modulate = Color(1, 1, 1, 1)
				current_element.visible = true


func _hide_all_menu_elements():
	var all_elements: Array[Control] = []
	all_elements.append_array(main_menu_options)
	all_elements.append_array(mode_select_options)
	all_elements.append_array(difficulty_select_options)
	# Không cần thêm map_select_options nữa
	for element in all_elements:
		if is_instance_valid(element):
			element.visible = false


# --- Các hàm xử lý nhấn nút ---
func _on_play_button_pressed():
	transition_to_menu(MenuState.MODE_SELECT)

func _on_exit_button_pressed():
	if is_instance_valid(exitButton): exitButton.visible = false
	get_tree().quit()

func _on_vs_player_pressed():
	is_animating = true
	# !!! THAY ĐỔI ĐƯỜNG DẪN NÀY - SCENE CHO 2P !!!
	get_tree().change_scene_to_file("res://scene/mainmenu/Map2p.tscn") # Ví dụ

func _on_vs_ai_pressed():
	transition_to_menu(MenuState.DIFFICULTY_SELECT) # Chuyển sang chọn độ khó

# --- HÀM XỬ LÝ MỚI CHO ĐỘ KHÓ ---
func _on_easy_pressed():
	print("Difficulty Selected: Easy")
	# TODO: Lưu độ khó vào Autoload Singleton, ví dụ: GlobalSettings.ai_difficulty = "easy"
	is_animating = true
	# Chuyển đến scene game AI
	# !!! THAY ĐỔI ĐƯỜNG DẪN NÀY - SCENE CHO AI !!!
	get_tree().change_scene_to_file("res://scene/mainmenu/MapEasySelect.tscn") # Ví dụ

func _on_hard_pressed():
	print("Difficulty Selected: Hard")
	# TODO: Lưu độ khó vào Autoload Singleton, ví dụ: GlobalSettings.ai_difficulty = "hard"
	is_animating = true
	# Chuyển đến scene game AI
	# !!! THAY ĐỔI ĐƯỜNG DẪN NÀY - SCENE CHO AI !!!
	get_tree().change_scene_to_file("res://scene/mainmenu/MapHard.tscn") # Ví dụ


# --- CÁC HÀM LIÊN QUAN ĐẾN MAP SELECT KHÔNG CẦN NỮA ---
# func _on_map_selected(): ...
# func update_map_selection_visuals(): ...


# Hàm process không thay đổi
func _process(delta):
	# if is_animating: return
	var center_vp = get_viewport_rect().size / 2
	var mouseOffset = get_global_mouse_position() - center_vp
	if is_instance_valid(bg1): bg1.position = center_vp + mouseOffset * 0.005
	if is_instance_valid(bg2): bg2.position = center_vp + mouseOffset * 0.008
	if is_instance_valid(bg3): bg3.position = center_vp + mouseOffset * 0.011
	if is_instance_valid(bg4): bg4.position = center_vp + mouseOffset * 0.014
	if is_instance_valid(bg5): bg5.position = center_vp + mouseOffset * 0.01
	if is_instance_valid(bg6): bg6.position = center_vp + mouseOffset * 0.01
