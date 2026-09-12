extends SceneTree
## Exercises the real coordinator and combat, injecting controller command
## dictionaries only at the documented menu boundary. No visual mocks.
const Main = preload("res://scripts/main.gd")
const Profile = preload("res://scripts/save_manager.gd")
var app
var checks := 0
var failures: Array = []
const PROFILE_PATH := "user://flow-test-isolated.json"

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
		printerr("FAIL: "+label)

func commands(a: Dictionary = {}, b: Dictionary = {}) -> Array:
	return [a.duplicate(),b.duplicate()]

func confirm_both() -> Array:
	return commands({"attack":true,"attack_pressed":true},{"attack":true,"attack_pressed":true})

func confirm_one(player: int = 0) -> Array:
	var p := commands()
	p[player] = {"attack":true,"attack_pressed":true}
	return p

func clear_flags() -> void:
	app.escape_pressed = false
	app.enter_pressed = false
	app.tab_pressed = false
	app.reset_pressed = false
	app.any_pressed = false

func finish_intro() -> void:
	var guard := 0
	while app.intro_frames > 0 and guard < 210:
		app.tick_fight(commands(),false)
		guard += 1
	check(app.intro_frames == 0,"Round introduction reaches live combat")

func finish_round(victor: int) -> void:
	finish_intro()
	app.combat.winner = victor
	app.tick_fight(commands(),false)
	check(app.round_end_timer == 155,"KO transition starts celebration delay")
	for frame in 155: app.tick_fight(commands(),false)

func start_from_stage() -> void:
	app.tick_stage(confirm_one())
	check(app.screen == "vs","Stage confirmation opens VS screen")
	app.screen_time = 4.0
	app._physics_process(1.0/60.0)
	check(app.screen == "fight" and app.combat.fighters.size() == 2,"VS countdown creates actual Combat")

func result_confirm(index: int = 0) -> void:
	app.screen_time = 1.0
	app.result_index = index
	app.tick_result(confirm_one())

func perfect_block_event(defender: int) -> void:
	app.reset_training()
	app.combat.fighters[0].x = 550
	app.combat.fighters[1].x = 645
	app.combat.tick(confirm_one(1-defender))
	for frame in 3: app.combat.tick(commands())
	var defense := commands()
	defense[defender] = {"block":true,"block_pressed":true}
	app.combat.tick(defense)
	defense[defender] = {"block":true}
	for frame in 4:
		app.combat.tick(defense)
		app.consume_combat_events()

