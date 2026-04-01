extends Control

signal video_finished

## 用于调试：设置为需要播放的视频资源路径（例如 res://resource/video/final2.ogv）
@export var video_path: String = "res://resource/video/final2.ogv"

@onready var _video_player: VideoStreamPlayer = $VideoPlayer

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	if video_path.is_empty():
		return

	var stream := load(video_path)
	if stream == null or not (stream is VideoStream):
		push_error("FinalVideoTest: 无法加载视频资源：%s" % video_path)
		return

	_video_player.stream = stream
	_video_player.play()
	_video_player.finished.connect(func() -> void:
		emit_signal("video_finished")
	)
