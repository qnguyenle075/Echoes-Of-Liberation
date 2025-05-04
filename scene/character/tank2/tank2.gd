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
	astar_grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER # No diagonal movement
	var map_rect = ground_layer.get_used_rect()
	if map_rect.has_area():
		# Important: Set region and offset *before* updating points
		astar_grid.region = map_rect
		# Offset needs to be the world position of the top-left corner of the map region
		astar_grid.offset = ground_layer.map_to_local(map_rect.position)
		print("AStar Initialized - Region:", astar_grid.region, "Offset:", astar_grid.offset, "CellSize:", astar_grid.cell_size)
		update_astar_grid() # Cập nhật lần đầu
	else:
		push_warning("Enemy: Ground Layer empty! A* grid starts empty.")
		astar_grid.region = Rect2i(); astar_grid.offset = Vector2.ZERO; astar_grid.update() # Still need update even if empty

	# --- Cài đặt Timer cập nhật đường đi ---
	path_update_timer.wait_time = 0.2 # Adjust as needed (slightly slower than before, less CPU)
	path_update_timer.one_shot = false
	path_update_timer.autostart = true
	path_update_timer.connect("timeout", _on_path_update_timer_timeout) # Simpler connect syntax
	add_child(path_update_timer)

	# --- Cài đặt Timer di chuyển ngẫu nhiên ---
	random_move_timer.wait_time = 1.5 # Slightly longer random moves
	random_move_timer.one_shot = false
	random_move_timer.autostart = true
	random_move_timer.connect("timeout", _on_random_move_timer_timeout) # Simpler connect syntax
	add_child(random_move_timer)
	_on_random_move_timer_timeout() # Initialize random direction

	current_state = MovementState.IDLE # Start idle

#-----------------------------------------------------------------------------
# HÀM XỬ LÝ VẬT LÝ
#-----------------------------------------------------------------------------
func _physics_process(delta: float) -> void:
	var move_direction = Vector2.ZERO

	match current_state:
		MovementState.PATHFINDING:
			move_direction = _follow_path(delta)
		MovementState.RANDOM_MOVE:
			move_direction = _move_randomly(delta)
		MovementState.IDLE:
			# Maybe try finding path if idle? Or stay idle until timer triggers.
			# For now, do nothing. Timer will eventually trigger a pathfind attempt.
			pass

	# Apply movement
	if move_direction != Vector2.ZERO:
		velocity = move_direction.normalized() * SPEED
	else:
		velocity = Vector2.ZERO # Stop if no direction

	move_and_slide()
	_update_animation(velocity) # Update animation based on final velocity

#-----------------------------------------------------------------------------
# HÀM CẬP NHẬT LƯỚI A*
#-----------------------------------------------------------------------------
func update_astar_grid() -> void:
	if not is_instance_valid(ground_layer) or tile_size == Vector2.ZERO:
		push_error("Cannot update A* grid: Ground layer invalid or tile size is zero.")
		return

	astar_grid.clear() # Clear existing points before rebuilding

	var current_map_rect: Rect2i = ground_layer.get_used_rect()
	if not current_map_rect.has_area():
		push_warning("A* Update: Ground Layer empty!")
		astar_grid.region = Rect2i(); astar_grid.offset = Vector2.ZERO; astar_grid.update()
		return

	# Ensure grid parameters match the current map state
	astar_grid.cell_size = tile_size
	astar_grid.region = current_map_rect
	astar_grid.offset = ground_layer.map_to_local(current_map_rect.position)

	# Iterate through all cells within the A* grid's region
	for x in range(astar_grid.region.position.x, astar_grid.region.end.x):
		for y in range(astar_grid.region.position.y, astar_grid.region.end.y):
			var map_coords = Vector2i(x, y)
			var is_solid = false

			# Check for obstacles:
			# 1. Is there a "kothepha" (unbreakable) tile?
			if is_instance_valid(kothepha_layer) and kothepha_layer.get_cell_source_id(map_coords) != -1:
				is_solid = true
			# 2. Is there a "brick" tile? (Only check if not already solid)
			elif is_instance_valid(brick_layer) and brick_layer.get_cell_source_id(map_coords) != -1:
				is_solid = true
			# 3. Is there NO "ground" tile? (Treat empty ground as solid/unwalkable)
			elif ground_layer.get_cell_source_id(map_coords) == -1:
				is_solid = true

			# Set solid state in A* grid
			if is_solid:
				astar_grid.set_point_solid(map_coords, true)
			# else: # Optional: explicitly set walkable, though default is walkable
			#   astar_grid.set_point_solid(map_coords, false)

	astar_grid.update() # IMPORTANT: Apply all the changes (solid points, region, offset)
	# print("AStar Grid Updated. Region:", astar_grid.region, "Offset:", astar_grid.offset)

