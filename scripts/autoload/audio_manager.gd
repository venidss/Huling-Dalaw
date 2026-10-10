extends Node
## Audio manager for DAET: ANG PAMANA.
##
## Owns the audio buses (Master, Music, Ambience, SFX, UI) and provides fire-and-forget
## playback helpers. Resources are preloaded on first access so later triggers are seamless.
##
## Bus layout is created in code so the project does not need an external .tres bus file —
## works even if the bus layout asset is missing on a fresh clone.

const SFX_DIR := "res://assets/audio/sfx/"
const MUSIC_DIR := "res://assets/audio/music/"
const AMBIENCE_DIR := "res://assets/audio/ambience/"

const BUS_MASTER := &"Master"
const BUS_MUSIC := &"Music"
const BUS_AMBIENCE := &"Ambience"
const BUS_SFX := &"SFX"
const BUS_UI := &"UI"

var _sfx_cache: Dictionary = {}
var _music_player: AudioStreamPlayer
var _ambience_player: AudioStreamPlayer
var _ambience_layer_player: AudioStreamPlayer  # second ambience layer (e.g. rain over insects)
var _active_sfx_players: Array[AudioStreamPlayer] = []

func _ready() -> void:
	_setup_buses()
	_music_player = AudioStreamPlayer.new()
	_music_player.bus = BUS_MUSIC
	add_child(_music_player)
	_ambience_player = AudioStreamPlayer.new()
	_ambience_player.bus = BUS_AMBIENCE
	add_child(_ambience_player)
	_ambience_layer_player = AudioStreamPlayer.new()
	_ambience_layer_player.bus = BUS_AMBIENCE
	add_child(_ambience_layer_player)
	Settings.settings_changed.connect(_apply_settings)
	_apply_settings()

func _setup_buses() -> void:
	# Ensure named buses exist. Master is index 0 and always present.
	var layout_names := [BUS_MUSIC, BUS_AMBIENCE, BUS_SFX, BUS_UI]
	for n in layout_names:
		if AudioServer.get_bus_index(n) == -1:
			var idx := AudioServer.bus_count
			AudioServer.add_bus(idx)
			AudioServer.set_bus_name(idx, n)
			AudioServer.set_bus_send(idx, BUS_MASTER)

func _apply_settings() -> void:
	_set_bus_volume(BUS_MASTER, Settings.master_volume)
	_set_bus_volume(BUS_MUSIC, Settings.music_volume)
	_set_bus_volume(BUS_AMBIENCE, Settings.ambience_volume)
	_set_bus_volume(BUS_SFX, Settings.sfx_volume)
	_set_bus_volume(BUS_UI, Settings.sfx_volume)

func _set_bus_volume(bus: StringName, linear: float) -> void:
	var idx := AudioServer.get_bus_index(bus)
	if idx == -1:
		return
	var db: float
	if linear <= 0.0001:
		db = -80.0
	else:
		db = linear_to_db(linear)
	AudioServer.set_bus_volume_db(idx, db)
	AudioServer.set_bus_mute(idx, linear <= 0.0001)

# --- music -------------------------------------------------------------------

func play_music(stream_name: String, fade_in: float = 1.0) -> void:
	var stream := _load_stream(MUSIC_DIR + stream_name)
	if stream == null:
		return
	_apply_loop(stream)
	if _music_player.stream == stream and _music_player.playing:
		return
	_music_player.stream = stream
	_fade_player(_music_player, fade_in)

func stop_music(fade_out: float = 0.5) -> void:
	_fade_out_player(_music_player, fade_out)

# --- ambience ----------------------------------------------------------------

func play_ambience(stream_name: String, layer: int = 0, fade_in: float = 1.0) -> void:
	var stream := _load_stream(AMBIENCE_DIR + stream_name)
	if stream == null:
		return
	_apply_loop(stream)
	var player := _ambience_player if layer == 0 else _ambience_layer_player
	if player.stream == stream and player.playing:
		return
	player.stream = stream
	_fade_player(player, fade_in)

func stop_ambience(layer: int = -1, fade_out: float = 0.5) -> void:
	if layer == 0 or layer == -1:
		_fade_out_player(_ambience_player, fade_out)
	if layer == 1 or layer == -1:
		_fade_out_player(_ambience_layer_player, fade_out)

## Start a player at silence and tween its bus volume up to 0 dB over `duration`.
func _fade_player(player: AudioStreamPlayer, duration: float) -> void:
	if player == null:
		return
	if duration <= 0.01:
		player.volume_db = 0.0
		player.play()
		return
	player.volume_db = -40.0
	player.play()
	var tween := create_tween()
	tween.tween_property(player, "volume_db", 0.0, duration)

func _fade_out_player(player: AudioStreamPlayer, duration: float) -> void:
	if player == null or not player.playing:
		return
	if duration <= 0.01:
		player.stop()
		return
	var tween := create_tween()
	tween.tween_property(player, "volume_db", -40.0, duration)
	tween.tween_callback(player.stop)

## Make a stream loop seamlessly. WAVs imported by Godot default to loop_mode=0 (no loop);
## we set it to forward loop here so ambience and music beds don't abruptly cut.
func _apply_loop(stream: AudioStream) -> void:
	if stream == null:
		return
	if stream is AudioStreamWAV:
		(stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
		(stream as AudioStreamWAV).loop_begin = 0
		# loop_end at 0 means to the end of the stream.
	elif stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true

# --- SFX --------------------------------------------------------------------

func play_sfx(stream_name: String, volume_db: float = 0.0, pitch_scale: float = 1.0) -> void:
	if stream_name == "":
		return
	var stream := _load_stream(SFX_DIR + stream_name)
	if stream == null:
		return
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.bus = BUS_SFX
	player.volume_db = volume_db
	player.pitch_scale = pitch_scale
	add_child(player)
	_active_sfx_players.append(player)
	player.finished.connect(func(): _cleanup_sfx(player))
	player.play()

func play_sfx_3d(stream_name: String, parent: Node3D, volume_db: float = 0.0, pitch_scale: float = 1.0) -> void:
	if stream_name == "" or parent == null or not is_instance_valid(parent):
		return
	var stream := _load_stream(SFX_DIR + stream_name)
	if stream == null:
		return
	var player := AudioStreamPlayer3D.new()
	player.stream = stream
	player.bus = BUS_SFX
	player.volume_db = volume_db
	player.pitch_scale = pitch_scale
	player.unit_size = 6.0
	player.max_distance = 25.0
	parent.add_child(player)
	player.finished.connect(_cleanup_3d_sfx.bind(player))
	player.play()

func _cleanup_3d_sfx(player: AudioStreamPlayer3D) -> void:
	if is_instance_valid(player):
		player.queue_free()

func _cleanup_sfx(player: AudioStreamPlayer) -> void:
	_active_sfx_players.erase(player)
	if is_instance_valid(player):
		player.queue_free()

func _load_stream(path: String) -> AudioStream:
	if _sfx_cache.has(path):
		return _sfx_cache[path]
	# Try common extensions.
	var candidates := [path, path + ".wav", path + ".ogg"]
	for c in candidates:
		if ResourceLoader.exists(c):
			var res := ResourceLoader.load(c)
			if res is AudioStream:
				_sfx_cache[path] = res
				return res
	push_warning("AudioManager: missing stream '%s'" % path)
	return null
