extends Node

## 全局音乐/音效管理器 —— autoload 单例，场景切换时不会被销毁。

const LOBBY_MUSIC_PATH := "res://assets/sound/music/lobby.mp3"
const BOAT_MUSIC_PATH := "res://assets/sound/music/boat.mp3"
const DIVE_ALARM_PATH := "res://assets/sound/effect/dive_alarm.mp3"
const UNDERWATER_PATH := "res://assets/sound/effect/underwater.mp3"


var _music_player: AudioStreamPlayer
var _sfx_player: AudioStreamPlayer

## 标记：是否是从船上下水进入 run_scene（用于决定是否已播放过 dive_alarm）
var diving_from_boat: bool = false


func _ready() -> void:
	_music_player = AudioStreamPlayer.new()
	_music_player.bus = "Music" if AudioServer.get_bus_index("Music") != -1 else "Master"
	_music_player.finished.connect(_on_music_finished)
	add_child(_music_player)

	_sfx_player = AudioStreamPlayer.new()
	_sfx_player.bus = "SFX" if AudioServer.get_bus_index("SFX") != -1 else "Master"
	add_child(_sfx_player)


## —— 音乐 ——

func play_lobby_music() -> void:
	var path := LOBBY_MUSIC_PATH
	if _music_player.stream != null and _music_player.stream.resource_path == path and _music_player.playing:
		return
	_music_player.stream = load(path)
	_music_player.play()


func play_boat_music() -> void:
	var path := BOAT_MUSIC_PATH
	if _music_player.stream != null and _music_player.stream.resource_path == path and _music_player.playing:
		return
	_music_player.stream = load(path)
	_music_player.play()


func stop_music() -> void:
	_music_player.stop()


func _on_music_finished() -> void:
	_music_player.play()


## —— 音效 ——

func play_dive_alarm() -> void:
	_sfx_player.stream = load(DIVE_ALARM_PATH)
	_sfx_player.play()


func play_underwater() -> void:
	_sfx_player.stream = load(UNDERWATER_PATH)
	_sfx_player.play()
