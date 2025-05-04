extends CharacterBody2D

const SPEED = 20.0
# TILE_SIZE sẽ được lấy từ TileSet của ground_layer

# --- Tham chiếu đến các Node cần thiết ---
@export var player_node_path: NodePath # Kéo Node Player vào đây
@export var map_parent_node_path: NodePath # Kéo Node Map4 (cha của các layer) vào đây
@export var ground_layer_path: NodePath    # Kéo Node TileMapLayer "ground" vào đây
@export var brick_layer_path: NodePath     # Kéo Node TileMapLayer "brick" vào đây (Tùy chọn)
@export var kothepha_layer_path: NodePath  # Kéo Node TileMapLayer "kothepha" vào đây (Tùy chọn)

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var player: CharacterBody2D = get_node_or_null(player_node_path)
@onready var map_parent: Node2D = get_node_or_null(map_parent_node_path)
@onready var ground_layer: TileMapLayer = get_node_or_null(ground_layer_path)
@onready var brick_layer: TileMapLayer = get_node_or_null(brick_layer_path)
@onready var kothepha_layer: TileMapLayer = get_node_or_null(kothepha_layer_path)

# --- Biến cho A* Pathfinding ---
var astar_grid: AStarGrid2D = AStarGrid2D.new()
var current_path: Array[Vector2i] = []
var target_world_position: Vector2 = Vector2.ZERO
var tile_size : Vector2 = Vector2.ZERO # Sẽ lấy từ ground_layer

# --- Biến trạng thái ---
enum MovementState { IDLE, PATHFINDING, RANDOM_MOVE }
var current_state: MovementState = MovementState.IDLE
var last_known_player_grid_pos: Vector2i = Vector2i.MAX # Dùng Vector2i.MAX để chắc chắn khác biệt ban đầu
var path_update_timer: Timer = Timer.new()
var random_move_timer: Timer = Timer.new()
var random_direction: Vector2 = Vector2.ZERO

# --- Biến Animation ---
var last_direction_anim: String = "south"

#-----------------------------------------------------------------------------
# HÀM KHỞI TẠO VÀ THIẾT LẬP
#-----------------------------------------------------------------------------
func _ready() -> void:
	# --- Kiểm tra các node quan trọng ---
	if not player:
		push_error("Enemy: Player node not found at path: " + str(player_node_path))
		set_physics_process(false); return
	if not map_parent:
		push_error("Enemy: Map Parent node (Map4) not found at path: " + str(map_parent_node_path))
		set_physics_process(false); return
	if not ground_layer:
		push_error("Enemy: Ground Layer node not found at path: " + str(ground_layer_path))
		set_physics_process(false); return
	if not brick_layer: print("Enemy: Brick Layer node not found.")
	if not kothepha_layer: print("Enemy: Kothepha Layer node not found.")

	# --- Lấy Tile Size ---
	if ground_layer.tile_set: tile_size = ground_layer.tile_set.tile_size
	else: push_error("Enemy: Ground Layer no TileSet!"); set_physics_process(false); return
	if tile_size == Vector2.ZERO: push_error("Enemy: Tile Size is zero!"); set_physics_process(false); return
	print("Obtained Tile Size: ", tile_size)

	# --- Cài đặt AStarGrid2D ---
	astar_grid.cell_size = tile_size
	astar_grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	var map_rect = ground_layer.get_used_rect()
	if map_rect.has_area():
		astar_grid.region = map_rect
		astar_grid.offset = ground_layer.map_to_local(map_rect.position)
		print("AStar Initialized - Region:", astar_grid.region, "Offset:", astar_grid.offset)
		update_astar_grid() # Cập nhật lần đầu
	else:
		push_warning("Enemy: Ground Layer empty! A* grid starts empty.")
		astar_grid.region = Rect2i(); astar_grid.offset = Vector2.ZERO; astar_grid.update()

	# --- Cài đặt Timer cập nhật đường đi (NHANH HƠN) ---
	path_update_timer.wait_time = 0.15 # <--- GIẢM THỜI GIAN CHỜ
	path_update_timer.one_shot = false
	path_update_timer.autostart = true
	path_update_timer.connect("timeout", Callable(self, "_on_path_update_timer_timeout"))
	add_child(path_update_timer)

	# --- Cài đặt Timer di chuyển ngẫu nhiên ---
	random_move_timer.wait_time = 1.0
	random_move_timer.one_shot = false
	random_move_timer.autostart = true
	random_move_timer.connect("timeout", Callable(self, "_on_random_move_timer_timeout"))
	add_child(random_move_timer)
	_on_random_move_timer_timeout()

	current_state = MovementState.IDLE

