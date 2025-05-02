extends CharacterBody2D

@export var speed := 30
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@export var wall_layer: TileMapLayer
@export var brick_layer: TileMapLayer
@export var player_path: NodePath

var direction := Vector2.ZERO
var change_dir_timer := 0.0
var tile_size := 16
var last_direction := Vector2.DOWN
var is_thinking := false
var player: Node2D

func _ready():
	randomize()
	player = get_node(player_path)
	direction = choose_direction()
	update_animation()

func _physics_process(delta):
	if is_thinking:
		return

	change_dir_timer -= delta
	if change_dir_timer <= 0:
		is_thinking = true
		await get_tree().create_timer(0.5).timeout

		direction = choose_direction()
		change_dir_timer = 2
		is_thinking = false

	velocity = direction * speed
	move_and_slide()
	update_animation()

# ----- CHỌN HƯỚNG DI CHUYỂN CHÍNH ------
func choose_direction() -> Vector2:
	var bot_tile = wall_layer.local_to_map(global_position)
	var player_tile = wall_layer.local_to_map(player.global_position)

	if is_player_in_sight(bot_tile, player_tile):
		var delta = player_tile - bot_tile
		return Vector2(delta).normalized()
	else:
		var path = bfs_find_path(bot_tile, player_tile)
		if path.size() >= 2:
			var next_step = path[1] - bot_tile
			return Vector2(next_step).normalized()

	return choose_random_direction(bot_tile)

# ----- KIỂM TRA TẦM NHÌN -----
func is_player_in_sight(bot_tile: Vector2i, player_tile: Vector2i) -> bool:
	var delta = player_tile - bot_tile
	
	# Chỉ xét 4 hướng
	if delta.x == 0 and abs(delta.y) <= 2:
		var step = Vector2i(0, sign(delta.y))
		var pos = bot_tile + step
		while pos != player_tile:
			if not is_walkable(pos):
				return false
			pos += step
		return true
	elif delta.y == 0 and abs(delta.x) <= 2:
		var step = Vector2i(sign(delta.x), 0)
		var pos = bot_tile + step
		while pos != player_tile:
			if not is_walkable(pos):
				return false
			pos += step
		return true

	return false


# ----- BFS TÌM ĐƯỜNG -----
func bfs_find_path(start: Vector2i, goal: Vector2i) -> Array:
	var visited = {}
	var queue = [start]
	var came_from = {}

	visited[start] = true

	while queue.size() > 0:
		var current = queue.pop_front()

		if current == goal:
			var path = [current]
			while came_from.has(current):
				current = came_from[current]
				path.insert(0, current)
			return path

		for dir in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var next = current + dir
			if visited.has(next) or not wall_layer.get_used_rect().has_point(next):
				continue
			if not is_walkable(next):
				continue
			visited[next] = true
			came_from[next] = current
			queue.append(next)

	return []

# ----- KIỂM TRA Ô ĐI ĐƯỢC -----
func is_walkable(tile: Vector2i) -> bool:
	var is_wall = wall_layer.get_cell_source_id(tile) != -1
	var is_brick = brick_layer.get_cell_source_id(tile) != -1
	return not is_wall and not is_brick

# ----- RANDOM HƯỚNG -----
func choose_random_direction(current_tile: Vector2i) -> Vector2:
	var dirs = [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]
	var valid_dirs = []

	for dir in dirs:
		var next_tile = current_tile + Vector2i(dir)
		if is_walkable(next_tile):
			valid_dirs.append(dir)

	if valid_dirs.size() > 0:
		return valid_dirs[randi() % valid_dirs.size()]
	return Vector2.ZERO

# ----- ANIMATION -----
func update_animation():
	if direction == Vector2.ZERO:
		if abs(last_direction.x) > abs(last_direction.y):
			if last_direction.x > 0:
				animated_sprite.animation = "Idle_Right"
			else:
				animated_sprite.animation = "Idle_Left"
		else:
			if last_direction.y > 0:
				animated_sprite.animation = "Idle_Down"
			else:
				animated_sprite.animation = "Idle_Up"
	else:
		if abs(direction.x) > abs(direction.y):
			if direction.x > 0:
				animated_sprite.animation = "Run_Right"
				last_direction = Vector2.RIGHT
			else:
				animated_sprite.animation = "Run_Left"
				last_direction = Vector2.LEFT
		else:
			if direction.y > 0:
				animated_sprite.animation = "Run_Down"
				last_direction = Vector2.DOWN
			else:
				animated_sprite.animation = "Run_Up"
				last_direction = Vector2.UP



# ----- DIE -----
var is_dead := false

func die():
	if is_dead:
		return
	is_dead = true
	velocity = Vector2.ZERO
	set_physics_process(false)
	animated_sprite.play("die")
	await get_tree().create_timer(0.5).timeout
	queue_free()

func _on_area_2d_body_entered(body):
	if body.is_in_group("players"):
		if body.has_method("die"):
			body.die()
