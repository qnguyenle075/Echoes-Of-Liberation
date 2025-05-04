extends CharacterBody2D

const SPEED = 15.0
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

var direction: Vector2 = Vector2.ZERO
var is_moving := false
var move_target: Vector2 = Vector2.ZERO

# --- Biến trạng thái ---
enum MovementState { IDLE, PATHFINDING, RANDOM_MOVE }
var current_state: MovementState = MovementState.IDLE
var last_known_player_grid_pos: Vector2i = Vector2i.MAX
var path_update_timer: Timer = Timer.new()
var random_move_timer: Timer = Timer.new()
var random_direction: Vector2 = Vector2.ZERO

# --- Biến Animation ---
var last_direction: String = "south"

#-----------------------------------------------------------------------------
# HÀM KHỞI TẠO VÀ THIẾT LẬP
#-----------------------------------------------------------------------------
func _ready() -> void:
	# Kiểm tra các layer
	if not is_instance_valid(ground_layer):
		printerr("Ground layer node not found or invalid!")
		return
	if not is_instance_valid(brick_layer):
		printerr("Brick layer node not found or invalid!")
	if not is_instance_valid(kothepha_layer):
		printerr("Kothepha layer node not found or invalid!")

	# Thiết lập AStarGrid lần đầu
	astar_grid = AStarGrid2D.new()
	rebuild_astar_grid()

	print("Enemy ready.")


	
func _process(_delta):
	if player == null:
		printerr("⚠ Player is null.")
	if ground_layer.get_used_rect().size == Vector2i(0, 0):
		printerr("⚠ ground_layer has no tiles!")
	if not is_instance_valid(ground_layer):
		printerr("❌ ground_layer is invalid.")

	if needs_update:
		rebuild_astar_grid()
		needs_update = false
		
	if not is_moving:
		move()
	
func move():
	var start = ground_layer.local_to_map(global_position)
	var end = ground_layer.local_to_map(player.global_position)
	print("Start:", start, "End:", end)
	print("Is start in region?: ", astar_grid.region.has_point(start))
	print("Is end in region?: ", astar_grid.region.has_point(end))
	var path = astar_grid.get_id_path(start, end)
	print("Path: ", path)
	# Bỏ điểm đầu vì là vị trí hiện tại
	if path.size() > 1:
		path.pop_front()
	else:
		print("Enemy: can not find path")
		return

	# Chuyển từ tile -> global
	var next_tile = path[0]
	var target_pos = ground_layer.map_to_local(next_tile)
	direction = (target_pos - global_position).normalized()
	is_moving = true
	move_target = target_pos

	
	
func _physics_process(delta):
	if not is_moving:
		return

	var distance = move_target - global_position
	if distance.length() < 2.0:
		is_moving = false
		velocity = Vector2.ZERO
	else:
		velocity = direction * SPEED

	move_and_slide()
	update_animation(direction)

func update_animation(direction: Vector2) -> void:
	if direction == Vector2.ZERO:
		animated_sprite.animation = "idle_" + last_direction
	else:
		if abs(direction.x) > abs(direction.y):
			if direction.x > 0:
				animated_sprite.animation = "run_east"
				last_direction = "east"
			else:
				animated_sprite.animation = "run_west"
				last_direction = "west"
		else:
			if direction.y > 0:
				animated_sprite.animation = "run_south"
				last_direction = "south"
			else:
				animated_sprite.animation = "run_north"
				last_direction = "north"
	animated_sprite.play()
	
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
	
var needs_update := false

func rebuild_astar_grid():
	if not is_instance_valid(ground_layer):
		return

	astar_grid.clear()
	astar_grid.region = ground_layer.get_used_rect()
	astar_grid.cell_size = ground_layer.tile_set.tile_size
	astar_grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	astar_grid.update()

	var region_size = astar_grid.region.size
	var region_position = astar_grid.region.position

	for x in region_size.x:
		for y in region_size.y:
			var tile_position = Vector2i(x + region_position.x, y + region_position.y)

			var is_solid = false

			var ground_tile_data = ground_layer.get_cell_tile_data(tile_position)
			if ground_tile_data == null or not ground_tile_data.get_custom_data("walkable"):
				is_solid = true

			if not is_solid and is_instance_valid(brick_layer) and brick_layer.get_cell_source_id(tile_position) != -1:
				is_solid = true

			if not is_solid and is_instance_valid(kothepha_layer) and kothepha_layer.get_cell_source_id(tile_position) != -1:
				is_solid = true

			if is_solid:
				astar_grid.set_point_solid(tile_position)

	print("AStarGrid rebuilt.")
	print("Ground used rect: ", ground_layer.get_used_rect())
	print("AStar region: ", astar_grid.region)