#-----------------------------------------------------------------------------
# HÀM XỬ LÝ VẬT LÝ
#-----------------------------------------------------------------------------
func _physics_process(delta: float) -> void:
	var move_direction = Vector2.ZERO
	var desired_velocity = Vector2.ZERO

	match current_state:
		MovementState.PATHFINDING:
			move_direction = _follow_path(delta)
			if move_direction.length_squared() > 0: # Kiểm tra để tránh normalize zero vector
				desired_velocity = move_direction.normalized() * SPEED
		MovementState.RANDOM_MOVE:
			move_direction = _move_randomly(delta)
			if move_direction.length_squared() > 0:
				desired_velocity = move_direction.normalized() * SPEED
		MovementState.IDLE:
			pass

	velocity = desired_velocity # Đặt vận tốc trực tiếp
	move_and_slide()
	_update_animation(velocity)

#-----------------------------------------------------------------------------
# HÀM CẬP NHẬT LƯỚI A*
#-----------------------------------------------------------------------------
func update_astar_grid() -> void:
	if not ground_layer or not is_instance_valid(ground_layer) or tile_size == Vector2.ZERO: return

	astar_grid.clear()
	var current_map_rect: Rect2i = ground_layer.get_used_rect()
	if not current_map_rect.has_area():
		astar_grid.region = Rect2i(); astar_grid.offset = Vector2.ZERO; astar_grid.update()
		return

	astar_grid.cell_size = tile_size
	astar_grid.region = current_map_rect
	astar_grid.offset = ground_layer.map_to_local(current_map_rect.position)

	for x in range(astar_grid.region.position.x, astar_grid.region.end.x):
		for y in range(astar_grid.region.position.y, astar_grid.region.end.y):
			var map_coords = Vector2i(x, y)
			var is_solid = false
			var kothepha_data = null
			if kothepha_layer and is_instance_valid(kothepha_layer): kothepha_data = kothepha_layer.get_cell_tile_data(map_coords)
			var brick_data = null
			if brick_layer and is_instance_valid(brick_layer): brick_data = brick_layer.get_cell_tile_data(map_coords)
			var ground_data = ground_layer.get_cell_tile_data(map_coords)
			if ground_data == null or brick_data != null or kothepha_data != null: is_solid = true
			if is_solid: astar_grid.set_point_solid(map_coords, true)
	astar_grid.update()

#-----------------------------------------------------------------------------
# HÀM TÌM ĐƯỜNG ĐI
#-----------------------------------------------------------------------------
func _try_find_path() -> void:
	if not player or not is_instance_valid(player) or \
	   not ground_layer or not is_instance_valid(ground_layer) or \
	   not map_parent or not is_instance_valid(map_parent):
		print("Pathfinding aborted: Nodes invalid.")
		current_state = MovementState.RANDOM_MOVE; current_path.clear(); return

	var start_local_pos = map_parent.to_local(global_position)
	var start_map_pos: Vector2i = ground_layer.local_to_map(start_local_pos)
	var end_local_pos = map_parent.to_local(player.global_position)
	var end_map_pos: Vector2i = ground_layer.local_to_map(end_local_pos)

	if not astar_grid.region.has_point(start_map_pos): print("Path Error: Start out of bounds"); current_path.clear(); current_state = MovementState.RANDOM_MOVE; return
	if not astar_grid.region.has_point(end_map_pos): print("Path Error: End out of bounds"); current_path.clear(); current_state = MovementState.RANDOM_MOVE; return
	if astar_grid.is_point_solid(start_map_pos): print("Path Error: Start is solid"); current_path.clear(); current_state = MovementState.RANDOM_MOVE; return
	if astar_grid.is_point_solid(end_map_pos): print("Path Error: End is solid"); current_path.clear(); current_state = MovementState.RANDOM_MOVE; return

	var new_path: Array[Vector2i] = astar_grid.get_id_path(start_map_pos, end_map_pos)

	if not new_path.is_empty():
		if new_path.size() > 0 : new_path.pop_front()
		if not new_path.is_empty():
			current_path = new_path
			_update_target_world_position()
			current_state = MovementState.PATHFINDING
		else:
			current_path.clear(); current_state = MovementState.IDLE
	else:
		current_path.clear(); target_world_position = global_position
		current_state = MovementState.RANDOM_MOVE

	last_known_player_grid_pos = end_map_pos