#-----------------------------------------------------------------------------
# HÀM TÌM ĐƯỜNG ĐI
#-----------------------------------------------------------------------------
func _try_find_path() -> void:
	# --- Essential Node Checks ---
	if not is_instance_valid(player) or \
	   not is_instance_valid(ground_layer) or \
	   not is_instance_valid(map_parent) or \
	   tile_size == Vector2.ZERO:
		# print("Pathfinding aborted: Essential nodes or tile size missing.")
		current_state = MovementState.RANDOM_MOVE # Fallback
		current_path.clear()
		return

	# --- Convert Positions to Map Coordinates ---
	# Use map_parent to ensure positions are relative to the map layers' common parent
	var start_local_pos = map_parent.to_local(global_position)
	var start_map_pos: Vector2i = ground_layer.local_to_map(start_local_pos)

	var end_local_pos = map_parent.to_local(player.global_position)
	var end_map_pos: Vector2i = ground_layer.local_to_map(end_local_pos)

	# --- Validate Start/End Points ---
	# Check if points are within the A* grid bounds
	if not astar_grid.region.has_point(start_map_pos):
		# print("Path Error: Start point ", start_map_pos, " is outside A* region ", astar_grid.region)
		current_path.clear(); current_state = MovementState.RANDOM_MOVE; return
	if not astar_grid.region.has_point(end_map_pos):
		# print("Path Error: End point ", end_map_pos, " is outside A* region ", astar_grid.region)
		current_path.clear(); current_state = MovementState.RANDOM_MOVE; return # Can't path to outside

	# Check if points are inside solid obstacles
	if astar_grid.is_point_solid(start_map_pos):
		# This shouldn't happen if collision is set up correctly, but check anyway
		# print("Path Error: Start point ", start_map_pos, " is solid.")
		current_path.clear(); current_state = MovementState.RANDOM_MOVE; return
	if astar_grid.is_point_solid(end_map_pos):
		# Player might be temporarily inside a wall during destruction etc. - path fails
		# print("Path Error: End point ", end_map_pos, " is solid.")
		current_path.clear(); current_state = MovementState.RANDOM_MOVE; return

	# --- Calculate Path ---
	# get_id_path returns grid coordinates (Vector2i)
	var new_path: Array[Vector2i] = astar_grid.get_id_path(start_map_pos, end_map_pos)

	# --- Process Path Result ---
	if not new_path.is_empty():
		# The path includes the starting cell, remove it as we are already there.
		if new_path.size() > 0:
			new_path.pop_front()

		# Check if path still has points after removing the start
		if not new_path.is_empty():
			current_path = new_path
			_update_target_world_position() # Set the first waypoint target
			current_state = MovementState.PATHFINDING
			# print("Path found. Length: ", current_path.size(), " Next target:", target_world_position) # Debug
		else:
			# Path only contained the start point (already at destination or adjacent)
			# print("Path found, but already at/near destination.")
			current_path.clear()
			current_state = MovementState.IDLE # Or maybe RANDOM_MOVE? IDLE seems fine.
	else:
		# No path found (target unreachable)
		# print("No path found from ", start_map_pos, " to ", end_map_pos)
		current_path.clear()
		target_world_position = global_position # Clear target
		current_state = MovementState.RANDOM_MOVE # Fallback to random movement

	# Update last known player position regardless of success
	last_known_player_grid_pos = end_map_pos

#-----------------------------------------------------------------------------
# HÀM CẬP NHẬT VỊ TRÍ ĐÍCH THẾ GIỚI
#-----------------------------------------------------------------------------
func _update_target_world_position():
	if current_path.is_empty() or \
	   not is_instance_valid(ground_layer) or \
	   not is_instance_valid(map_parent) or \
	   tile_size == Vector2.ZERO:
		# print("Cannot update target world pos: Path empty or nodes invalid.")
		target_world_position = global_position # Default to current pos if error
		return

	# Get the next waypoint (map coordinates) from the path
	var target_map_pos: Vector2i = current_path[0]

	# Convert map coordinates to local position relative to the ground layer
	# Add half tile size to target the center of the tile
	var target_local_pos: Vector2 = ground_layer.map_to_local(target_map_pos) + tile_size / 2.0

	# Convert the local position (relative to ground_layer) to global world position
	target_world_position = map_parent.to_global(target_local_pos)
	# print("Updated target world position to:", target_world_position, " for map pos:", target_map_pos) # Debug

