extends Node

@onready var music_player := AudioStreamPlayer.new()
@onready var sfx_player := AudioStreamPlayer.new()
@onready var transition_sfx_player := AudioStreamPlayer.new()

var current_track: String = ""
var music_muted := false
var sfx_muted := false

func _ready():
	add_child(sfx_player)
	add_child(music_player)
	music_player.volume_db = -20
	sfx_player.volume_db = -20
	add_child(transition_sfx_player)
	transition_sfx_player.volume_db = -10


func play_music(path: String):
	if current_track == path and music_player.playing:
		return  # Đang phát đúng bài thì bỏ qua

	current_track = path

	var stream = load(path)
	if stream is AudioStream:
		if stream.has_method("set_loop"):  # Kiểm tra có thể loop không
			stream.set_loop(true)  # ✅ Chỉ gán loop cho AudioStream
		music_player.stream = stream
		music_player.play()

func stop_music():
	music_player.stop()
	current_track = ""
	
func play_sfx(path: String):
	if sfx_muted:
		return
	var sfx = load(path)
	if sfx is AudioStream:
		sfx_player.stream = sfx
		sfx_player.play()

func toggle_music():
	music_muted = !music_muted
	music_player.volume_db = -80 if music_muted else -40
	if music_muted:
		music_player.stop()
	else:
		if current_track != "":
			play_music(current_track)

func toggle_sfx():
	sfx_muted = !sfx_muted
	sfx_player.volume_db = -80 if sfx_muted else -30
	
func play_sfx_and_wait(path: String) -> void:
	if sfx_muted:
		return
	var stream = load(path)
	if stream is AudioStream:
		transition_sfx_player.stream = stream
		transition_sfx_player.play()
		await transition_sfx_player.finished