#-----------------------------------------------------------------------------
# HÀM CẬP NHẬT VỊ TRÍ ĐÍCH THẾ GIỚI
#-----------------------------------------------------------------------------
func _update_target_world_position():
	if current_path.is_empty() or not ground_layer or not is_instance_valid(ground_layer) or \
	   not map_parent or not is_instance_valid(map_parent):
		target_world_position = global_position; return

	var target_map_pos = current_path[0]
	var target_local_pos = ground_layer.map_to_local(target_map_pos) + tile_size / 2.0
	target_world_position = map_parent.to_global(target_local_pos)

#-----------------------------------------------------------------------------
# HÀM DI CHUYỂN THEO ĐƯỜNG ĐI A* (QUAY LẠI NGƯỠNG HỢP LÝ HƠN)
#-----------------------------------------------------------------------------
func _follow_path(delta: float) -> Vector2:
	if current_path.is_empty():
		current_state = MovementState.IDLE
		return Vector2.ZERO

	var direction_to_target = (target_world_position - global_position)

	# --- LOGIC KIỂM TRA ĐẾN NƠI VỚI NGƯỠNG HỢP LÝ VÀ KIỂM TRA OVERSHOOT ---
	# Quay lại ngưỡng lớn hơn một chút, ví dụ 0.15 hoặc 0.2
	var distance_threshold_sq = (tile_size.x * 0.15) * (tile_size.x * 0.15)
	var distance_sq = global_position.distance_squared_to(target_world_position)
	# Ước tính bình phương quãng đường di chuyển trong frame này
	var movement_this_frame_sq = (SPEED * delta) * (SPEED * delta)

	# Kiểm tra đến nơi: Đủ gần HOẶC có khả năng đã di chuyển vượt qua trong frame này
	if distance_sq < distance_threshold_sq or (distance_sq > 0 and distance_sq < movement_this_frame_sq):
		# print("Reached waypoint threshold for", current_path[0]) # Debug

		# 1. ĐƯA VỀ TÂM Ô VỪA ĐẾN
		global_position = target_world_position

		# 2. Xóa điểm vừa đến khỏi đường đi
		current_path.pop_front()

		# 3. Nếu còn điểm tiếp theo, cập nhật mục tiêu mới
		if not current_path.is_empty():
			_update_target_world_position() # Cập nhật target_world_position
			# Tính lại hướng cho mục tiêu mới để sử dụng ngay
			direction_to_target = (target_world_position - global_position)
		else:
			# Hết đường đi, thử tìm lại ngay
			# print("Path ended. Attempting immediate re-path.") # Debug
			_try_find_path()

			if current_state == MovementState.PATHFINDING:
				if not current_path.is_empty():
					direction_to_target = (target_world_position - global_position)
				else:
					current_state = MovementState.IDLE; return Vector2.ZERO
			else: # Tìm lại path không thành công
				return Vector2.ZERO

	# Trả về hướng di chuyển
	if direction_to_target.length_squared() > 0.001:
		return direction_to_target.normalized()
	else:
		return Vector2.ZERO