#-----------------------------------------------------------------------------
# HÀM DI CHUYỂN THEO ĐƯỜNG ĐI A* (REFINED)
#-----------------------------------------------------------------------------
func _follow_path(delta: float) -> Vector2:
	if current_path.is_empty():
		# print("Follow path called but path is empty.") # Debug
		current_state = MovementState.IDLE
		return Vector2.ZERO

	if target_world_position == Vector2.ZERO: # Should be set by _try_find_path or _update_target
		push_warning("Following path but target_world_position is ZERO. Attempting recovery.")
		_update_target_world_position()
		if target_world_position == Vector2.ZERO: # Still zero? Abort.
			current_path.clear(); current_state = MovementState.IDLE; return Vector2.ZERO

	# --- Calculate vector towards the current target waypoint ---
	var direction_to_target = target_world_position - global_position

	# --- Check if waypoint is reached ---
	# How far we will likely move this frame
	var move_distance_this_frame = SPEED * delta
	# How far we are from the target right now
	var current_distance_to_target_sq = global_position.distance_squared_to(target_world_position)

	# Waypoint reached if:
	# 1. We are very close (within a small threshold).
	# 2. OR We are about to move *past* the target this frame.
	# Use squared distances to avoid sqrt calculation.
	# Threshold: Use a fraction of the tile size (e.g., 20-25%) squared.
	var threshold = tile_size.x * 0.20
	var threshold_sq = threshold * threshold

	if current_distance_to_target_sq < threshold_sq or \
	   (current_distance_to_target_sq > 0 and current_distance_to_target_sq < move_distance_this_frame * move_distance_this_frame):

		# --- Waypoint Reached ---
		# print("Reached waypoint:", current_path[0]) # Debug

		# 1. OPTIONAL BUT RECOMMENDED: Snap to the exact target position
		# This prevents accumulating small errors over long paths.
		global_position = target_world_position

		# 2. Remove the reached waypoint from the path
		current_path.pop_front()

		# 3. Check if there are more waypoints
		if not current_path.is_empty():
			# Update target to the *next* waypoint in the list
			_update_target_world_position()
			# Recalculate direction for the new target immediately
			direction_to_target = target_world_position - global_position
			# print("Moving to next waypoint:", current_path[0]) # Debug
		else:
			# Path is now finished
			# print("Path finished. Attempting immediate re-path.") # Debug
			current_state = MovementState.IDLE # Temporarily idle while checking
			_try_find_path() # See if player moved, find new path immediately

			# If _try_find_path started a new path, recalculate direction
			if current_state == MovementState.PATHFINDING and not current_path.is_empty():
				direction_to_target = target_world_position - global_position
			else:
				# No new path found or state changed back to IDLE/RANDOM
				return Vector2.ZERO # Stop movement for this frame

	# --- Return movement direction ---
	# Only return a normalized direction if we actually need to move
	if direction_to_target.length_squared() > 0.001: # Check against small epsilon
		return direction_to_target.normalized()
	else:
		# Already very close or exactly at the target (e.g., after snapping)
		# Or calculated direction is zero for some reason.
		return Vector2.ZERO


#-----------------------------------------------------------------------------
# HÀM DI CHUYỂN NGẪU NHIÊN
#-----------------------------------------------------------------------------
func _move_randomly(delta: float) -> Vector2:
	# If no direction chosen, or timer forces a change, pick a new one
	if random_direction == Vector2.ZERO:
		_on_random_move_timer_timeout() # Ensure a direction is picked if possible
		# If still zero after trying, means stuck or map error
		if random_direction == Vector2.ZERO:
			return Vector2.ZERO

	# We return the direction vector; normalization happens in _physics_process
	return random_direction

func _on_random_move_timer_timeout() -> void:
	# Ensure required nodes are valid before attempting random move logic
	if not is_instance_valid(ground_layer) or \
	   not is_instance_valid(map_parent) or \
	   tile_size == Vector2.ZERO or \
	   astar_grid.region.size == Vector2i.ZERO: # Check if grid has valid region
		random_direction = Vector2.ZERO
		# print("Random Move: Cannot determine direction due to invalid nodes/grid.") # Debug
		return

	var possible_directions = []
	# Cardinal directions
	var directions = [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]

	# Current position in map coordinates
	var current_local_pos = map_parent.to_local(global_position)
	var current_map_pos = ground_layer.local_to_map(current_local_pos)

	# Check each direction
	for dir_vec in directions:
		# Rounding ensures we get integer offsets for map coords
		var next_map_pos = current_map_pos + Vector2i(roundi(dir_vec.x), roundi(dir_vec.y))

		# Check if the next position is within the grid bounds AND not solid
		if astar_grid.region.has_point(next_map_pos) and not astar_grid.is_point_solid(next_map_pos):
			possible_directions.append(dir_vec)

	# Choose a random direction from the valid ones
	if not possible_directions.is_empty():
		random_direction = possible_directions[randi() % possible_directions.size()]
		# print("Random Move: New direction:", random_direction) # Debug
	else:
		# Stuck! No valid moves from current position.
		random_direction = Vector2.ZERO
		# print("Random Move: Stuck! No valid directions.") # Debug

