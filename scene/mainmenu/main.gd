extends Node2D

@onready var bg1 := $bg1
@onready var bg2 := $bg2
@onready var bg3 := $bg3
@onready var bg4 := $bg4
@onready var bg5 := $bg5
@onready var bg6 := $bg6
const VERTICAL_OFFSET := -10

# --- UI Elements ---
@onready var logo := $Logo
@onready var uiAnchor := $UIAnchor

@onready var playButton := $UIAnchor/PlayButton
@onready var exitButton := $UIAnchor/ExitButton
@onready var vsPlayerButton := $UIAnchor/VsPlayerButton
@onready var vsAIButton := $UIAnchor/VsAIButton
@onready var easyButton := $UIAnchor/EasyButton
@onready var hardButton := $UIAnchor/HardButton

# Các trạng thái menu
enum MenuState { MAIN, MODE_SELECT, DIFFICULTY_SELECT }
var current_menu_state = MenuState.MAIN
var previous_menu_state: MenuState = MenuState.MAIN
# Mảng chứa các elements cho từng menu
var main_menu_options: Array[Control] = []
var mode_select_options: Array[Control] = []
var difficulty_select_options: Array[Control] = []
var selected_index: int = 0

# --- Biến Animation ---
var is_animating: bool = false
var current_tween: Tween
var center_pos_buttons: Vector2 # Vị trí trung tâm *cơ sở* cho các nút bấm

var start_pos_offset: Vector2 = Vector2(0, 50) # Offset vị trí bắt đầu animation
var end_pos_offset: Vector2 = Vector2(0, -50)   # Offset vị trí kết thúc animation
var animation_duration: float = 0.3
const SPECIFIC_BUTTON_X_OFFSET : float = 4.0 # Lượng dịch chuyển X cho nút đặc biệt

# --- Hàm Helper ---
# Hàm này tính toán vị trí cuối cùng, áp dụng offset X cho các nút cụ thể
func get_adjusted_position(button: Control, base_position: Vector2) -> Vector2:
	var adjusted_pos = base_position
	# Kiểm tra xem nút có hợp lệ và là VsPlayer hoặc VsAI không
	if is_instance_valid(button) and (button == vsPlayerButton or button == vsAIButton):
		adjusted_pos.x += SPECIFIC_BUTTON_X_OFFSET # Thêm offset X
	return adjusted_pos

# --- Hàm Khởi tạo ---
func _ready():
	# --- Kiểm tra node ---
	if not is_instance_valid(logo): printerr("Logo node missing!")
	if not is_instance_valid(playButton): printerr("PlayButton missing!")
	# ... (thêm các kiểm tra khác nếu cần) ...
	if not is_instance_valid(vsPlayerButton): printerr("VsPlayerButton missing!")
	if not is_instance_valid(vsAIButton): printerr("VsAIButton missing!")
	if not is_instance_valid(easyButton): printerr("EasyButton missing!")
	if not is_instance_valid(hardButton): printerr("HardButton missing!")

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

	# Xác định vị trí trung tâm CƠ SỞ cho các nút bấm (từ PlayButton)
	if is_instance_valid(playButton):
		center_pos_buttons = playButton.position
	else:
		center_pos_buttons = Vector2.ZERO; printerr("PlayButton invalid, using ZERO position!")

	# --- Thiết lập trạng thái ban đầu cho tất cả nút bấm ---
	var all_buttons = main_menu_options + mode_select_options + difficulty_select_options
	for button_control in all_buttons:
		if not is_instance_valid(button_control) or not button_control is Button: continue
		var button = button_control as Button

		# Đặt text
		if button == playButton: button.text = "Play"
		elif button == exitButton: button.text = "Quit"
		elif button == vsPlayerButton: button.text = "PVP"
		elif button == vsAIButton: button.text = "PVE"
		elif button == easyButton: button.text = "Easy"
		elif button == hardButton: button.text = "Hard"

		button.focus_mode = Control.FOCUS_NONE
		# Đặt vị trí ban đầu (ẩn) đã điều chỉnh
		button.position = get_adjusted_position(button, center_pos_buttons + start_pos_offset)
		button.modulate.a = 0.0

		# Kết nối signal (kiểm tra để tránh kết nối lại)
		var signals = button.get_signal_connection_list("pressed")
		var connected = false
		for connection in signals:
			if connection.callable.get_object() == self:
				connected = true
				break
		if not connected:
			if button == playButton: button.pressed.connect(_on_play_button_pressed)
			elif button == exitButton: button.pressed.connect(_on_exit_button_pressed)
			elif button == vsPlayerButton: button.pressed.connect(_on_vs_player_pressed)
			elif button == vsAIButton: button.pressed.connect(_on_vs_ai_pressed)
			elif button == easyButton: button.pressed.connect(_on_easy_pressed)
			elif button == hardButton: button.pressed.connect(_on_hard_pressed)

	# --- Hoàn tất thiết lập ban đầu ---
	_hide_all_menu_elements() # Ẩn tất cả nút

	selected_index = 0 # Bắt đầu ở menu chính
	if not main_menu_options.is_empty():
		var initial_button = main_menu_options[selected_index]
		if is_instance_valid(initial_button):
			# Đặt vị trí cho nút đầu tiên hiển thị (đã điều chỉnh)
			initial_button.position = get_adjusted_position(initial_button, center_pos_buttons)
			initial_button.modulate.a = 1.0
			initial_button.visible = true
	else:
		printerr("Main menu has no valid options!")

	if is_instance_valid(logo): logo.visible = true # Hiện logo
	set_process_unhandled_input(true)

	Music.play_music("res://assets/Sound/Pixel Triumph(menu).mp3")

