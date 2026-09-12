extends Node
## Original project score and effects, centrally pooled and crossfaded.
## Announcer recordings use the locally installed Microsoft Zira synthetic voice.

const ROOT: String = "res://assets/audio/"
const VOICES: int = 18
const ALIASES: Dictionary = {
	"impact": "hit", "light": "hit", "heavy": "hit_heavy", "attack": "whoosh",
	"perfect_block": "parry", "guardbreak": "guard_break", "guard_break": "guard_break",
	"power": "projectile", "special": "projectile", "step": "footstep",
	"select": "select", "confirm": "confirm", "cancel": "cancel", "navigate": "select",
	"round_1": "round_one", "round_2": "round_two", "round_3": "final_round",
	"round1": "round_one", "round2": "round_two", "round3": "final_round",
	"player1_wins": "player_one_wins", "player2_wins": "player_two_wins",
	"clash": "parry", "dash": "whoosh", "land": "footstep", "throw": "hit_heavy",
	"move": "footstep", "super_ready": "ready", "super_hit": "ko_impact",
	"phase": "super", "no_meter": "cancel", "teleport": "projectile",
	"buff": "ready", "throw_start": "whoosh", "throw_break": "parry"
}
const ANNOUNCER: Array[String] = ["round_one", "round_two", "final_round", "fight", "ko", "perfect", "counter", "guard_break_voice", "final_hit", "player_one_wins", "player_two_wins"]
var _effects: Array[AudioStreamPlayer] = []
var _music_players: Array[AudioStreamPlayer] = []
var _announcer: AudioStreamPlayer
var _cache: Dictionary = {}
var _cursor: int = 0
var _active_music: int = 0
var _track: String = ""
var _fade: Tween
var _music_level: float = 0.5
var _sfx_level: float = 0.7
var _initialized: bool = false
var _last_effect: Dictionary = {}
var _voice_queue: Array[String] = []
var _spoken_key: String = ""
var _owned_buses: Array[String] = []
var _shutting_down: bool = false

func _ready() -> void:
	_initialize()

func _initialize() -> void:
	if _initialized:
		return
	_initialized = true
	for bus_name: String in ["NexusMusic", "NexusSFX", "NexusVoice"]:
		if AudioServer.get_bus_index(bus_name) < 0:
			AudioServer.add_bus()
			var bus_index: int = AudioServer.bus_count - 1
			AudioServer.set_bus_name(bus_index, bus_name)
			AudioServer.set_bus_send(bus_index, "Master")
			_owned_buses.append(bus_name)
	for index: int in range(VOICES):
		var voice: AudioStreamPlayer = AudioStreamPlayer.new()
		voice.bus = "NexusSFX"
		add_child(voice)
		_effects.append(voice)
	for index: int in range(2):
		var player: AudioStreamPlayer = AudioStreamPlayer.new()
		player.bus = "NexusMusic"
		add_child(player)
		_music_players.append(player)
	_announcer = AudioStreamPlayer.new()
	_announcer.bus = "NexusVoice"
	add_child(_announcer)
	_announcer.finished.connect(_voice_finished)
	set_levels(_music_level, _sfx_level)

func set_levels(music_volume: float, sfx_volume: float) -> void:
	_music_level = clampf(music_volume, 0.0, 1.0)
	_sfx_level = clampf(sfx_volume, 0.0, 1.0)
	if not _initialized:
		return
	_set_bus_level("NexusMusic", _music_level)
	_set_bus_level("NexusSFX", _sfx_level)
	_set_bus_level("NexusVoice", _sfx_level)

func _set_bus_level(bus_name: String, level: float) -> void:
	var index: int = AudioServer.get_bus_index(bus_name)
	AudioServer.set_bus_mute(index, level <= 0.0001)
	AudioServer.set_bus_volume_db(index, linear_to_db(maxf(level, 0.0001)))

