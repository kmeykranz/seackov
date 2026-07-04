extends Node

## 全局音乐管理器 —— autoload 单例，场景切换时不会被销毁，音乐无缝衔接。

const LOBBY_MUSIC_PATH := "res://assets/sound/music/lobby.mp3"

var _player: AudioStreamPlayer


func _ready() -> void:
	_player = AudioStreamPlayer.new()
	_player.bus = "Music" if AudioServer.get_bus_index("Music") != -1 else "Master"
	_player.finished.connect(_on_music_finished)
	add_child(_player)


## 播放 lobby 音乐（如果已在播放则不做任何事）
func play_lobby_music() -> void:
	if _player.stream != null and _player.playing:
		return
	_player.stream = load(LOBBY_MUSIC_PATH)
	_player.play()


## 停止音乐
func stop_music() -> void:
	_player.stop()


func _on_music_finished() -> void:
	_player.play()
