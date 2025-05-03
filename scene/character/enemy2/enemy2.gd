extends CharacterBody2D

const SPEED = 80.0
# TILE_SIZE sẽ được lấy từ TileSet của ground_layer

# --- Tham chiếu đến các Node cần thiết ---
@export var player_node_path: NodePath # Kéo Node Player vào đây
# THAY ĐỔI: Đường dẫn đến các TileMapLayer cụ thể và node cha chung
@export var map_parent_node_path: NodePath # Kéo Node Map4 (cha của các layer) vào đây
@export var ground_layer_path: NodePath    # Kéo Node TileMapLayer "ground" vào đây
@export var brick_layer_path: NodePath     # Kéo Node TileMapLayer "brick" vào đây
@export var kothepha_layer_path: NodePath  # Kéo Node TileMapLayer "kothepha" vào đây

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var player: CharacterBody2D = get_node_or_null(player_node_path)
# THAY ĐỔI: Lấy các node layer và node cha
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
var last_known_player_grid_pos: Vector2i = Vector2i.MAX
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
	# Các layer khác có thể tùy chọn (nếu không có thì coi như không có vật cản loại đó)
	if not brick_layer:
		print("Enemy: Brick Layer node not found. Assuming no breakable obstacles.")
	if not kothepha_layer:
		print("Enemy: Kothepha Layer node not found. Assuming no unbreakable obstacles.")

	# --- Lấy Tile Size từ ground layer ---
	if ground_layer.tile_set:
		tile_size = ground_layer.tile_set.tile_size
		print("Obtained Tile Size: ", tile_size)
	else:
		push_error("Enemy: Ground Layer does not have a TileSet assigned!")
		set_physics_process(false); return
	if tile_size == Vector2.ZERO:
		push_error("Enemy: Could not determine Tile Size from Ground Layer's TileSet.")
		set_physics_process(false); return


	# --- Cài đặt AStarGrid2D dựa trên ground_layer ---
	astar_grid.cell_size = tile_size # Sử dụng tile_size đã lấy
	astar_grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	# Lấy vùng map sử dụng từ ground_layer
	var map_rect = ground_layer.get_used_rect()
	print("Ground Layer Used Rect: ", map_rect)
	astar_grid.region = map_rect
	# Offset dựa trên hệ tọa độ của ground_layer
	var center_offset = ground_layer.map_to_local(map_rect.position)
	astar_grid.offset = center_offset - tile_size / 2.0
	print("Calculated AStar Offset: ", astar_grid.offset) # DEBUG
	print("AStar Region after set: ", astar_grid.region) # DEBUG Check lại region
	# --- Cập nhật lưới A* lần đầu ---
	update_astar_grid()

	# --- Cài đặt Timer cập nhật đường đi ---
	path_update_timer.wait_time = 0.5
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

	# Đặt trạng thái ban đầu và thử tìm đường
	current_state = MovementState.PATHFINDING
	_try_find_path()

#-----------------------------------------------------------------------------
# HÀM XỬ LÝ VẬT LÝ (DI CHUYỂN, LOGIC AI)
#-----------------------------------------------------------------------------
func _physics_process(delta: float) -> void:
	var move_direction = Vector2.ZERO

	match current_state:
		MovementState.PATHFINDING:
			move_direction = _follow_path(delta)
		MovementState.RANDOM_MOVE:
			move_direction = _move_randomly(delta)
		MovementState.IDLE:
			velocity = Vector2.ZERO

	if current_state != MovementState.IDLE:
		if move_direction != Vector2.ZERO:
			velocity = move_direction.normalized() * SPEED
		else:
			velocity = velocity.move_toward(Vector2.ZERO, SPEED * delta * 4.0)

	move_and_slide()
	_update_animation(velocity)

