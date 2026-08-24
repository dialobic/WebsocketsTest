# scenes/audio/SoundPool.gd
extends Node2D

@onready var click_player: AudioStreamPlayer = $ClickPlayer
@onready var woosh_player: AudioStreamPlayer = $WooshPlayer
@onready var wrong_player: AudioStreamPlayer = $WrongPlayer
@onready var done_player: AudioStreamPlayer = $DonePlayer
@onready var ambient_player: AudioStreamPlayer = $AmbientPlayer

func _ready() -> void:
	# Configura ogni player con il suo suono
	setup_player(click_player, "click.ogg")
	setup_player(woosh_player, "woosh.ogg")
	setup_player(wrong_player, "wrong.ogg")
	setup_player(done_player, "done.ogg")
	setup_player(ambient_player, "ambient.ogg")

func setup_player(player: AudioStreamPlayer, sound_file: String) -> void:
	var path = "res://assets/sounds/%s" % sound_file
	if ResourceLoader.exists(path):
		player.stream = load(path)
		player.volume_db = 0.0
	else:
		print("Warning: Sound file not found: ", path)

func play_click() -> void:
	click_player.pitch_scale = randf_range(0.95, 1.05)
	click_player.play()

func play_woosh() -> void:
	woosh_player.pitch_scale = randf_range(0.95, 1.05)
	woosh_player.play()

func play_wrong() -> void:
	wrong_player.pitch_scale = randf_range(0.95, 1.05)
	wrong_player.play()

func play_done() -> void:
	done_player.pitch_scale = randf_range(0.95, 1.05)
	done_player.play()

func play_ambient() -> void:
	ambient_player.pitch_scale = 1.0
	ambient_player.play()

func stop_ambient() -> void:
	ambient_player.stop()