#-----------------------------------------------------------------------------
# HÀM CALLBACK CHO TIMER CẬP NHẬT ĐƯỜNG ĐI (KHÔNG UPDATE GRID)
#-----------------------------------------------------------------------------
func _on_path_update_timer_timeout() -> void:
	# --- Basic Node Checks ---
	if not is_instance_valid(player) or \
	   not is_instance_valid(ground_layer) or \
	   not is_instance_valid(map_parent):
		# print("Path Update Timer: Aborted due to invalid nodes.") # Debug
		return

	# --- Get Current Player Grid Position ---
	var current_player_local_pos = map_parent.to_local(player.global_position)
	var current_player_grid_pos = ground_layer.local_to_map(current_player_local_pos)

	# --- Decide Whether to Recalculate Path ---
	# Recalculate if:
	# 1. Player has moved to a new grid cell since the last check.
	# 2. The enemy is not currently following a path (maybe it finished, or got stuck).
	if current_player_grid_pos != last_known_player_grid_pos or \
	   current_state != MovementState.PATHFINDING:
		# print(f"Path Update Timer: Triggering path recalculation. Reason: Player moved ({current_player_grid_pos != last_known_player_grid_pos}) or State not Pathfinding ({current_state != MovementState.PATHFINDING})") # Debug
		# *** KHÔNG GỌI update_astar_grid() Ở ĐÂY ***
		# Grid updates only happen via on_map_changed()
		_try_find_path() # Calculate path using the *current* A* grid data
	# else: # Debug
	#    print(f"Path Update Timer: Skipping recalculation. Player pos {current_player_grid_pos} same as last {last_known_player_grid_pos} and state is {current_state}")

#-----------------------------------------------------------------------------
# HÀM CẬP NHẬT ANIMATION
#-----------------------------------------------------------------------------
func _update_animation(move_velocity: Vector2) -> void:
	if not is_instance_valid(animated_sprite): return

	# Use a small threshold to detect if moving or idle
	if move_velocity.length_squared() < 0.1:
		# If stopped, play idle animation facing the last movement direction
		if not animated_sprite.animation.begins_with("idle_"):
			animated_sprite.play("idle_" + last_direction_anim)
	else:
		# Determine dominant direction for animation
		var direction_str = ""
		# Check horizontal vs vertical dominance
		if abs(move_velocity.x) > abs(move_velocity.y):
			direction_str = "east" if move_velocity.x > 0 else "west"
		else: # Vertical dominance or equal
			direction_str = "south" if move_velocity.y > 0 else "north"

		# Play the corresponding run animation
		var target_anim = "run_" + direction_str
		if animated_sprite.animation != target_anim:
			animated_sprite.play(target_anim)

		# Store the last direction for idle state
		last_direction_anim = direction_str

#-----------------------------------------------------------------------------
# HÀM GỌI KHI MAP THAY ĐỔI (e.g., Brick destroyed)
#-----------------------------------------------------------------------------
func on_map_changed() -> void:
	print("Map possibly changed. Updating AStar grid and retrying path.")
	# VERY IMPORTANT: Update the grid *before* trying to find a path
	update_astar_grid()
	# Now try finding a path with the updated grid information
	_try_find_path()

#-----------------------------------------------------------------------------
# HÀM XỬ LÝ KHI ENEMY CHẾT
#-----------------------------------------------------------------------------
func _on_area_2d_body_entered(body): # Assuming you have an Area2D for detecting player collision
	if body.is_in_group("players"): # Make sure your player node is in the "players" group
		#print("Enemy collided with Player") # Debug
		if body.has_method("die"):
			body.die() # Make the player die

# (You might also want the enemy to die if hit by player's attack, e.g., explosion)

var is_dead := false

func die():
	if is_dead:
		return # Prevent dying multiple times
	is_dead = true
	#print("Enemy Died") # Debug

	# Stop all activity
	velocity = Vector2.ZERO
	set_physics_process(false) # Stop _physics_process
	path_update_timer.stop()   # Stop pathfinding attempts
	random_move_timer.stop()   # Stop random movement

	# Play death animation
	if animated_sprite.has_animation("die"):
		animated_sprite.play("die")
		await animated_sprite.animation_finished # Wait for animation to finish
	else:
		# Fallback if no die animation: wait a short time
		await get_tree().create_timer(0.5).timeout

	# Remove from scene
	queue_free()