#-----------------------------------------------------------------------------
# HÀM DI CHUYỂN NGẪU NHIÊN
#-----------------------------------------------------------------------------
func _move_randomly(delta: float) -> Vector2:
	if random_direction == Vector2.ZERO:
		_on_random_move_timer_timeout()
		if random_direction == Vector2.ZERO: return Vector2.ZERO
	return random_direction # Normalized trong _physics_process

func _on_random_move_timer_timeout() -> void:
	if not ground_layer or not is_instance_valid(ground_layer) or \
	   not map_parent or not is_instance_valid(map_parent) or \
	   astar_grid.region.size == Vector2i.ZERO:
		random_direction = Vector2.ZERO; return

	var possible_directions = []
	var directions = [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]
	var current_local_pos = map_parent.to_local(global_position)
	var current_map_pos = ground_layer.local_to_map(current_local_pos)

	for dir_vec in directions:
		var next_map_pos = current_map_pos + Vector2i(round(dir_vec.x), round(dir_vec.y))
		if astar_grid.region.has_point(next_map_pos) and not astar_grid.is_point_solid(next_map_pos):
			possible_directions.append(dir_vec)

	if not possible_directions.is_empty(): random_direction = possible_directions[randi() % possible_directions.size()]
	else: random_direction = Vector2.ZERO

#-----------------------------------------------------------------------------
# HÀM CALLBACK CHO TIMER CẬP NHẬT ĐƯỜNG ĐI (KHÔNG UPDATE GRID)
#-----------------------------------------------------------------------------
func _on_path_update_timer_timeout() -> void:
	if not player or not is_instance_valid(player) or \
	   not ground_layer or not is_instance_valid(ground_layer) or \
	   not map_parent or not is_instance_valid(map_parent): return

	var current_player_local_pos = map_parent.to_local(player.global_position)
	var current_player_grid_pos = ground_layer.local_to_map(current_player_local_pos)

	if current_player_grid_pos != last_known_player_grid_pos or \
	   current_state == MovementState.RANDOM_MOVE or \
	   current_state == MovementState.IDLE:
		# *** KHÔNG GỌI update_astar_grid() Ở ĐÂY ***
		_try_find_path() # Chỉ tìm đường trên grid hiện có

#-----------------------------------------------------------------------------
# HÀM CẬP NHẬT ANIMATION
#-----------------------------------------------------------------------------
func _update_animation(move_velocity: Vector2) -> void:
	if not is_instance_valid(animated_sprite): return

	if move_velocity.length_squared() < 0.1:
		if not animated_sprite.animation.begins_with("idle"):
			animated_sprite.play("idle_" + last_direction_anim)
	else:
		var direction_str = ""
		if abs(move_velocity.x) > abs(move_velocity.y): direction_str = "east" if move_velocity.x > 0 else "west"
		else: direction_str = "south" if move_velocity.y > 0 else "north"
		var target_anim = "run_" + direction_str
		if animated_sprite.animation != target_anim: animated_sprite.play(target_anim)
		last_direction_anim = direction_str

#-----------------------------------------------------------------------------
# HÀM GỌI KHI MAP THAY ĐỔI
#-----------------------------------------------------------------------------
func on_map_changed() -> void:
	print("Map possibly changed. Updating AStar grid and retrying path.")
	update_astar_grid() # CHỈ CẬP NHẬT GRID KHI MAP THAY ĐỔI
	_try_find_path()

#-----------------------------------------------------------------------------
# HÀM XỬ LÝ KHI ENEMY CHẾT
#-----------------------------------------------------------------------------
func _on_area_2d_body_entered(body):
	if body.is_in_group("players"):
		if body.has_method("die"):
			body.die()

var is_dead := false

func die():
	# (Giữ nguyên code die của bạn)
	if is_dead:
		return
	is_dead = true
	velocity = Vector2.ZERO
	set_physics_process(false)
	animated_sprite.play("die")
	await get_tree().create_timer(0.5).timeout
	queue_free()