# Lấy danh sách các nút cho menu hiện tại
func get_current_options() -> Array[Control]:
	match current_menu_state:
		MenuState.MAIN: return main_menu_options
		MenuState.MODE_SELECT: return mode_select_options
		MenuState.DIFFICULTY_SELECT: return difficulty_select_options
		_: return []

# Xử lý input không được xử lý bởi UI
func _unhandled_input(event: InputEvent):
	if event.is_action_pressed("ui_cancel"):
		Music.play_sfx("res://assets/Sound/retro-select-236670.mp3")
		if current_menu_state != MenuState.MAIN:
			transition_to_menu(previous_menu_state) # Quay lại menu trước đó
			get_viewport().set_input_as_handled()
		return

	if not is_inside_tree() or is_animating: return

	var current_options = get_current_options()
	if current_options.is_empty(): return

	var direction = 0
	var accept_pressed = false

	if event.is_action_pressed("ui_down") or event.is_action_pressed("down_p1"):
		Music.play_sfx("res://assets/Sound/retro-select-236670.mp3")
		direction = 1
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_up") or event.is_action_pressed("up_p1"):
		Music.play_sfx("res://assets/Sound/retro-select-236670.mp3")
		direction = -1
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_accept") or event.is_action_pressed("boom_p1"):
		accept_pressed = true
		get_viewport().set_input_as_handled()

	if accept_pressed:
		if selected_index >= 0 and selected_index < current_options.size():
			var selected_element = current_options[selected_index]
			if selected_element is Button:
				Music.play_sfx("res://assets/Sound/retro-select-236670.mp3")
				selected_element.emit_signal("pressed")
		return

	if direction != 0:
		var previous_index = selected_index
		selected_index = (selected_index + direction + current_options.size()) % current_options.size()
		if previous_index != selected_index:
			start_transition_animation(previous_index, selected_index, current_options)


# Bắt đầu animation chuyển đổi giữa các nút trong cùng menu
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
	# Đặt vị trí bắt đầu cho nút "vào" (đã điều chỉnh)
	button_in.position = get_adjusted_position(button_in, center_pos_buttons + start_pos_offset)
	button_in.modulate.a = 0.0
	button_in.visible = true

	if current_tween and current_tween.is_valid(): current_tween.kill()
	current_tween = create_tween()
	current_tween.set_parallel(true)
	current_tween.set_trans(Tween.TRANS_SINE)
	current_tween.set_ease(Tween.EASE_OUT)

	# Tween vị trí nút "ra" đến vị trí kết thúc (đã điều chỉnh)
	current_tween.tween_property(button_out, "position", get_adjusted_position(button_out, center_pos_buttons + end_pos_offset), animation_duration)
	current_tween.tween_property(button_out, "modulate:a", 0.0, animation_duration * 0.8).set_delay(animation_duration * 0.1)
	# Tween vị trí nút "vào" đến vị trí trung tâm (đã điều chỉnh)
	current_tween.tween_property(button_in, "position", get_adjusted_position(button_in, center_pos_buttons), animation_duration)
	current_tween.tween_property(button_in, "modulate:a", 1.0, animation_duration * 0.8).set_delay(animation_duration * 0.1)

	current_tween.finished.connect(_on_transition_animation_finished.bind(button_out, false)) # false = không phải chuyển menu

# Bắt đầu animation chuyển đổi giữa các menu
func transition_to_menu(target_state: MenuState):
	if is_animating: return
	var options_out = get_current_options()
	if options_out.is_empty() or selected_index < 0 or selected_index >= options_out.size(): return
	var element_out = options_out[selected_index]
	if not is_instance_valid(element_out): return

	is_animating = true

	if current_tween and current_tween.is_valid(): current_tween.kill()
	current_tween = create_tween()

	# Tính toán vị trí kết thúc cho animation ẩn (đã điều chỉnh)
	var base_end_pos = center_pos_buttons + end_pos_offset
	var adjusted_end_pos = get_adjusted_position(element_out, base_end_pos)

	# Tween ẩn element cũ
	current_tween.tween_property(element_out, "position", adjusted_end_pos, animation_duration)
	current_tween.tween_property(element_out, "modulate:a", 0.0, animation_duration * 0.8).set_delay(animation_duration * 0.1)

	# Kết nối để xử lý sau khi animation ẩn kết thúc
	current_tween.finished.connect(_on_transition_animation_finished.bind(element_out, true, target_state))