func play(event: String, character: int = 0) -> void:
	if _shutting_down:
		return
	_initialize()
	var key: String = str(ALIASES.get(event.to_lower(), event.to_lower()))
	if ANNOUNCER.has(key):
		_queue_voice(key)
		if key == "ko":
			play("ko_impact", character)
		return
	# Walking emits every simulation tick; footsteps keep a natural audible cadence.
	if key in ["footstep", "cancel"]:
		var throttle_key: String = key + "_" + str(character)
		var now: int = Time.get_ticks_msec()
		var interval: int = 210 if key == "footstep" else 350
		if now - int(_last_effect.get(throttle_key, -1000)) < interval:
			return
		_last_effect[throttle_key] = now
	var stream: AudioStream = _stream(key)
	if stream == null:
		return
	var player: AudioStreamPlayer = _effects[_cursor % VOICES]
	for candidate: AudioStreamPlayer in _effects:
		if not candidate.playing:
			player = candidate
			break
	_cursor += 1
	player.stop()
	player.stream = stream
	player.pitch_scale = 1.0 + (float(posmod(character, 7)) - 3.0) * 0.015 if key in ["hit", "hit_heavy", "projectile", "whoosh"] else 1.0
	player.volume_db = -3.0 if key == "footstep" else 0.0
	player.play()
	if key == "guard_break":
		play("guard_break_voice", character)

func _queue_voice(key: String) -> void:
	if key == _spoken_key and _announcer.playing or _voice_queue.has(key):
		return
	if _announcer.playing:
		if key in ["round_one", "round_two", "final_round", "fight", "ko", "player_one_wins", "player_two_wins"]:
			_announcer.stop()
			_voice_queue.clear()
		else:
			if _voice_queue.size() < 2:
				_voice_queue.append(key)
			return
	_start_voice(key)

func _start_voice(key: String) -> void:
	var spoken: AudioStream = _stream("voice_" + key)
	if spoken == null:
		return
	_spoken_key = key
	_announcer.stream = spoken
	_announcer.volume_db = -1.0
	_announcer.play()

func _voice_finished() -> void:
	_spoken_key = ""
	if not _voice_queue.is_empty():
		_start_voice(_voice_queue.pop_front())

func music(context: String, stage_id: int = 0) -> void:
	if _shutting_down:
		return
	_initialize()
	var key: String = "music_menu"
	match context.to_lower():
		"selection", "select", "character_select": key = "music_selection"
		"vs", "versus": key = "music_vs"
		"victory", "ending", "result": key = "music_victory"
		"fight", "battle", "arena", "stage": key = "music_arena_%02d" % posmod(stage_id, 10)
		"off", "stop", "none": key = ""
	if key == _track:
		return
	_track = key
	if _fade != null and _fade.is_valid():
		_fade.kill()
	var previous: AudioStreamPlayer = _music_players[_active_music]
	_active_music = 1 - _active_music
	var next: AudioStreamPlayer = _music_players[_active_music]
	next.stop()
	_fade = create_tween().set_parallel(true)
	_fade.tween_property(previous, "volume_db", -55.0, 0.65)
	if key.is_empty():
		_fade.chain().tween_callback(previous.stop)
		return
	var stream: AudioStream = _stream(key)
	if stream == null:
		_fade.chain().tween_callback(previous.stop)
		return
	if stream is AudioStreamWAV:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = int(stream.get_length() * float(stream.mix_rate))
	next.stream = stream
	next.volume_db = -55.0
	next.play()
	_fade.tween_property(next, "volume_db", -3.5, 0.75)
	_fade.chain().tween_callback(previous.stop)

func _stream(key: String) -> AudioStream:
	if _cache.has(key):
		return _cache[key] as AudioStream
	var path: String = ROOT + key + ".wav"
	if not ResourceLoader.exists(path):
		return null
	var result: AudioStream = load(path) as AudioStream
	_cache[key] = result
	return result

func _stop_playbacks() -> void:
	if _fade != null and _fade.is_valid():
		_fade.kill()
	_fade = null
	_voice_queue.clear()
	for child: Node in get_children():
		if child is AudioStreamPlayer:
			child.stop()
			child.stream = null
	_cache.clear()

func shutdown() -> void:
	# AudioServer retires stopped playback references on subsequent mixer updates.
	# The application should await this method before SceneTree.quit().
	_shutting_down = true
	_stop_playbacks()
	if is_inside_tree():
		await get_tree().process_frame
		var drain_time: float = maxf(0.6, AudioServer.get_output_latency() + 0.15)
		await get_tree().create_timer(drain_time).timeout
		await get_tree().process_frame

func _exit_tree() -> void:
	_stop_playbacks()
	_effects.clear()
	_music_players.clear()
	_announcer = null
	for bus_name: String in _owned_buses:
		var index: int = AudioServer.get_bus_index(bus_name)
		if index > 0:
			AudioServer.remove_bus(index)
	_owned_buses.clear()
	_initialized = false
