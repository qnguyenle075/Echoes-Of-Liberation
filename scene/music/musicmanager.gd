extends Node

@onready var btn_sfx := $HBoxContainer/sfx
@onready var btn_music := $HBoxContainer/music
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	btn_sfx.pressed.connect(_on_mute_sfx_button_pressed)
	btn_music.pressed.connect(_on_mute_music_button_pressed)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
func _on_mute_music_button_pressed():
	Music.toggle_music()

func _on_mute_sfx_button_pressed():
	Music.toggle_sfx()