#-----------------------------------------------------------------------------
# HÀM CẬP NHẬT LƯỚI A* (Sử dụng thông tin động từ ground_layer)
#-----------------------------------------------------------------------------
func update_astar_grid() -> void:
	# --- Kiểm tra điều kiện cần thiết ---
	if not ground_layer:
		print("Update AStar Grid failed: ground_layer not found.")
		return
	# Đảm bảo tile_size đã được lấy từ _ready và hợp lệ
	if tile_size == Vector2.ZERO:
		print("Update AStar Grid failed: tile_size is zero (check _ready).")
		return

	# Bỏ comment nếu muốn thấy log mỗi lần cập nhật
	# print("Enemy: Updating AStar Grid...")

	# 1. Xóa các điểm solid/walkable cũ trong lưới A*
	astar_grid.clear()

	# --- LẤY THÔNG TIN ĐỘNG TỪ ground_layer ---
	# 2. Lấy vùng chữ nhật bao quanh các ô đang được sử dụng trên ground_layer
	var current_map_rect: Rect2i = ground_layer.get_used_rect()

	# 3. Kiểm tra xem layer có thực sự chứa tile nào không
	if not current_map_rect.has_area():
		print("Update AStar Grid warning: Ground layer get_used_rect() is empty! No tiles to base grid on.")
		# Nếu không có tile, đặt region thành rỗng và dừng cập nhật grid này
		astar_grid.region = Rect2i()
		astar_grid.update() # Áp dụng thay đổi (region rỗng)
		return

	# --- THIẾT LẬP LẠI THÔNG SỐ A* DỰA TRÊN DỮ LIỆU ĐỘNG ---
	# 4. Đặt lại cell_size (thường không đổi, nhưng để chắc chắn)
	astar_grid.cell_size = tile_size

	# 5. Đặt lại region dựa trên vùng map thực tế vừa lấy
	astar_grid.region = current_map_rect

	# 6. Đặt lại offset: Vị trí local (trong ground_layer) của ô map đầu tiên (góc trên trái)
	#    Điều này đảm bảo gốc (0,0) của hệ tọa độ A* grid khớp với ô map đầu tiên.
	astar_grid.offset = ground_layer.map_to_local(ground_layer.get_used_rect().position) - tile_size / 2.0
	# -------------------------------------------------------

	# In ra thông tin mới để debug (rất hữu ích)
	print("AStar Updated - CellSize:", astar_grid.cell_size, "Region:", astar_grid.region, "Offset:", astar_grid.offset)

# ... (Phần code trước vòng lặp) ...

	# 7. Duyệt qua các ô trong region mới và đánh dấu vật cản (solid)
	print("--- Identifying Solid Cells ---") # Thêm dòng này để biết bắt đầu kiểm tra
	for x in range(astar_grid.region.position.x, astar_grid.region.end.x):
		for y in range(astar_grid.region.position.y, astar_grid.region.end.y):
			var map_coords = Vector2i(x, y)
			var is_solid = false
			var reason = "" # Biến lưu lý do (tùy chọn nhưng hữu ích)

			# --- Logic kiểm tra solid (Khuyến nghị dùng get_cell_tile_data) ---
			var ground_data = ground_layer.get_cell_tile_data(map_coords)
			var brick_data = null
			var kothepha_data = null
			if brick_layer: brick_data = brick_layer.get_cell_tile_data(map_coords)
			if kothepha_layer: kothepha_data = kothepha_layer.get_cell_tile_data(map_coords)

			if ground_data == null:
				is_solid = true
				reason = "No Ground" # Gán lý do
			else:
				if brick_data != null:
					is_solid = true
					reason = "Brick" # Gán lý do
				elif kothepha_data != null:
					is_solid = true
					reason = "Kothepha" # Gán lý do
				 # else: reason = "Walkable" # Ô đi được
			# -------------------------------------------------------------

			# Đặt điểm solid trong A* nếu cần VÀ IN RA TỌA ĐỘ
			if is_solid:
				astar_grid.set_point_solid(map_coords, true)
				# --- DÒNG THÊM VÀO ĐỂ IN TỌA ĐỘ SOLID ---
				print("Setting solid at map coordinate:", map_coords, "| Reason:", reason)
				# -----------------------------------------
	print("--- Finished Identifying Solid Cells ---") # Thêm dòng này để biết kết thúc kiểm tra

	# 8. QUAN TRỌNG: Gọi update() để A* xử lý các thay đổi về region và points
	astar_grid.update()
	# print("Enemy: AStar Grid Updated successfully.") # Bỏ comment nếu muốn xác nhận hoàn tất

