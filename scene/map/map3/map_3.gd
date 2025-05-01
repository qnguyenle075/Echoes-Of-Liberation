extends Node

@onready var wall_layer: TileMapLayer = $TileMap/wall
@onready var brick_layer: TileMapLayer = $TileMap/brick
@onready var enemy := $Enemy

var astar := AStarGrid2D.new()

func _ready():
	setup_astar_from_tilemap_layers(wall_layer, brick_layer)
	enemy.set_astar(astar)

	var target_pos: Vector2 = $player.global_position
	enemy.set_target(target_pos)

func setup_astar_from_tilemap_layers(wall_layer: TileMapLayer, brick_layer: TileMapLayer):
	var region := wall_layer.get_used_rect()
	var tile_size: Vector2i = wall_layer.tile_map.cell_quadrant_size


	astar.region = region
	astar.cell_size = tile_size
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
	astar.update()

	for y in range(region.position.y, region.end.y):
		for x in range(region.position.x, region.end.x):
			var cell := Vector2i(x, y)


			var is_wall := wall_layer.get_cell_source_id(cell) != -1
			var is_brick := brick_layer.get_cell_source_id(cell) != -1
			astar.set_point_solid(cell, is_wall or is_brick)

func _process(_delta):
	# Kiểm tra xem còn enemy nào trong nhóm "enemies" không
	var enemies = get_tree().get_nodes_in_group("enemies")
	if enemies.size() == 0:
		await get_tree().create_timer(3.0).timeout
		get_tree().change_scene_to_file("res://scene/gameovermenu/victory.tscn")
