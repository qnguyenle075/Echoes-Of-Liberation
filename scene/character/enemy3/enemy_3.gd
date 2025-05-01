extends CharacterBody2D

@onready var nav_agent = $NavigationAgent2D
@onready var animated_sprite = $AnimatedSprite2D
@export var ground_layer: TileMapLayer
@export var brick_layer: TileMapLayer
@export var kothepha_layer: TileMapLayer

@export var speed: float = 100.0
@export var grid_size: int = 16
@export var bomb_explosion_range: int = 2

var target_pos: Vector2
var dangerous_cells: Array[Vector2i] = []
var last_direction: Vector2 = Vector2.DOWN

func _ready():
	if not ground_layer:
		print("Error: ground_layer is not assigned in Inspector!")
		return
	if not brick_layer:
		print("Error: brick_layer is not assigned in Inspector!")
		return
	if not kothepha_layer:
		print("Error: kothepha_layer is not assigned in Inspector!")
		return
	
	if not animated_sprite:
		print("Error: AnimatedSprite node not found or not assigned!")
		return
	
	# Kiểm tra số ô an toàn
	var map_size = ground_layer.get_used_rect()
	var safe_cells = []
	for x in range(map_size.size.x):
		for y in range(map_size.size.y):
			var cell = Vector2i(x, y)
			if is_cell_safe(cell):
				safe_cells.append(cell)
	print("Total safe cells:", safe_cells)
	
	snap_to_grid()
	update_dangerous_cells()
	choose_new_destination()
	
	animated_sprite.play("Idle_Down")

func _physics_process(delta):
	update_dangerous_cells()
	
	if nav_agent.is_navigation_finished() or nav_agent.get_next_path_position() == position:
		print("Bot reached destination or no path, choosing new destination")
		choose_new_destination()
	
	var next_pos = nav_agent.get_next_path_position()
	var direction = (next_pos - position).normalized()
	velocity = direction * speed
	
	update_animation(direction)
	
	move_and_slide()
	snap_to_grid()

func snap_to_grid():
	var grid_pos = ground_layer.local_to_map(position)
	position = ground_layer.map_to_local(grid_pos)
	print("Bot position snapped to:", position)

func update_dangerous_cells():
	dangerous_cells.clear()
	var bombs = get_tree().get_nodes_in_group("bombs")
	
	for bomb in bombs:
		var bomb_grid_pos = ground_layer.local_to_map(bomb.position)
		dangerous_cells.append(bomb_grid_pos)
		
		for direction in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			for i in range(1, bomb_explosion_range + 1):
				var explosion_cell = bomb_grid_pos + direction * i
				if is_wall_or_brick(explosion_cell):
					break
				dangerous_cells.append(explosion_cell)
	print("Dangerous cells:", dangerous_cells)

func is_wall_or_brick(cell: Vector2i) -> bool:
	var kothepha_cell_id = kothepha_layer.get_cell_source_id(cell)
	var brick_cell_id = brick_layer.get_cell_source_id(cell)
	var is_obstacle = kothepha_cell_id != -1 or brick_cell_id != -1
	if is_obstacle:
		print("Cell", cell, "is obstacle (kothepha:", kothepha_cell_id, ", brick:", brick_cell_id, ")")
	return is_obstacle

func is_cell_safe(cell: Vector2i) -> bool:
	var safe = not dangerous_cells.has(cell) and not is_wall_or_brick(cell)
	print("Cell", cell, "safe:", safe)
	return safe

func choose_new_destination():
	var map_size = ground_layer.get_used_rect()
	var current_grid_pos = ground_layer.local_to_map(position)
	
	print("Map size:", map_size.size)
	
	for _i in range(10):
		var random_x = randi() % int(map_size.size.x)
		var random_y = randi() % int(map_size.size.y)
		var target_cell = Vector2i(random_x, random_y)
		
		if is_cell_safe(target_cell):
			target_pos = ground_layer.map_to_local(target_cell)
			nav_agent.set_target_position(target_pos)
			var path = nav_agent.get_current_navigation_path()
			print("Path to target:", path)
			if path.size() > 0:
				print("New destination set:", target_pos)
				return
			else:
				print("No valid path to:", target_pos)
	
	nav_agent.set_target_position(position)
	print("No safe destination found, staying at:", position)

func update_animation(direction: Vector2):
	if not animated_sprite:
		print("Error: AnimatedSprite is null!")
		return
	
	if direction.length() < 0.1:
		if last_direction.x < 0:
			animated_sprite.play("Idle_Left")
		elif last_direction.x > 0:
			animated_sprite.play("Idle_Right")
		elif last_direction.y < 0:
			animated_sprite.play("Idle_Up")
		else:
			animated_sprite.play("Idle_Down")
	else:
		last_direction = direction
		if abs(direction.x) > abs(direction.y):
			if direction.x < 0:
				animated_sprite.play("Run_Left")
			else:
				animated_sprite.play("Run_Right")
		else:
			if direction.y < 0:
				animated_sprite.play("Run_Up")
			else:
				animated_sprite.play("Run_Down")
				
				
var is_dead:= false
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