#-----------------------------------------------------------------------------
# HÀM TÌM ĐƯỜNG ĐI
#-----------------------------------------------------------------------------
func _try_find_path() -> void:
	print("Attempting to find path...")
	if not player or not ground_layer or not map_parent:
		print("Pathfinding aborted: Missing required nodes.")
		return

	# --- DEBUG: Tọa độ Global ---
	print("Enemy Global Pos: ", global_position)
	print("Player Global Pos: ", player.global_position)

	var start_local_pos = map_parent.to_local(global_position)
	var start_map_pos: Vector2i = ground_layer.local_to_map(start_local_pos)

	var end_local_pos = map_parent.to_local(player.global_position)
	var end_map_pos: Vector2i = ground_layer.local_to_map(end_local_pos)

	# --- DEBUG: Tọa độ Local và Map ---
	print("Enemy Local Pos (relative to Map4): ", start_map_pos)
	print("Player Local Pos (relative to Map4): ", end_map_pos)
	print("Start Map Pos (Grid): ", start_map_pos, " | End Map Pos (Grid): ", end_map_pos)

	var start_is_solid = astar_grid.is_point_solid(start_map_pos)
	var end_is_solid = astar_grid.is_point_solid(end_map_pos)
	print("Is Start Solid? ", start_is_solid, " | Is End Solid? ", end_is_solid)

	print("Checking bounds against A* Region: ", astar_grid.region)
	if not astar_grid.region.has_point(start_map_pos) or not astar_grid.region.has_point(end_map_pos):
		print("Pathfinding failed: Start or End point is out of A* grid bounds.")
		current_path.clear()
		current_state = MovementState.RANDOM_MOVE
		print("--> State changed to RANDOM_MOVE (Out of Bounds)")
		return

	if start_is_solid or end_is_solid:
		print("Pathfinding failed: Start or End point is solid.")
		current_path.clear()
		current_state = MovementState.RANDOM_MOVE
		print("--> State changed to RANDOM_MOVE (Solid Point)")
		return

	# --- DEBUG: Gọi A* ---
	print("Calling A* get_id_path from ", start_map_pos, " to ", end_map_pos)
	var new_path: Array[Vector2i] = astar_grid.get_id_path(start_map_pos, end_map_pos)
	print("A* result path: ", new_path)

	if not new_path.is_empty():
		# ... (code xử lý path thành công) ...
		current_path = new_path
		print("Path found successfully!")
		_update_target_world_position()
		current_state = MovementState.PATHFINDING
		print("--> State changed to PATHFINDING")
	else:
		print("Pathfinding failed: No path found by A*.")
		current_path.clear()
		target_world_position = global_position
		current_state = MovementState.RANDOM_MOVE
		print("--> State changed to RANDOM_MOVE (No Path Found)")

	last_known_player_grid_pos = end_map_pos

#-----------------------------------------------------------------------------
# HÀM CẬP NHẬT VỊ TRÍ ĐÍCH THẾ GIỚI TỪ GRID PATH
#-----------------------------------------------------------------------------
func _update_target_world_position():
	if current_path.is_empty() or not ground_layer or not map_parent:
		target_world_position = global_position # Đứng yên tại chỗ nếu không có path
		return

	# THAY ĐỔI: Chuyển đổi tọa độ Map sang Global thông qua ground_layer và map_parent
	var target_map_pos = current_path[0]
	# Lấy vị trí local trong ground_layer (tâm ô)
	var target_local_pos = ground_layer.map_to_local(target_map_pos) + tile_size / 2.0
	# Chuyển sang global
	target_world_position = map_parent.to_global(target_local_pos)

