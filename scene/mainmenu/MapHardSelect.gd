extends Node2D

# --- Tham chiếu đến các Node Preview Map ---
# !!! Đảm bảo các đường dẫn này đúng !!!
@onready var map1Preview := $Map1Preview
@onready var map2Preview := $Map2Preview
@onready var map3Preview := $Map3Preview
@onready var map4Preview := $Map4Preview
@onready var map5Preview := $Map5Preview

# Mảng chứa các node preview theo thứ tự điều hướng (Trái sang Phải)
var map_select_options: Array[Node2D] = [] # Node2D là lớp cha chung
var selected_index: int = 0

# --- Dữ liệu Map ---
# !!! THAY ĐỔI ĐƯỜNG DẪN NÀY CHO ĐÚNG VỚI CÁC SCENE MAP EASY CỦA BẠN !!!
var map_data := {
	"Map1Preview": "res://scene/map/map1/map1_pve_hard.tscn",
	"Map2Preview": "res://scene/map/map2/map2_pve_hard.tscn",
	"Map3Preview": "res://scene/map/map3/map3_pve_hard.tscn",
	"Map4Preview": "res://scene/map/map4/map4_pve_hard.tscn",
	"Map5Preview": "res://scene/map/map5/map5_pve_hard.tscn",
}

# --- Visuals cho Map Select ---
const NORMAL_SCALE := Vector2(0.2333, 0.2333) # Scale bình thường là scale bạn đặt
const SELECTED_SCALE := NORMAL_SCALE * 1.2 # Scale khi chọn là 120% của normal
const SELECTED_MODULATE := Color(1, 1, 1, 1) # Rõ ràng
const NORMAL_MODULATE := Color(0.8, 0.8, 0.8, 1) # Hơi mờ/xám đi một chút
const SCALE_DURATION: float = 0.3 # Thời gian tween scale

var current_scale_tween: Tween # Để quản lý animation scale

func _ready():
	# --- Khởi tạo mảng options ---
	var previews_to_add = [
		get_node_or_null("Map1Preview"), get_node_or_null("Map2Preview"),
		get_node_or_null("Map3Preview"), get_node_or_null("Map4Preview"),
		get_node_or_null("Map5Preview")
	]
	map_select_options.clear()
	for preview in previews_to_add:
		if is_instance_valid(preview) and (preview is Sprite2D or preview is TextureRect):
			map_select_options.append(preview)
			if preview is TextureRect:
				preview.pivot_offset = preview.texture.get_size() / 2.0 if preview.texture else preview.size / 2.0
			elif preview is Sprite2D and not preview.centered:
				if preview.texture:
					preview.offset = -preview.texture.get_size() / 2.0
			preview.visible = true # Đảm bảo hiện
			# Scale ban đầu sẽ được đặt bởi update_selection_visuals(true)
		else:
			printerr("Failed to find or validate preview node: ", preview)

	if map_select_options.is_empty():
		printerr("Map Select Error: No valid map preview nodes found!")
		set_process_unhandled_input(false)
		return

	# --- Thiết lập trạng thái ban đầu ---
	selected_index = 0
	update_selection_visuals(true) # Đặt scale/modulate ban đầu ngay lập tức
	set_process_unhandled_input(true)


func _unhandled_input(event: InputEvent):
	if map_select_options.is_empty(): return

	var direction = 0
	var accept_pressed = false

	if event.is_action_pressed("ui_right"): direction = 1
	elif event.is_action_pressed("ui_left"): direction = -1
	elif event.is_action_pressed("ui_accept"): accept_pressed = true

	if direction != 0:
		get_viewport().set_input_as_handled()
		var previous_index = selected_index
		selected_index = (selected_index + direction + map_select_options.size()) % map_select_options.size()
		if previous_index != selected_index:
			update_selection_visuals() # Bắt đầu animation scale/modulate
	elif accept_pressed:
		get_viewport().set_input_as_handled()
		_load_selected_map()


func update_selection_visuals(instant: bool = false):
	if current_scale_tween and current_scale_tween.is_valid():
		current_scale_tween.kill()

	current_scale_tween = create_tween()
	current_scale_tween.set_parallel(true)
	current_scale_tween.set_trans(Tween.TRANS_SINE)
	current_scale_tween.set_ease(Tween.EASE_OUT)

	for i in range(map_select_options.size()):
		var preview_node = map_select_options[i]
		if not is_instance_valid(preview_node): continue

		var target_scale = NORMAL_SCALE
		var target_modulate = NORMAL_MODULATE
		var target_z_index = 0

		if i == selected_index:
			target_scale = SELECTED_SCALE
			target_modulate = SELECTED_MODULATE
			target_z_index = 1

		preview_node.z_index = target_z_index

		if instant:
			preview_node.scale = target_scale
			preview_node.modulate = target_modulate
		else:
			current_scale_tween.tween_property(preview_node, "scale", target_scale, SCALE_DURATION)
			current_scale_tween.tween_property(preview_node, "modulate", target_modulate, SCALE_DURATION)


func _load_selected_map():
	if selected_index < 0 or selected_index >= map_select_options.size():
		printerr("Cannot load map: Invalid selected_index.")
		return
	var selected_preview_node = map_select_options[selected_index]
	if not is_instance_valid(selected_preview_node):
		printerr("Cannot load map: Selected preview node is invalid.")
		return

	var node_name = selected_preview_node.name
	if map_data.has(node_name):
		var scene_path = map_data[node_name]
		print("Loading EASY map: %s (Path: %s)" % [node_name, scene_path])
		set_process_unhandled_input(false)
		var error = get_tree().change_scene_to_file(scene_path)
		if error != OK:
			printerr("Failed to change scene to: %s. Error code: %s" % [scene_path, error])
			set_process_unhandled_input(true)
	else:
		printerr("No scene path found in map_data for preview node: %s" % node_name)