# Được gọi khi animation chuyển đổi (nút hoặc menu) hoàn tất
func _on_transition_animation_finished(element_that_animated_out: Control, is_menu_transition: bool, target_state: MenuState = MenuState.MAIN):
	is_animating = false

	# Ẩn element vừa di chuyển ra (nếu hợp lệ)
	if element_that_animated_out and is_instance_valid(element_that_animated_out):
		element_that_animated_out.visible = false

	# Xác định vị trí mục tiêu cơ sở (không đổi)
	var base_target_position = center_pos_buttons

	if is_menu_transition:
		previous_menu_state = current_menu_state
		current_menu_state = target_state

		selected_index = 0
		var options_in = get_current_options()
		if options_in.is_empty(): return

		_hide_all_menu_elements() # Ẩn tất cả trước khi hiện cái mới

		if is_instance_valid(logo): logo.visible = true # Đảm bảo logo hiện

		# Hiện nút đầu tiên của menu mới
		if not options_in.is_empty() and selected_index < options_in.size():
			var element_in = options_in[selected_index]
			if is_instance_valid(element_in):
				# Đặt vị trí cuối cùng (đã điều chỉnh)
				element_in.position = get_adjusted_position(element_in, base_target_position)
				element_in.modulate = Color.WHITE # Đặt lại màu/alpha
				element_in.visible = true
	else: # Kết thúc animation chuyển nút trong cùng menu
		var current_options = get_current_options()
		if selected_index >= 0 and selected_index < current_options.size():
			var current_element = current_options[selected_index]
			if is_instance_valid(current_element):
				# Đặt vị trí cuối cùng (đã điều chỉnh)
				current_element.position = get_adjusted_position(current_element, base_target_position)
				current_element.modulate = Color.WHITE # Đặt lại màu/alpha
				current_element.visible = true # Đảm bảo nó hiện rõ

# Ẩn tất cả các nút trong các menu
func _hide_all_menu_elements():
	var all_elements = main_menu_options + mode_select_options + difficulty_select_options
	for element in all_elements:
		if is_instance_valid(element):
			element.visible = false

# --- Các hàm xử lý nhấn nút ---
func _on_play_button_pressed():
	Music.play_sfx("res://assets/Sound/retro-select-236670.mp3")
	transition_to_menu(MenuState.MODE_SELECT)

func _on_exit_button_pressed():
	Music.play_sfx("res://assets/Sound/retro-select-236670.mp3")
	if is_instance_valid(exitButton): exitButton.visible = false # Ẩn nút trước khi thoát
	get_tree().quit()

func _on_vs_player_pressed():
	Music.play_sfx("res://assets/Sound/retro-select-236670.mp3")
	is_animating = true # Ngăn input khác khi đang chuyển scene
	get_tree().change_scene_to_file("res://scene/mainmenu/Map2p.tscn") # !!! KIỂM TRA ĐƯỜNG DẪN !!!

func _on_vs_ai_pressed():
	Music.play_sfx("res://assets/Sound/retro-select-236670.mp3")
	transition_to_menu(MenuState.DIFFICULTY_SELECT) # Chuyển sang chọn độ khó

func _on_easy_pressed():
	Music.play_sfx("res://assets/Sound/retro-select-236670.mp3")
	print("Difficulty Selected: Easy")
	# Ví dụ lưu độ khó: GlobalSettings.ai_difficulty = "easy" (cần tạo Autoload GlobalSettings)
	is_animating = true
	get_tree().change_scene_to_file("res://scene/mainmenu/MapEasySelect.tscn") # !!! KIỂM TRA ĐƯỜNG DẪN !!!

func _on_hard_pressed():
	Music.play_sfx("res://assets/Sound/retro-select-236670.mp3")
	print("Difficulty Selected: Hard")
	# Ví dụ lưu độ khó: GlobalSettings.ai_difficulty = "hard"
	is_animating = true
	get_tree().change_scene_to_file("res://scene/mainmenu/MapHardSelect.tscn") # !!! KIỂM TRA ĐƯỜNG DẪN !!!

# --- Hàm Process (Parallax Background) ---
func _process(delta):
	# Không cần kiểm tra is_animating ở đây vì nó chỉ ảnh hưởng background
	var center_vp = get_viewport_rect().size / 2.0
	var mouse_offset = get_global_mouse_position() - center_vp
	if is_instance_valid(bg1): bg1.position = center_vp + mouse_offset * 0.005
	if is_instance_valid(bg2): bg2.position = center_vp + mouse_offset * 0.008
	if is_instance_valid(bg3): bg3.position = center_vp + mouse_offset * 0.011
	if is_instance_valid(bg4): bg4.position = center_vp + mouse_offset * 0.014
	if is_instance_valid(bg5): bg5.position = center_vp + mouse_offset * 0.010 # Điều chỉnh lại chút
	if is_instance_valid(bg6): bg6.position = center_vp + mouse_offset * 0.010 # Điều chỉnh lại chút	