func run() -> void:
	for suffix in ["",".tmp",".bak"]:
		if FileAccess.file_exists(PROFILE_PATH+suffix):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(PROFILE_PATH+suffix))
	app = Main.new()
	app.profile = Profile.new(PROFILE_PATH)
	root.add_child(app)
	app.set_process(false)
	app.set_physics_process(false)
	app.sound.set_levels(0.0,0.0)
	app.profile.data.settings.fullscreen = false
	check(app.screen == "boot","Game begins at boot")
	app.any_pressed = true
	app._physics_process(1.0/60.0)
	check(app.screen == "menu","Any cabinet input exits boot")
	app.menu_index = 1
	app.tick_menu(confirm_one(1))
	check(app.screen == "select" and app.mode == "versus","P2 can choose Versus in menu")
	app.cursors = [0,3]
	app.tick_select(confirm_both())
	check(app.chosen == [0,3] and app.ready_players == [true,true] and app.screen == "stage","Simultaneous selection confirms both players exactly once")
	app.stage_cursor = 10
	start_from_stage()
	check(app.stage >= 0 and app.stage < 10,"Random stage resolves to an actual arena")
	check(app.wins == [0,0] and app.round_number == 1,"New match resets round scores")
	var idle_hp: float = app.combat.fighters[1].hp
	app.tick_fight(confirm_both(),true)
	check(app.intro_frames == 65 and app.combat.fighters[1].hp == idle_hp,"Intro skip preserves final fight countdown without attacks")
	finish_intro()
	app.combat.fighters[0].x = 550
	app.combat.fighters[1].x = 645
	app.tick_fight(confirm_one(),true)
	for frame in 15: app.tick_fight(commands(),false)
	check(app.combat.fighters[1].hp < 1000,"Live flow forwards attack input into actual combat")
	# Every best-of setting: actual introductions and end-of-round timers run;
	# only the winner value is forced, isolating flow from fighter balance.
	for best_of in [1,3,5]:
		app.profile.data.settings.rounds = best_of
		app.mode = "versus"
		app.start_match()
		var wins_needed: int = (best_of+1)/2
		var matches_before: int = app.profile.data.stats.matches
		for win_index in wins_needed:
			finish_round(0)
			check(app.wins[0] == win_index+1,"Best-of-%d tracks round win %d" % [best_of,win_index+1])
			if win_index < wins_needed-1:
				check(app.screen == "fight" and app.combat.winner == -1,"Nonfinal round resets combat without leaving match")
			else:
				check(app.screen == "result" and app.match_winner == 0,"Best-of-%d resolves match at required wins" % best_of)
		check(app.profile.data.stats.matches == matches_before+1,"Match statistics commit once per completed best-of")
		result_confirm(0)
		check(app.screen == "fight" and app.wins == [0,0] and app.match_winner == -1,"Rematch resets all match state")
	app.profile.data.settings.rounds = 3
	app.start_match()
	finish_round(0)
	finish_round(1)
	check(app.is_final_round(),"One win each identifies final round")
	finish_round(2)
	check(app.wins == [1,1] and app.round_number == 4 and app.screen == "fight","Draw awards neither player and repeats playable round")
	check(app.is_final_round(),"Draw does not remove final-round status")
	finish_round(1)
	check(app.match_winner == 1 and app.screen == "result","Final round after draw resolves correct winner")
	result_confirm(1)
	check(app.screen == "select" and app.ready_players == [false,false],"Result character-select clears player confirmations")
	app.tick_select(commands({"block_pressed":true}))
	check(app.screen == "menu","Cabinet defense button returns from unconfirmed selection")
	# Six-match arcade route includes the boss and fictional character ending.
	app.profile.data.settings.rounds = 1
	app.begin_mode("arcade")
	app.cursors[0] = 2
	app.tick_select(confirm_one())
	check(app.arcade_order.size() == 6 and app.arcade_order[-1] == 7 and not app.arcade_order.has(2),"Arcade route has five rivals and Nexus Prime without a mirror")
	var seen: Dictionary = {}
	for rival in app.arcade_order: seen[rival] = true
	check(seen.size() == 6,"Arcade route opponents are distinct")
	start_from_stage()
	for match_index in 6:
		check(app.chosen[1] == app.arcade_order[match_index],"Arcade opponent matches route index %d" % match_index)
		finish_round(0)
		check(app.result_options()[0] == "CONTINUAR","Arcade win offers route progression")
		result_confirm(0)
		if match_index < 5:
			check(app.screen == "vs" and app.arcade_index == match_index+1,"Arcade advances to next VS screen")
			if match_index == 4: check(app.stage == 9 and app.chosen[1] == 7,"Boss uses Final Dimension")
			app.screen_time = 4
			app._physics_process(1.0/60.0)
		else:
			check(app.screen == "ending" and not app.fighter_info(app.chosen[0]).ending.is_empty(),"Final arcade victory reaches character-specific ending")
	app.screen_time = 2
	app.enter_pressed = true
	app._physics_process(1.0/60.0)
	check(app.screen == "menu","Ending returns to menu")
	# Arcade defeat supports retry without advancing the route.
	app.begin_mode("arcade")
	app.tick_select(confirm_one())
	start_from_stage()
	finish_round(1)
	var retry_opponent: int = app.chosen[1]
	result_confirm(0)
	check(app.screen == "fight" and app.arcade_index == 0 and app.chosen[1] == retry_opponent,"Arcade defeat rematches the same rival")
	# Four entrants, two semifinals, one final and a champion bracket.
	app.set_screen("menu")
	app.menu_index = 3
	app.tick_menu(confirm_one())
	check(app.screen == "tournament" and app.tournament_roster.is_empty(),"Tournament opens entrant selection")
	for entry in 4:
		app.tournament_cursor = entry
		app.tick_tournament(confirm_one())
	check(app.screen == "stage" and app.chosen == [0,1],"Four selected entrants launch first semifinal")
	for bracket_match in 3:
		start_from_stage()
		finish_round(0 if bracket_match != 1 else 1)
		check(app.result_options()[0] == "VER CHAVEAMENTO","Tournament match offers bracket progression")
		result_confirm(0)
		check(app.screen == "tournament_result" and app.tournament_round == bracket_match+1,"Bracket records completed match")
		app.enter_pressed = true
		app._physics_process(1.0/60.0)
		if bracket_match == 0: check(app.chosen == [2,3] and app.screen == "stage","Second semifinal uses remaining entrants")
		elif bracket_match == 1: check(app.chosen == [0,3] and app.screen == "stage","Final uses actual semifinal winners")
		else: check(app.screen == "menu" and app.tournament_winners == [0,3,0],"Tournament champion is retained before menu return")
	# Training owns its health/meter toggles; main and engine must agree.
	app.begin_mode("training")
	app.tick_select(confirm_one())
	start_from_stage()
	check(app.combat.training and app.intro_frames == 0,"Training starts directly in controllable combat")
	app.train_options.health = false
	app.train_options.meter = false
	app.train_options.guard = false
	app.train_options.dummy = 0
	app.combat.fighters[0].hp = 410
	app.combat.fighters[0].meter = 37
	app.tick_fight(commands(),false)
	check(not app.combat.training_options.infinite_health and not app.combat.training_options.infinite_meter,"Training UI toggles synchronize into engine")
	check(app.combat.fighters[0].hp == 410 and app.combat.fighters[0].meter == 37,"Disabled training regeneration remains disabled")
	app.train_options.health = true
	app.train_options.meter = true
	app.tick_fight(commands(),false)
	check(app.combat.fighters[0].hp == 1000 and app.combat.fighters[0].meter == 100,"Enabled training regeneration restores resources")
	app.train_options.health = false
	app.train_options.meter = false
	app.combat.fighters[1].hp = 0
	app.tick_fight(commands(),false)
	check(app.combat.fighters[1].hp == 1000 and app.combat.winner == -1 and app.screen == "fight","Finite-health training restarts after KO")
	app.combat.fighters[0].x = 550
	app.combat.fighters[1].x = 645
	app.combat.fighters[0].meter = 100
	app.combat.fighters[1].hp = 90
	app.tick_fight(commands({"attack":true,"power":true,"attack_pressed":true,"power_pressed":true}),true)
	var cinematic_start_wait := 0
	while not app.combat.cinematic.active and cinematic_start_wait < 90:
		app.tick_fight(commands(),false)
		cinematic_start_wait += 1
	check(app.combat.cinematic.active,"Actual training flow starts a confirmed super cinematic")
	for frame in 269: app.tick_fight(commands(),false)
	check(app.combat.cinematic.active and app.combat.fighters[1].hp == 0,"Finite training health never interrupts a lethal cinematic")
	app.tick_fight(commands(),false)
	check(not app.combat.cinematic.active and app.combat.fighters[1].hp == 1000,"Training resets lethal super only after its full duration")
	app.tutorial = true
	app.tutorial_step = 2
	perfect_block_event(0)
	check(app.tutorial_step == 3,"One perfect block completes only current tutorial step")
	perfect_block_event(1)
	check(app.tutorial_step == 3,"Opponent defense cannot complete player's tutorial step")
	perfect_block_event(0)
	check(app.tutorial_step == 4,"Player perfect block completes dedicated timing step")
	app.tutorial = false
	app.tab_pressed = true
	app.tick_fight(commands(),true)
	clear_flags()
	check(app.screen == "training_menu","Training menu opens without mouse")
	app.tick_training_menu(commands({"block_pressed":true}))
	check(app.screen == "fight","Defense button closes training menu")
	# Dedicated Enter and gamepad Start pause/resume without normal attack keys.
	var key := InputEventKey.new()
	key.physical_keycode = KEY_ENTER
	key.pressed = true
	app._input(key)
	app.tick_fight(commands(),true)
	clear_flags()
	check(app.screen == "pause","Keyboard encoder Enter pauses fight")
	app._input(key)
	app.tick_pause(commands())
	clear_flags()
	check(app.screen == "fight","Enter resumes paused fight")
	var pad := InputEventJoypadButton.new()
	pad.pressed = true
	pad.device = 2
	pad.button_index = JOY_BUTTON_START
	app._input(pad)
	app.tick_fight(commands(),true)
	clear_flags()
	check(app.screen == "pause","Gamepad Start pauses fight")
	app.pause_index = 1
	app.tick_pause(confirm_one())
	check(app.screen == "controls" and app.previous_screen == "pause","Pause exposes control remapping")
	# Bindings are captured through actual InputEvent handlers, then release-
	# debounced so the captured attack button cannot reopen capture immediately.
	app.controls_player = 0
	app.controls_index = 4
	app.tick_controls(confirm_one())
	check(app.capturing_binding,"Control confirm begins binding capture")
	key.physical_keycode = KEY_Q
	app._input(key)
	check(not app.capturing_binding and app.input.get_binding(0,"attack") == KEY_Q,"Keyboard event remaps selected combat action")
	app.tick_controls(commands({"attack":true,"attack_pressed":true}))
	check(not app.capturing_binding and app.binding_capture_wait_release,"Captured key cannot immediately reopen capture")
	app.tick_controls(commands())
	app.controls_player = 1
	app.controls_index = 5
	app.tick_controls(confirm_one())
	pad.button_index = JOY_BUTTON_RIGHT_SHOULDER
	app._input(pad)
	check(not app.capturing_binding and app.input.get_gamepad_binding(1,"power") == JOY_BUTTON_RIGHT_SHOULDER,"Gamepad button event remaps selected action")
	check(app.input.get_gamepad_config(1).device == 2,"Gamepad remap records actual device")
	check(not app.enter_pressed and not app.escape_pressed and not app.any_pressed,"Binding capture consumes navigation flags")
	app.tick_controls(commands())
	app.tick_controls(confirm_one())
	var original_button: int = app.input.get_gamepad_binding(1,"power")
	pad.button_index = JOY_BUTTON_BACK
	app._input(pad)
	check(not app.capturing_binding and app.input.get_gamepad_binding(1,"power") == original_button,"Gamepad Back cancels binding without mutation")
	app.tick_controls(commands())
	app.tick_controls(confirm_one())
	var original_key: int = app.input.get_binding(1,"power")
	key.physical_keycode = KEY_ENTER
	app._input(key)
	check(app.input.get_binding(1,"power") == original_key and app.toast == "TECLA RESERVADA AO SISTEMA","Reserved Enter cannot silently become an unusable combat mapping")
	app.tick_controls(commands())
	app.tick_controls(confirm_one())
	pad.button_index = JOY_BUTTON_START
	app._input(pad)
	check(app.input.get_gamepad_binding(1,"power") == original_button and app.toast == "BOTÃO RESERVADO AO SISTEMA","Reserved Start remains available for pause after rejected remap")
	app.tick_controls(commands())
	app.tick_controls(commands({"block_pressed":true}))
	check(app.screen == "pause","Controls returns to pause through cabinet defense button")
	app.pause_index = 6
	app.tick_pause(confirm_one())
	check(app.screen == "menu","Training pause returns to main menu")
	# Idle cabinet demo is interruptible and never adds player statistics.
	app.idle_frames = 1501
	var stats_before: int = app.profile.data.stats.matches
	app.tick_menu(commands())
	check(app.mode == "attract" and app.screen == "fight","Arcade idle timeout starts attract fight")
	app.tick_fight(commands({"attack_pressed":true}),true)
	check(app.screen == "menu" and app.profile.data.stats.matches == stats_before,"Any input exits attract without recording a match")
	await app.sound.shutdown()
	app.queue_free()
	await process_frame
	for suffix in ["",".tmp",".bak"]:
		if FileAccess.file_exists(PROFILE_PATH+suffix):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(PROFILE_PATH+suffix))
	print("FLOW TESTS: %d checks, %d failures" % [checks,failures.size()])
	quit(0 if failures.is_empty() else 1)
