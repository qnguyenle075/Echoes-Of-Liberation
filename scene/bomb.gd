extends StaticBody2D
signal bomb_exploded

@onready var collisionShape = $CollisionShape2D
@onready var WallTileMap = get_parent().get_node("TileMap")
@onready var Explosion = preload("res://scene/explosion.tscn")

func _ready():
	
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
	spawn_explosions()
	emit_signal("bomb_exploded")
	queue_free()

func spawn_explosions():
	var tile_size = 16
	var c = Vector2(
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

	for dir_name in directions:
		var offset = directions[dir_name]
		var target_pos = c + offset * tile_size

		var tile_coords = WallTileMap.local_to_map(target_pos)
		var tile_id = WallTileMap.get_cell_source_id(0, tile_coords)
		
		if tile_id != -1 and dir_name != "center":
			continue

		var explosion = Explosion.instantiate()
		get_parent().add_child(explosion)
		explosion.global_position = target_pos
		explosion.play_animation(dir_name)
