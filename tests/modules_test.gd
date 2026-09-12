extends SceneTree
## godot --headless --path . --script res://tests/modules_test.gd
## These tests use an isolated profile; the player's profile is never modified.
## Physical keyboard rollover/gamepad behavior must also be tested on the cabinet.

const Inputs = preload("res://scripts/input_manager.gd")
const Profile = preload("res://scripts/save_manager.gd")
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
	var input = Inputs.new()
	check(input.get_binding(0, "attack") == KEY_F, "Player one physical defaults")
	check(input.get_binding(1, "block") == KEY_L, "Player two physical defaults")
	check(input.set_binding(0, "attack", KEY_G), "Accept valid remap")
	check(input.get_binding(0, "power") == KEY_F, "Same-player conflicts swap keys")
	check(not input.set_binding(2, "attack", KEY_G), "Reject invalid player")
	check(not input.set_binding(0, "unknown", KEY_G), "Reject invalid action")
	check(not input.set_binding(0, "attack", KEY_NONE), "Reject empty physical key")
	check(not input.set_binding(0, "attack", KEY_ENTER) and not input.set_binding(0, "attack", KEY_F11), "System hotkeys cannot become broken combat bindings")
	var serialized: Dictionary = input.export_bindings()
	input.defaults()
	check(input.get_binding(0, "attack") == KEY_F, "Defaults restore controls")
	input.load_bindings(serialized)
	check(input.get_binding(0, "attack") == KEY_G, "Binding roundtrip")
	serialized["0"]["attack"] = KEY_T
	check(input.get_binding(0, "attack") == KEY_G, "Loading does not alias saved dictionaries")
	input.load_bindings({"0": {"attack": "invalid"}})
	check(input.get_binding(0, "attack") == KEY_F, "Malformed bindings use defaults")
	input.set_binding(1, "attack", KEY_F)
	check(input.get_binding(0, "attack") == KEY_J and input.get_binding(1, "attack") == KEY_F, "Cross-player keyboard conflicts swap instead of duplicate")
	check(input.get_gamepad_binding(0, "attack") == JOY_BUTTON_A, "Gamepad defaults")
	check(input.set_gamepad_binding(0, "attack", JOY_BUTTON_B), "Gamepad remapping")
	check(input.get_gamepad_binding(0, "power") == JOY_BUTTON_A, "Gamepad button conflicts swap")
	check(input.set_gamepad_device(1, 0), "Gamepad assignment")
	check(input.get_gamepad_config(0)["device"] == 1 and input.get_gamepad_config(1)["device"] == 0, "Gamepad device ownership remains distinct")
	check(input.set_gamepad_axis(0, "horizontal", JOY_AXIS_RIGHT_X, true), "Remappable analog axis and inversion")
	check(input.set_gamepad_deadzone(0, 0.45), "Custom gamepad deadzone")
	var pad_saved: Dictionary = input.export_bindings()
	input.defaults()
	input.load_bindings(pad_saved)
	check(input.get_gamepad_binding(0, "attack") == JOY_BUTTON_B, "Persisted gamepad button mapping")
	check(input.get_gamepad_config(0)["horizontal"] == JOY_AXIS_RIGHT_X and input.get_gamepad_config(0)["invert_horizontal"], "Persisted analog axis configuration")
	check(is_equal_approx(input.get_gamepad_config(0)["deadzone"], 0.45), "Persisted analog deadzone")
	check(not input.set_gamepad_binding(0, "attack", -1) and not input.set_gamepad_device(0, -1), "Reject invalid gamepad values")
	check(not input.set_gamepad_binding(0, "attack", JOY_BUTTON_START) and not input.set_gamepad_binding(0, "attack", JOY_BUTTON_BACK), "Reserve gamepad system navigation buttons")
	check(not input.set_gamepad_axis(0, "diagonal", JOY_AXIS_LEFT_X), "Reject unsupported axis labels")
	check(not input.set_gamepad_deadzone(0, NAN), "Reject nonfinite deadzone")
	input.update()
	for player: int in range(2):
		var snapshot: Dictionary = input.sample(player)
		for action: String in Inputs.ACTIONS:
			check(snapshot.has(action) and snapshot.has(action + "_pressed") and snapshot.has(action + "_released"), "Snapshot schema: %d/%s" % [player, action])
		var original: bool = bool(snapshot["attack"])
		snapshot["attack"] = not original
		check(bool(input.sample(player)["attack"]) == original, "Snapshot isolation")
	check(input.sample(-1).is_empty(), "Invalid sample is empty")

	var profile_path: String = "user://module_test_profile_%d.json" % OS.get_process_id()
	var profile = Profile.new(profile_path)
	profile.data["stats"]["matches"] = 42
	profile.data["settings"]["music"] = 2.0
	profile.data["settings"]["difficulty"] = 3
	profile.data["bindings"] = serialized
	check(profile.save_profile(), "Write temporary and commit: " + profile.last_error)
	var restored = Profile.new(profile_path)
	restored.load_profile()
	check(restored.data["stats"]["matches"] == 42, "Persistence roundtrip")
	check(restored.data["settings"]["music"] == 1.0, "Clamp volume")
	check(restored.data["settings"]["difficulty"] == 3, "Preserve MASTER difficulty")
	check(restored.data["bindings"]["0"]["attack"] == KEY_T, "Persist binding codes")
	restored.data["stats"]["matches"] = 43
	check(restored.save_profile(), "Atomic replacement of an existing profile")
	check(FileAccess.file_exists(profile_path + ".bak"), "Backup created")
	var corrupt: FileAccess = FileAccess.open(profile_path, FileAccess.WRITE)
	corrupt.store_string("invalid JSON")
	corrupt.close()
	restored.load_profile()
	check(restored.data["stats"]["matches"] == 42, "Recover last valid backup")
	for extension: String in ["", ".tmp", ".bak"]:
		if FileAccess.file_exists(profile_path + extension):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(profile_path + extension))

	var sound = Sound.new()
	root.add_child(sound)
	sound.set_levels(0.0, 0.5)
	check(sound.get_child_count() == 21, "Pooled sound players: 18 effects, 2 score, 1 announcer")
	var music_bus: int = AudioServer.get_bus_index("NexusMusic")
	var sfx_bus: int = AudioServer.get_bus_index("NexusSFX")
	check(music_bus >= 0 and sfx_bus >= 0, "Independent audio buses")
	check(AudioServer.is_bus_mute(music_bus), "Music zero mutes only music")
	check(not AudioServer.is_bus_mute(sfx_bus), "SFX remains active")
	sound.free()
	print("Support modules: %d checks, %d failures." % [checks, failures])
	quit(1 if failures else 0)
