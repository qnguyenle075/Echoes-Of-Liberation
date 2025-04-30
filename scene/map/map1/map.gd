extends Node

@onready var WallTileMap = $kothepha
@onready var BrickTileMap = $brick

const TILE_SIZE = 16

# Dùng RandomNumberGenerator riêng để random mạnh hơn
var rng = RandomNumberGenerator.new()

var WIDTH
var HEIGHT
var safe_spots = []

func _ready():
	rng.randomize() # Random lần đầu tiên khi vào game

	var used_rect = WallTileMap.get_used_rect()
	WIDTH = used_rect.size.x
	HEIGHT = used_rect.size.y

	setup_safe_spots()
	spawn_random_brick()

func setup_safe_spots():
	safe_spots.clear()

	# Lấy tất cả player trong group "players"
	var players = get_tree().get_nodes_in_group("players")

	for player in players:
		var player_tile = WallTileMap.local_to_map(player.global_position)

		# Chừa vùng an toàn 3x3 quanh player
		for dx in range(-1, 2): # từ -1 tới 1
			for dy in range(-1, 2):
				var offset = Vector2i(dx, dy)
				var spot = player_tile + offset
				if not safe_spots.has(spot):
					safe_spots.append(spot)

	# Chừa thêm 4 góc ngoài map
	var corners = [
		Vector2i(0, 0),
		Vector2i(WIDTH-1, 0),
		Vector2i(0, HEIGHT-1),
		Vector2i(WIDTH-1, HEIGHT-1)
	]

	for corner in corners:
		safe_spots.append(corner)
		safe_spots.append(corner + Vector2i(1, 0))
		safe_spots.append(corner + Vector2i(0, 1))
		safe_spots.append(corner + Vector2i(1, 1))


func spawn_random_brick():
	for y in range(HEIGHT):
		for x in range(WIDTH):
			var tile_pos = Vector2i(x, y)

			# Nếu vị trí này nằm trong vùng an toàn thì bỏ qua
			if tile_pos in safe_spots:
				continue

			# Spawn Brick ngẫu nhiên 85% tỉ lệ
			if rng.randf() < 0.4:
				BrickTileMap.set_cell(tile_pos, 0, Vector2i(7,7))
