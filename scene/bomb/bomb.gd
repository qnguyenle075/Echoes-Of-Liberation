extends StaticBody2D
signal bomb_exploded

@onready var collisionShape = $CollisionShape2D
@onready var WallTileMap = get_parent().get_node("kothepha")
@onready var Explosion = preload("res://scene/bomb/explosion.tscn")
@onready var BrickTileMap = get_parent().get_node("brick")
@onready var BrickExplosionScene = preload("res://scene/breakbrick.tscn")

func _ready():
	Music.play_sfx("res://assets/Sound/place_bomb.wav")
	add_to_group("bombs")
	collisionShape.disabled = true
	$thoigianvacham.start()
	$thoigianvacham.timeout.connect(_on_delay_collision_timeout)
	
	# Sau 5s sẽ gọi hàm explode
	$thoigianno.start()
	$thoigianno.timeout.connect(_on_timeout)
	
func _on_delay_collision_timeout():
	collisionShape.disabled = false

func _on_timeout():
	explode()

func explode():
	for enemy in get_tree().get_nodes_in_group("astar"):
		enemy.needs_update = true
	Music.play_sfx("res://assets/Sound/explosion-312361.mp3")
	spawn_explosions()
	emit_signal("bomb_exploded")
	queue_free()

func spawn_explosions():
	var tile_size = 16
	var center_pos = Vector2(
		int(global_position.x / tile_size) * tile_size + tile_size / 2,
		int(global_position.y / tile_size) * tile_size + tile_size / 2
	)
	
	var directions = {
		"center": Vector2(0, 0),
		"right": Vector2(1, 0),
		"left": Vector2(-1, 0),
		"up": Vector2(0, -1),
		"down": Vector2(0, 1)
	}
	
	for dir_name in directions.keys():
		var offset = directions[dir_name]
		var target_pos = center_pos + offset * tile_size
		var tile_coords = WallTileMap.local_to_map(target_pos)
		
		# Nếu đụng Wall => ngưng không nổ tiếp
		if WallTileMap.get_cell_tile_data(tile_coords) != null:
			continue
		
		# Nếu đụng Brick => phá Brick rồi dừng lan
		if BrickTileMap.get_cell_tile_data(tile_coords) != null:
			# Spawn hiệu ứng phá gạch
			var brick_explosion = BrickExplosionScene.instantiate()
			get_parent().add_child(brick_explosion)
			brick_explosion.global_position = target_pos

			# Xóa Brick
			BrickTileMap.set_cell(tile_coords, -1)
			
			# Spawn explosion tại chỗ Brick bị phá
			var explosion = Explosion.instantiate()
			get_parent().add_child(explosion)
			explosion.global_position = target_pos
			explosion.play_animation(dir_name)

			# Sau khi phá Brick thì ngưng nổ tiếp theo hướng đó
			continue

		# Nếu không gặp gì thì nổ bình thường
		var explosion = Explosion.instantiate()
		get_parent().add_child(explosion)
		explosion.global_position = target_pos
		explosion.play_animation(dir_name)
