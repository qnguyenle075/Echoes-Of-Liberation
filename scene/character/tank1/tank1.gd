extends CharacterBody2D

@export var speed := 30
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@export var wall_layer: TileMapLayer
@export var brick_layer: TileMapLayer



var direction := Vector2.ZERO
var change_dir_timer := 0.0
var tile_size := 16  # chỉnh nếu tile của bạn khác

var last_direction := Vector2.DOWN

func _ready():
	randomize()
	direction = choose_smart_direction()
	last_direction = Vector2.DOWN
	
var is_thinking := false

func _physics_process(delta):
	if is_thinking:
		return  # Đang suy nghĩ thì không làm gì

	change_dir_timer -= delta
	if change_dir_timer <= 0:
		is_thinking = true
		await get_tree().create_timer(0.5).timeout  # delay khi "suy nghĩ"
		
		var new_dir = choose_smart_direction()
		direction = new_dir if new_dir != Vector2.ZERO else Vector2.ZERO
		
		change_dir_timer = randf_range(2.0, 5.0)
		is_thinking = false

	velocity = direction * speed
	move_and_slide()
	update_animation()



func choose_smart_direction() -> Vector2:
	var current_tile = wall_layer.local_to_map(global_position)
	var dirs = [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]
	var valid_dirs = []

	for dir in dirs:
		var next_tile = current_tile + Vector2i(dir)
		if is_walkable(next_tile):
			valid_dirs.append(dir)

	if valid_dirs.size() > 0:
		return valid_dirs[randi() % valid_dirs.size()]

	# Không có đường trực tiếp → dùng BFS để tìm đường
	var path = bfs_find_path(current_tile)
	if path.size() >= 2:
		var next_step = path[1] - current_tile
		return Vector2(next_step).normalized()

	# Không có hướng nào đi được → đứng yên
	return Vector2.ZERO


func is_walkable(tile: Vector2i) -> bool:
	var is_wall = wall_layer.get_cell_source_id(tile) != -1
	var is_brick = brick_layer.get_cell_source_id(tile) != -1
	return not is_wall and not is_brick

# Tìm lối gần nhất có thể đi được
func bfs_find_path(start: Vector2i) -> Array:
	var visited = {}
	var queue = [start]
	var came_from = {}

	visited[start] = true

	while queue.size() > 0:
		var current = queue.pop_front()

		if current != start and is_walkable(current):
			# Nếu tìm được ô khác start mà đi được
			var path = [current]
			while came_from.has(current):
				current = came_from[current]
				path.insert(0, current)
			return path

		for dir in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var next = current + dir
			if visited.has(next):
				continue
			if not wall_layer.get_used_rect().has_point(next):
				continue
			visited[next] = true
			came_from[next] = current
			queue.append(next)

	return []


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