#-----------------------------------------------------------------------------
# HÀM DI CHUYỂN THEO ĐƯỜNG ĐI A*
#-----------------------------------------------------------------------------
func _follow_path(delta: float) -> Vector2:
	if current_path.is_empty():
		current_state = MovementState.IDLE
		_try_find_path()
		return Vector2.ZERO

	var direction = (target_world_position - global_position)

	# Ngưỡng khoảng cách nên dựa trên tile_size
	var distance_threshold_sq = (tile_size.x * 0.2) * (tile_size.x * 0.2)
	if global_position.distance_squared_to(target_world_position) < distance_threshold_sq :
		current_path.pop_front()
		if not current_path.is_empty():
			_update_target_world_position() # Cập nhật điểm đến tiếp theo
			direction = (target_world_position - global_position) # Tính lại hướng
		else:
			current_state = MovementState.IDLE
			# _try_find_path() # Bỏ comment nếu muốn tìm lại ngay khi đến đích
			return Vector2.ZERO

	return direction.normalized()

#-----------------------------------------------------------------------------
# HÀM DI CHUYỂN NGẪU NHIÊN
#-----------------------------------------------------------------------------
func _move_randomly(delta: float) -> Vector2:
	var collision = move_and_collide(random_direction.normalized() * SPEED * delta, false)
	if collision:
		_on_random_move_timer_timeout()
		return Vector2.ZERO

	return random_direction.normalized()

func _on_random_move_timer_timeout() -> void:
	if not ground_layer or not map_parent: return

	var directions = [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]
	random_direction = directions[randi() % directions.size()]

	# THAY ĐỔI: Kiểm tra ô kế tiếp có solid không dựa trên A* grid
	var current_local_pos = map_parent.to_local(global_position)
	var current_map_pos = ground_layer.local_to_map(current_local_pos)
	var next_map_pos = current_map_pos + Vector2i(round(random_direction.x), round(random_direction.y))

	if astar_grid.is_point_solid(next_map_pos):
		random_direction = Vector2.ZERO

#-----------------------------------------------------------------------------
# HÀM CALLBACK CHO TIMER CẬP NHẬT ĐƯỜNG ĐI
#-----------------------------------------------------------------------------
func _on_path_update_timer_timeout() -> void:
	# THÊM PRINT: Kiểm tra timer có hoạt động không
	print("Path update timer timeout...")
	if not player or not ground_layer or not map_parent: return

	var current_player_local_pos = map_parent.to_local(player.global_position)
	var current_player_grid_pos = ground_layer.local_to_map(current_player_local_pos)

	# THÊM PRINT: Kiểm tra điều kiện gọi lại _try_find_path
	print("Current Player Grid: ", current_player_grid_pos, " | Last Known: ", last_known_player_grid_pos, " | Current State: ", current_state)

	if current_player_grid_pos != last_known_player_grid_pos or current_state == MovementState.RANDOM_MOVE:
		print("Condition met, trying to find path again...") # THÊM PRINT
		_try_find_path()

#-----------------------------------------------------------------------------
# HÀM CẬP NHẬT ANIMATION (Giữ nguyên)
#-----------------------------------------------------------------------------
func _update_animation(move_velocity: Vector2) -> void:
	# ... (Giữ nguyên code animation của bạn)
	if move_velocity == Vector2.ZERO:
		if not animated_sprite.animation.begins_with("idle"):
			animated_sprite.play("idle_" + last_direction_anim)
	else:
		var direction_str = ""
		if abs(move_velocity.x) > abs(move_velocity.y):
			if move_velocity.x > 0: direction_str = "east"
			else: direction_str = "west"
		else:
			if move_velocity.y > 0: direction_str = "south"
			else: direction_str = "north"

		if animated_sprite.animation != "run_" + direction_str:
			animated_sprite.play("run_" + direction_str)
		last_direction_anim = direction_str

#-----------------------------------------------------------------------------
# HÀM GỌI KHI MAP THAY ĐỔI (ví dụ bom nổ)
#-----------------------------------------------------------------------------
func on_map_changed() -> void:
	print("Map possibly changed. Updating AStar grid.")
	update_astar_grid()
	if current_state == MovementState.RANDOM_MOVE or current_state == MovementState.PATHFINDING:
		_try_find_path()

#-----------------------------------------------------------------------------
# HÀM XỬ LÝ KHI ENEMY CHẾT (Giữ nguyên)
#-----------------------------------------------------------------------------
func die():
	# ... (Giữ nguyên code die của bạn)
	print("Enemy died!")
	set_physics_process(false)
	queue_free()
	
