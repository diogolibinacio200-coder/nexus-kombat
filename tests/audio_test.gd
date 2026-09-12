extends SceneTree
## Loads real imported WAV assets, exercises rapid crossfades and exits mid-loop.
const Sound = preload("res://scripts/audio_manager.gd")
var failures: int = 0
var checks: int = 0

func _initialize() -> void:
	call_deferred("run_checks")

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + label)

func run_checks() -> void:
	var sound = Sound.new()
	root.add_child(sound)
	for context: String in ["menu", "selection", "vs", "victory"]:
		sound.music(context)
		var player: AudioStreamPlayer = sound._music_players[sound._active_music]
		check(player.playing and player.stream != null, "Music asset starts: " + context)
		if player.stream is AudioStreamWAV:
			check(player.stream.loop_mode == AudioStreamWAV.LOOP_FORWARD and player.stream.loop_end > 0, "Valid loop region: " + context)
	for stage: int in range(10):
		sound.music("arena", stage)
		var player: AudioStreamPlayer = sound._music_players[sound._active_music]
		check(player.playing and player.stream != null and player.stream.get_length() > 10.0, "Arena score: %d" % stage)
	for event: String in ["hit", "hit_heavy", "block", "parry", "guard_break", "footstep", "jump", "whoosh", "projectile", "super", "ko_impact", "select", "confirm", "cancel", "victory", "ready", "counter_hit"]:
		sound.play(event)
		check(sound._cache.has(event), "Effect loads: " + event)
	for event: String in Sound.ANNOUNCER:
		check(sound._stream("voice_" + event) != null, "Announcer asset: " + event)
	sound.play("ko")
	sound.play("perfect")
	check(sound._voice_queue.has("perfect"), "Follow-up narration queues behind KO")
	sound.set_levels(0.0, 0.0)
	sound.music("menu")
	await create_timer(0.05).timeout
	await sound.shutdown()
	print("Audio assets: %d checks, %d failures. Shutdown retired active audio playbacks." % [checks, failures])
	quit(1 if failures else 0)
